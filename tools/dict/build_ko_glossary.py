#!/usr/bin/env python3
"""Build the Korean glossary the app ships: the Basic Korean Dictionary (한국어기초사전)
looked up backwards from its Japanese equivalents.

  python3 tools/dict/build_ko_glossary.py --source krdict_json.zip [--expect-sha256 HEX]
      [--variant lean|full] [--out-dir app/assets/dict]
  python3 tools/dict/build_ko_glossary.py --source krdict_json.zip --sizes
  python3 tools/dict/build_ko_glossary.py --sample-sql      # test fixture of packages/krdict_block
  python3 tools/dict/build_ko_glossary.py --check [--out-dir app/assets/dict] [--max-age-days N]

Source: the JSON download of the dictionary (a zip of JSON files), a single JSON file
or a folder of them. It is not in the repository. To refresh it, open
https://krdict.korean.go.kr/download/downloadPopup, read the current `seq` of the
JSON download and fetch https://krdict.korean.go.kr/dicBatchDownload?seq=<seq>
in a browser (no login; the site refuses requests from scripts). The script never
downloads anything itself; tools/dict/refresh.py --krdict-source takes the zip.

Writes into --out-dir (default app/assets/dict, git-ignored):
  ko-glossary.sqlite.gz      the index (docs/dictionary.md, 11)
  ko-glossary.edition.json   source, edition date, licence, sha256 of the source and of
                             the SQLite file; the app unpacks again whenever it changes

Index rules (packages/krdict_block reads the same keys, tools/dict/testdata/ko_glossary_keys.json):
- An equivalent `しょくどう【食堂】。レストラン` gives the pair 食堂 + しょくどう at
  position 0 and the kana word レストラン at position 1.
- Keys drop spaces, 〜 and …, a する / だ / な ending (だ and な only after kanji,
  する after kanji or two kana), other parenthesised parts, and fold katakana to hiragana.
  The dropped ending is kept (ja.ending): 有名だ prefers 유명하다 (ゆうめいだ【有名だ】)
  to 유명 (ゆうめい【有名】).
- Senses whose only equivalent is `(対訳語無し)` and entries that are not single words
  (idioms, proverbs, grammar patterns) are left out.
Same source and build day give byte-identical files. Only the Python 3 standard library is used.
"""
from __future__ import annotations

import argparse
import datetime as dt
import glob
import gzip
import hashlib
import json
import os
import re
import sqlite3
import sys
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator, NamedTuple

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))

import asset_check  # noqa: E402
DEFAULT_OUT = REPO / "app" / "assets" / "dict"
SAMPLE = HERE / "testdata" / "krdict_sample.json"
SAMPLE_SQL = REPO / "packages" / "krdict_block" / "test" / "fixtures" / "mini_krdict.sql"
SAMPLE_BUILT_ON = "2026-11-05"

SCHEMA_VERSION = 1
ASSET_NAME = "ko-glossary.sqlite.gz"
EDITION_NAME = "ko-glossary.edition.json"
VARIANTS = ("lean", "full")
DAY = re.compile(r"\d{4}-\d{2}-\d{2}")

KRDICT = {
    "source": "krdict",
    "name": "한국어기초사전",
    "publisher": "국립국어원",
    "license": "CC BY-SA 2.0 KR",
    "license_url": "https://creativecommons.org/licenses/by-sa/2.0/kr/",
    "url": "https://krdict.korean.go.kr/download/downloadPopup",
}

# Part kinds, as stored in ja.kind.
PAIR, WRITTEN, KANA = 0, 1, 2

LEVELS = {"초급": 1, "중급": 2, "고급": 3}
WORD_UNIT = "단어"
JAPANESE = "일본어"
NO_EQUIVALENT = "対訳語無し"

# ------------------------------------------------------------------ keys


def _is_kanji(ch: str) -> bool:
    o = ord(ch)
    return (0x4E00 <= o <= 0x9FFF or 0x3400 <= o <= 0x4DBF or 0xF900 <= o <= 0xFAFF
            or 0x20000 <= o <= 0x2FFFF or ch in "々〆")


def has_kanji(s: str) -> bool:
    return any(_is_kanji(c) for c in s)


def to_hiragana(s: str) -> str:
    """ァ..ヶ become ぁ..ゖ; ー and other marks stay."""
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in s)


_NOISE = re.compile("[ \t\n\r\f\v\u00a0\u3000\ufeff〜～~…]")  # same set as keys.dart
_PARENS = re.compile(r"[（(][^）)]*[）)]")
_ENDINGS = ("する", "だ", "な")
_KANJI_ONLY_ENDINGS = {"だ", "な"}


def _ending_of(s: str, ending: str) -> str:
    """'optional' for 勉強(する), 'written' for 勉強する, '' otherwise."""
    if s.endswith(f"({ending})") or s.endswith(f"（{ending}）"):
        return "optional"
    return "written" if len(s) > len(ending) and s.endswith(ending) else ""


def _cut(s: str, ending: str, how: str) -> str:
    if how == "optional":
        return s[: -len(ending) - 2]
    if how == "written":
        return s[: -len(ending)]
    return s


def _strip_ending(form: str, reading: str) -> tuple[str, str, str]:
    kanji = has_kanji(form)
    for ending in _ENDINGS:
        if ending in _KANJI_ONLY_ENDINGS and not kanji:
            continue
        how = _ending_of(form, ending)
        if not how:
            continue
        # A kana word needs two kana before する (かする is a verb of its own).
        if how == "written" and not kanji and len(form) - len(ending) < 2:
            continue
        return _cut(form, ending, how), _cut(reading, ending, _ending_of(reading, ending)), ending
    return form, reading, ""


def keys_and_ending(form: str, reading: str) -> tuple[str, str, str]:
    """[pair_key] and the ending it dropped ('する', 'だ', 'な' or '')."""
    f, r, ending = _strip_ending(_NOISE.sub("", form), _NOISE.sub("", reading))
    return to_hiragana(_PARENS.sub("", f)), to_hiragana(_PARENS.sub("", r)), ending


def pair_key(form: str, reading: str) -> tuple[str, str]:
    """The index keys of a written form and its reading ('' for none)."""
    key, reading_key, _ = keys_and_ending(form, reading)
    return key, reading_key


# ------------------------------------------------------------------ parsing


class Part(NamedTuple):
    position: int
    kind: int
    written: str
    reading: str


_SPLIT = re.compile(r"[。、;；\n]")
_BRACKET = re.compile(r"^(?P<before>[^【]*)【(?P<inside>[^】」]*)(?:[】」]|$)(?P<after>.*)$")


def _alternatives(s: str) -> list[str]:
    return [a.strip() for a in re.split(r"[・･]", s) if a.strip()]


def _parts_of(chunk: str, position: int) -> list[Part]:
    m = _BRACKET.match(chunk)
    if m is None:
        kind = WRITTEN if has_kanji(chunk) else KANA
        return [Part(position, kind, chunk, "")]
    before, inside, after = m["before"].strip(), m["inside"].strip(), m["after"].strip(" \t・･、")
    if not before and after:  # 【きばたい】騎馬隊: the reading came first
        before, inside, after = inside, after, ""
    parts: list[Part] = []
    if inside and not has_kanji(inside):  # たばこ【タバコ】: two kana spellings
        parts += [Part(position, KANA, w, "") for w in [*_alternatives(before), *_alternatives(inside)]]
    elif inside:
        readings = _alternatives(before) or [""]
        if after in _ENDINGS:  # せいじゅく【成熟】する: the ending belongs to the pair
            readings = [r + after for r in readings]
            inside, after = "・".join(w + after for w in _alternatives(inside)), ""
        parts += [Part(position, PAIR, w, r) for r in readings for w in _alternatives(inside)]
    elif before:
        parts += _parts_of(before, position)
    if after:
        parts += _parts_of(after, position)
    return parts


def parse_equivalent(text: str) -> list[Part]:
    """The Japanese words of one equivalent string, in order (`(対訳語無し)` gives none)."""
    parts: list[Part] = []
    position = 0
    for chunk in _SPLIT.split(text):
        chunk = chunk.strip(" \t　")
        if not chunk or NO_EQUIVALENT in chunk:
            continue
        found = _parts_of(chunk, position)
        if found:
            parts += found
            position += 1
    return parts


# ------------------------------------------------------------------ source


def _as_list(x: object) -> list:
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


def _feats(node: dict) -> dict[str, str]:
    """att → val of a node's feat list (the first value wins; feats without val are skipped)."""
    out: dict[str, str] = {}
    for f in _as_list(node.get("feat")):
        if isinstance(f, dict) and "att" in f and "val" in f:
            out.setdefault(f["att"], f["val"])
    return out


@dataclass(frozen=True)
class Sense:
    number: int
    definition: str
    japanese: str  # the raw equivalent string
    synonyms: tuple[str, ...]


@dataclass(frozen=True)
class Entry:
    entry_id: str
    word: str
    unit: str
    level: int | None
    senses: tuple[Sense, ...]


@dataclass(frozen=True)
class Source:
    edition: str
    sha256: str
    entries: tuple[Entry, ...]


def _entry(e: dict) -> Entry | None:
    lemma = _as_list(e.get("Lemma"))
    word = _feats(lemma[0]).get("writtenForm", "").strip() if lemma else ""
    if not word:
        return None
    ef = _feats(e)
    senses = []
    for i, s in enumerate(_as_list(e.get("Sense")), start=1):
        japanese = [_feats(q).get("lemma", "") for q in _as_list(s.get("Equivalent"))
                    if _feats(q).get("language") == JAPANESE]
        synonyms = tuple(dict.fromkeys(
            _feats(r)["lemma"].strip() for r in _as_list(s.get("SenseRelation"))
            if _feats(r).get("type") == "유의어" and _feats(r).get("lemma", "").strip()))
        number = int(s["val"]) if str(s.get("val", "")).isdigit() else i
        senses.append(Sense(number, _feats(s).get("definition", ""), "。".join(japanese), synonyms))
    return Entry(str(e.get("val", "")), word, ef.get("lexicalUnit", ""),
                 LEVELS.get(ef.get("vocabularyLevel", "")), tuple(senses))


def _documents(path: Path) -> Iterator[tuple[str, bytes]]:
    if path.is_dir():
        for name in sorted(glob.glob(str(path / "*.json")), key=_file_order):
            yield name, Path(name).read_bytes()
    elif zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            names = sorted((n for n in z.namelist() if n.endswith(".json")), key=_file_order)
            for name in names:
                yield name, z.read(name)
    else:
        yield str(path), path.read_bytes()


def _file_order(name: str) -> tuple[int, str]:
    """1_5000_…json before 2_5000_…json before 10_5000_…json."""
    m = re.match(r"(\d+)_", Path(name).name)
    return (int(m[1]) if m else 0, name)


def _sha256(path: Path) -> str:
    if path.is_dir():
        h = hashlib.sha256()
        for _, data in _documents(path):
            h.update(hashlib.sha256(data).digest())
        return h.hexdigest()
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def read_source(path: Path) -> Source:
    """Every entry of the download, in file order. Exits on a file that is not the dictionary."""
    path = Path(path)
    if not path.exists():
        sys.exit(f"source not found: {path} (see --help for where to get it)")
    entries: list[Entry] = []
    editions: set[str] = set()
    for name, data in _documents(path):
        try:
            resource = json.loads(data.decode("utf-8"))["LexicalResource"]
            raw = _as_list(resource["Lexicon"].get("LexicalEntry"))
        except (UnicodeDecodeError, json.JSONDecodeError, KeyError, TypeError, AttributeError) as e:
            sys.exit(f"{name}: not a Basic Korean Dictionary JSON file ({e})")
        created = _feats(resource.get("GlobalInformation") or {}).get("creationDate", "")
        m = re.match(r"(\d{4})[/-](\d{2})[/-](\d{2})", created)
        if m:
            editions.add(f"{m[1]}-{m[2]}-{m[3]}")
        entries += [x for x in (_entry(e) for e in raw if isinstance(e, dict)) if x is not None]
    if len(editions) != 1:
        sys.exit(f"{path}: expected one creationDate in the files, found {sorted(editions) or 'none'}")
    return Source(editions.pop(), _sha256(path), tuple(entries))


# ------------------------------------------------------------------ database


def _schema(variant: str) -> str:
    definition = ",\n  definition TEXT NOT NULL" if variant == "full" else ""
    return f"""
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE sense (
  id INTEGER PRIMARY KEY,
  word TEXT NOT NULL,
  level INTEGER,
  sense_no INTEGER NOT NULL,
  source INTEGER NOT NULL,
  synonyms TEXT NOT NULL{definition}
);
CREATE TABLE ja (
  key TEXT NOT NULL,
  reading TEXT NOT NULL,
  kind INTEGER NOT NULL,
  pos INTEGER NOT NULL,
  ending TEXT NOT NULL,
  sense_id INTEGER NOT NULL REFERENCES sense(id)
);
"""


INDEXES = """
CREATE INDEX ja_key ON ja(key);
CREATE INDEX ja_reading ON ja(reading) WHERE kind = 0;
"""


def _rows(entries: Iterable[Entry], variant: str) -> Iterator[tuple[tuple, list[tuple]]]:
    """(sense row, its ja rows) for every single-word sense with a Japanese word."""
    sense_id = 0
    for e in entries:
        if e.unit != WORD_UNIT:
            continue
        for s in e.senses:
            keys: dict[tuple[str, str, int, str], int] = {}
            for p in parse_equivalent(s.japanese):
                key, reading, ending = keys_and_ending(p.written, p.reading)
                if key:
                    keys.setdefault((key, reading, p.kind, ending), p.position)
            if not keys:
                continue
            sense_id += 1
            row = (sense_id, e.word, e.level, s.number, 0, "|".join(s.synonyms))
            if variant == "full":
                row += (s.definition,)
            yield row, [(k, r, kind, pos, ending, sense_id) for (k, r, kind, ending), pos in keys.items()]


def _meta(source: Source, variant: str, built_on: str, senses: int, keys: int) -> dict[str, str]:
    return {
        "schema": str(SCHEMA_VERSION),
        "variant": variant,
        "built_on": built_on,
        "senses": str(senses),
        "keys": str(keys),
        "sources": "krdict",
        "krdict.name": KRDICT["name"],
        "krdict.publisher": KRDICT["publisher"],
        "krdict.license": KRDICT["license"],
        "krdict.license_url": KRDICT["license_url"],
        "krdict.edition": source.edition,
    }


def _fill(db: sqlite3.Connection, source: Source, variant: str, built_on: str) -> dict[str, str]:
    if variant not in VARIANTS:
        sys.exit(f"--variant must be one of {', '.join(VARIANTS)}, got {variant!r}")
    if not DAY.fullmatch(built_on):
        sys.exit(f"--built-on must be YYYY-MM-DD, got {built_on!r}")
    db.executescript(_schema(variant))
    senses = keys = 0
    marks = ",".join("?" * (7 if variant == "full" else 6))
    for row, ja in _rows(source.entries, variant):
        db.execute(f"INSERT INTO sense VALUES ({marks})", row)
        db.executemany("INSERT INTO ja VALUES (?,?,?,?,?,?)", ja)
        senses += 1
        keys += len(ja)
    db.executescript(INDEXES)
    meta = _meta(source, variant, built_on, senses, keys)
    db.executemany("INSERT INTO meta VALUES (?,?)", sorted(meta.items()))
    db.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
    return meta


def build_db(source: Source, out: Path, *, variant: str = "lean", built_on: str) -> dict[str, str]:
    """Write the SQLite file [out] and return its meta."""
    out = Path(out)
    out.unlink(missing_ok=True)
    db = sqlite3.connect(out)
    try:
        meta = _fill(db, source, variant, built_on)
        db.commit()
        db.execute("VACUUM")
    finally:
        db.close()
    return meta


def sql_dump(source: Source, *, variant: str = "lean", built_on: str) -> str:
    """The database as SQL text (the Dart tests load it into an in-memory database)."""
    db = sqlite3.connect(":memory:")
    try:
        _fill(db, source, variant, built_on)
        lines = [line for line in db.iterdump() if line not in ("BEGIN TRANSACTION;", "COMMIT;")]
    finally:
        db.close()
    header = ["-- Built by tools/dict/build_ko_glossary.py --sample-sql from",
              "-- tools/dict/testdata/krdict_sample.json (made-up entries). Do not edit.",
              f"PRAGMA user_version = {SCHEMA_VERSION};"]
    return "\n".join(header + lines) + "\n"


# ------------------------------------------------------------------ asset


def build_asset(source_path: Path, out_dir: Path, *, built_on: str, variant: str = "lean",
                expect_sha256: str | None = None) -> dict:
    """Build the gzip and its edition file into [out_dir] and return the edition."""
    if not DAY.fullmatch(built_on):
        sys.exit(f"--built-on must be YYYY-MM-DD, got {built_on!r}")
    source_path = Path(source_path)
    if not source_path.exists():
        sys.exit(f"source not found: {source_path} (see --help for where to get it)")
    if expect_sha256 and _sha256(source_path) != expect_sha256.lower():
        sys.exit(f"sha256 mismatch: {source_path} is {_sha256(source_path)}, expected {expect_sha256}")
    source = read_source(source_path)
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=out_dir) as tmp:
        db_path = Path(tmp) / "ko-glossary.sqlite"
        meta = build_db(source, db_path, variant=variant, built_on=built_on)
        raw = db_path.read_bytes()
        packed = gzip.compress(raw, compresslevel=9, mtime=0)
        krdict = {k: KRDICT[k] for k in ("source", "name", "publisher", "license", "license_url", "url")}
        edition = {
            "variant": variant,
            "schema": SCHEMA_VERSION,
            "built_on": built_on,
            "sources": [{**krdict, "edition": source.edition, "source_sha256": source.sha256}],
            "attribution": f"{KRDICT['name']}, {KRDICT['publisher']}, {KRDICT['license']}, "
                           f"{source.edition}판을 가공함",
            "senses": int(meta["senses"]),
            "keys": int(meta["keys"]),
            "sqlite_bytes": len(raw),
            "sqlite_sha256": hashlib.sha256(raw).hexdigest(),
            "gzip_bytes": len(packed),
        }
        # As in build_app_asset.py: the old edition goes first and the new one last,
        # so a build cut short leaves no edition file rather than a stale one.
        gz_part = Path(tmp) / ASSET_NAME
        gz_part.write_bytes(packed)
        edition_part = Path(tmp) / EDITION_NAME
        edition_part.write_text(json.dumps(edition, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                                encoding="utf-8")
        (out_dir / EDITION_NAME).unlink(missing_ok=True)
        os.replace(gz_part, out_dir / ASSET_NAME)
        os.replace(edition_part, out_dir / EDITION_NAME)
    return edition


def sizes(source_path: Path, built_on: str) -> list[dict]:
    """SQLite and gzip size of both variants (docs/dictionary.md)."""
    source = read_source(source_path)
    out = []
    with tempfile.TemporaryDirectory() as tmp:
        for variant in VARIANTS:
            path = Path(tmp) / f"{variant}.sqlite"
            meta = build_db(source, path, variant=variant, built_on=built_on)
            raw = path.read_bytes()
            out.append({"variant": variant, "sqlite_bytes": len(raw),
                        "gzip_bytes": len(gzip.compress(raw, compresslevel=9, mtime=0)),
                        "senses": int(meta["senses"]), "keys": int(meta["keys"])})
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", type=Path, help="the JSON download (zip, JSON file or folder)")
    ap.add_argument("--expect-sha256", help="stop unless the source file has this sha256")
    ap.add_argument("--variant", default="lean", choices=VARIANTS,
                    help="lean: Korean words only (default); full: also the Korean definitions")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT, help="default: app/assets/dict")
    ap.add_argument("--built-on", default=dt.datetime.now(dt.timezone.utc).date().isoformat(),
                    help="build day written to the edition file (default: today, UTC)")
    ap.add_argument("--sizes", action="store_true", help="print the size of both variants and stop")
    ap.add_argument("--sample-sql", action="store_true",
                    help=f"rewrite {SAMPLE_SQL.relative_to(REPO)} from the made-up sample and stop")
    ap.add_argument("--check", action="store_true",
                    help="build nothing: check the asset in --out-dir against its edition file (asset_check.py)")
    asset_check.add_arguments(ap)
    a = ap.parse_args(argv)
    if a.check:
        return asset_check.report(a.out_dir, max_age_days=a.max_age_days, names=("ko-glossary",))
    if a.sample_sql:
        SAMPLE_SQL.parent.mkdir(parents=True, exist_ok=True)
        SAMPLE_SQL.write_text(sql_dump(read_source(SAMPLE), variant="lean", built_on=SAMPLE_BUILT_ON),
                              encoding="utf-8")
        print(f"wrote {SAMPLE_SQL.relative_to(REPO)}", file=sys.stderr)
        return 0
    if a.source is None:
        ap.error("--source is required (the dictionary is not downloaded by this script)")
    if a.sizes:
        print(json.dumps(sizes(a.source, a.built_on), indent=1))
        return 0
    edition = build_asset(a.source, a.out_dir, built_on=a.built_on, variant=a.variant,
                          expect_sha256=a.expect_sha256)
    print(f"wrote {a.out_dir / ASSET_NAME} ({edition['gzip_bytes']:,} bytes, "
          f"SQLite {edition['sqlite_bytes']:,}) and {EDITION_NAME}", file=sys.stderr)
    print(json.dumps(edition, ensure_ascii=False, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
