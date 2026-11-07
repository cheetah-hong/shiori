#!/usr/bin/env python3
"""Build the Wiktionary fallback glossary the app ships: Korean meanings of Japanese words
the Basic Korean Dictionary glossary (build_ko_glossary.py) has none for.

  python3 tools/dict/build_wikt_glossary.py --kowikt <kowiktionary raw gzip> --kowikt-dump YYYY-MM-DD
      --en-rows <rows from wikt_en_rows.py> [--expect-kowikt-sha256 HEX] [--expect-en-sha256 HEX]
      [--krdict-dir app/assets/dict] [--out-dir app/assets/dict]
  python3 tools/dict/build_wikt_glossary.py --sample-sql   # test fixture of packages/krdict_block
  python3 tools/dict/build_wikt_glossary.py --check [--out-dir app/assets/dict]

Sources (kaikki.org wiktextract data; not in the repository, nothing is downloaded here):
- the Korean Wiktionary: https://kaikki.org/kowiktionary/raw-wiktextract-data.jsonl.gz,
  its Japanese entries and their Korean glosses;
- the English Wiktionary: the Japanese and Korean terms of each English sense's translation
  table, kept by wikt_en_rows.py while the raw dump downloads (the dump is about 3 GB).
  --expect-en-sha256 is the sha256 of that raw dump, which the rows file records.

Rules (docs/dictionary.md, 13):
- A Korean gloss gives its words: notes in brackets and the final stop go, commas split;
  pieces with Japanese in them, explanations (more than MAX_GLOSS_SPACES spaces) and notes
  about the word's use (「어간의 하나」) are dropped. Readings: kana forms (old spellings left
  out) and ruby laid over the word (食べる with ruby 食/た → たべる).
- An English translation row gives every Japanese term the row's Korean terms (a leading
  note in brackets goes, brackets without Hangul or with hanja go, an optional part opens
  up; separators inside brackets do not split; a piece with Japanese left in it is dropped).
- Keys follow build_ko_glossary.keys_and_ending. A key takes the Korean Wiktionary's senses
  when it has any, else the English Wiktionary's.
- Only keys the Basic Korean Dictionary asset (--krdict-dir, checked against its edition)
  cannot answer are kept: not its keys, and for kana keys not its kanji pairs' readings.
- Same schema as the Basic Korean Dictionary glossary (schema 2, lean), read by the same
  block: one sense row per Korean word, its sense's words as synonyms, sense.source 1
  (wiktionary), sense_no the sense's place for the key.
Writes wikt-glossary.sqlite.gz and wikt-glossary.edition.json into --out-dir (git-ignored).
Same inputs and build day give byte-identical files. Only the Python 3 standard library is used.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import gzip
import hashlib
import json
import os
import re
import sqlite3
import sys
import tempfile
from pathlib import Path
from typing import Iterable, Iterator, NamedTuple

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))

import asset_check  # noqa: E402
import build_ko_glossary as ko  # noqa: E402
import wikt_en_rows  # noqa: E402

DEFAULT_OUT = REPO / "app" / "assets" / "dict"
SAMPLE_KO = HERE / "testdata" / "wikt_sample_ko.jsonl"
SAMPLE_EN = HERE / "testdata" / "wikt_sample_en_rows.jsonl"
SAMPLE_SQL = REPO / "packages" / "krdict_block" / "test" / "fixtures" / "mini_wikt.sql"
SAMPLE_BUILT_ON = "2026-11-07"
SAMPLE_KO_DUMP = "2026-11-01"

ASSET_NAME = "wikt-glossary.sqlite.gz"
EDITION_NAME = "wikt-glossary.edition.json"
SCHEMA_VERSION = ko.SCHEMA_VERSION
SOURCE_CODE = 1  # sense.source of wiktionary (krdict is 0)

LICENSE = "CC BY-SA 4.0"
LICENSE_URL = "https://creativecommons.org/licenses/by-sa/4.0/"
KOWIKT = {"source": "wiktionary", "name": "한국어 위키낱말사전", "publisher": "한국어 위키낱말사전 기여자",
          "license": LICENSE, "license_url": LICENSE_URL, "url": "https://ko.wiktionary.org"}
ENWIKT = {"source": "wiktionary", "name": "영어 위키낱말사전", "publisher": "영어 위키낱말사전(Wiktionary) 기여자",
          "license": LICENSE, "license_url": LICENSE_URL, "url": "https://en.wiktionary.org"}

# A gloss piece with more spaces than this explains instead of translating
# (「안개가 낀 숲을 이르는 말」); 「오늘 아침」, 「채소 가게」 stay.
MAX_GLOSS_SPACES = 2

_HANGUL = re.compile("[가-힣]")
_JA_CHAR = re.compile("[ぁ-ゟ゠-ヿ一-鿿㐀-䶿々〆]")
_KANA_ONLY = re.compile("^[ぁ-ゟ゠-ヿー]+$")
_PARENS = re.compile(r"\s*[（(\[［][^）)\]］]*[）)\]］]\s*")
_SPLIT = re.compile(r"\s*[,，;；、/]\s*")
_LEADING_NOTE = re.compile(r"^\s*[（(][^）)]*[）)]\s*")
_NO_HANGUL_PARENS = re.compile("[（(][^）)가-힣]*[）)]")
# A bracketed spelling in hanja (관다발식물(管다발植物)): not part of the word.
_HANJA_PARENS = re.compile("[（(][^）)]*[一-鿿][^）)]*[）)]")
# Glosses about the word, not its meaning (a kanji's use in compounds).
_META = re.compile(r"(어간|어소|어미)의 하나|다음 단어|음독으로|훈독으로")
_OLD_FORM_TAGS = {"archaic", "historical", "obsolete"}


class Group(NamedTuple):
    """One sense of a key: its Korean words, in order."""
    source: str  # "kowikt" or "enwikt"
    ending: str
    readings: frozenset[str]
    words: tuple[str, ...]


# ------------------------------------------------------------------ text


def korean_words(gloss: str) -> list[str]:
    """The words of a Korean gloss (``눈숲, 설삼.`` → 눈숲·설삼; ``(옛말) 겨울 숲.`` → 겨울 숲)."""
    text = _PARENS.sub(" ", gloss).strip().rstrip(".。")
    out: list[str] = []
    for piece in _SPLIT.split(text):
        w = re.sub(r"\s+", " ", piece).strip().rstrip(".。").strip()
        if (w and _HANGUL.search(w) and not _JA_CHAR.search(w) and not _META.search(w)
                and w.count(" ") <= MAX_GLOSS_SPACES and w not in out):
            out.append(w)
    return out


def _split_outside_brackets(text: str) -> list[str]:
    """[text] split at the separators of _SPLIT that are not inside brackets
    (``…(은/는) 무엇, 어디`` → ``…(은/는) 무엇`` · ``어디``)."""
    pieces, depth, start = [], 0, 0
    for i, ch in enumerate(text):
        if ch in "(（":
            depth += 1
        elif ch in ")）":
            depth = max(depth - 1, 0)
        elif depth == 0 and ch in ",，;；、/":
            pieces.append(text[start:i])
            start = i + 1
    pieces.append(text[start:])
    return pieces


def translation_words(term: str) -> list[str]:
    """The words of a translation-table term, read like a Korean gloss (no Japanese
    left in a word): ``(입을) 다물다`` → 다물다; ``가만히 (있다)`` → 가만히 있다;
    ``자유(自由)``, ``관다발식물(管다발植物)`` → 자유, 관다발식물."""
    out: list[str] = []
    for piece in _split_outside_brackets(term):
        w = _HANJA_PARENS.sub("", _NO_HANGUL_PARENS.sub("", _LEADING_NOTE.sub("", piece)))
        w = re.sub(r"\s+", " ", re.sub(r"[（()）]", "", w)).strip()
        if w and _HANGUL.search(w) and not _JA_CHAR.search(w) and w not in out:
            out.append(w)
    return out


def ruby_reading(word: str, ruby: list) -> str:
    """The whole reading of [word] from ruby over its kanji pieces (食べる with [[食, た]] →
    たべる); '' when the pieces do not fit the word."""
    out, i = [], 0
    for base, kana in ruby:
        j = word.find(base, i)
        if j < 0:
            return ""
        out += [word[i:j], kana]
        i = j + len(base)
    out.append(word[i:])
    reading = "".join(out)
    return reading if _KANA_ONLY.match(reading) else ""


def readings_of(entry: dict) -> list[str]:
    """Readings an entry spells out: kana forms (old spellings left out) and ruby over the word."""
    out: list[str] = []
    word = entry.get("word", "")
    for f in entry.get("forms") or []:
        if _OLD_FORM_TAGS & set(f.get("tags") or []):
            continue
        form = f.get("form", "")
        if _KANA_ONLY.match(form) and form != word:
            out.append(form)
        ruby = f.get("ruby") or []
        if ruby and form == word:
            reading = ruby_reading(word, ruby)
            if reading:
                out.append(reading)
    return list(dict.fromkeys(out))


# ------------------------------------------------------------------ senses


def _add(groups: dict[str, list[Group]], source: str, word: str, readings: Iterable[str],
         words: Iterable[str]) -> None:
    words = tuple(dict.fromkeys(w for w in words if w))
    if not words:
        return
    key, _, ending = ko.keys_and_ending(word, "")
    if not key:
        return
    reads = frozenset(r for r in (ko.keys_and_ending(word, x)[1] for x in readings) if r and r != key)
    group = Group(source, ending, reads, words)
    found = groups.setdefault(key, [])
    if group not in found:
        found.append(group)


def kowikt_groups(entries: Iterable[dict]) -> dict[str, list[Group]]:
    """Senses of the Korean Wiktionary's Japanese entries, by key, in file order."""
    groups: dict[str, list[Group]] = {}
    for e in entries:
        if e.get("lang_code") != "ja" or not e.get("word"):
            continue
        reads = readings_of(e)
        for s in e.get("senses") or []:
            for g in s.get("glosses") or []:
                _add(groups, "kowikt", e["word"], reads, korean_words(g))
    return groups


def enwikt_groups(rows: Iterable[dict]) -> dict[str, list[Group]]:
    """Senses of the English Wiktionary's translation rows, by Japanese key, in row order."""
    groups: dict[str, list[Group]] = {}
    for row in rows:
        words = [w for k in row.get("ko") or [] for w in translation_words(k.get("word") or "")]
        for j in row.get("ja") or []:
            alt = j.get("alt") or ""
            _add(groups, "enwikt", j.get("word") or "", [alt] if _KANA_ONLY.match(alt) else [], words)
    return groups


def krdict_keys(sqlite_path: Path) -> set[str]:
    """Keys the Basic Korean Dictionary glossary answers: its keys and its kanji pairs' readings."""
    with contextlib.closing(sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True)) as db:
        keys = {r[0] for r in db.execute("SELECT DISTINCT key FROM ja")}
        keys |= {r[0] for r in db.execute(f"SELECT DISTINCT reading FROM ja WHERE kind = {ko.PAIR}")}
    keys.discard("")
    return keys


def merge_groups(kowikt: dict[str, list[Group]], enwikt: dict[str, list[Group]],
                 excluded: set[str]) -> dict[str, list[Group]]:
    """Per key the Korean Wiktionary's senses, else the English one's; keys in [excluded] go."""
    out: dict[str, list[Group]] = {}
    for key in sorted(set(kowikt) | set(enwikt)):
        if key in excluded:
            continue
        out[key] = list(kowikt.get(key) or enwikt[key])
    return out


# ------------------------------------------------------------------ database


def _rows(groups: dict[str, list[Group]]) -> Iterator[tuple[tuple, list[tuple]]]:
    """(sense row, its ja rows): one sense row per Korean word of each group."""
    sense_id = 0
    for key in sorted(groups):
        for number, g in enumerate(groups[key], start=1):
            synonyms = "|".join(g.words)
            if ko.has_kanji(key):
                parts = [(key, r, ko.PAIR) for r in sorted(g.readings)] or [(key, "", ko.WRITTEN)]
            else:
                parts = [(key, "", ko.KANA)]
            for word in g.words:
                sense_id += 1
                yield ((sense_id, word, None, number, SOURCE_CODE, synonyms, 0),
                       [(k, r, kind, 0, g.ending, sense_id) for k, r, kind in parts])


def _meta(info: dict, built_on: str, senses: int, keys: int) -> dict[str, str]:
    return {
        "schema": str(SCHEMA_VERSION),
        "variant": "lean",
        "built_on": built_on,
        "senses": str(senses),
        "keys": str(keys),
        "sources": "wiktionary",
        "wiktionary.name": "위키낱말사전",
        "wiktionary.publisher": "위키낱말사전(한국어판·영어판) 기여자",
        "wiktionary.license": LICENSE,
        "wiktionary.license_url": LICENSE_URL,
        "wiktionary.edition": info["kowikt_dump"],
        "wiktionary.en_edition": info["en_dump"],
        "krdict_sqlite_sha256": info["krdict_sqlite_sha256"],
    }


def _fill(db: sqlite3.Connection, groups: dict[str, list[Group]], info: dict, built_on: str) -> dict[str, str]:
    if not ko.DAY.fullmatch(built_on):
        sys.exit(f"--built-on must be YYYY-MM-DD, got {built_on!r}")
    db.executescript(ko._schema("lean"))
    senses = keys = 0
    for row, ja in _rows(groups):
        db.execute("INSERT INTO sense VALUES (?,?,?,?,?,?,?)", row)
        db.executemany("INSERT INTO ja VALUES (?,?,?,?,?,?)", ja)
        senses += 1
        keys += len(ja)
    db.executescript(ko.INDEXES)
    meta = _meta(info, built_on, senses, keys)
    db.executemany("INSERT INTO meta VALUES (?,?)", sorted(meta.items()))
    db.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
    return meta


def _read_jsonl(path: Path) -> list[dict]:
    opener = gzip.open if path.suffix == ".gz" else open
    try:
        with opener(path, "rt", encoding="utf-8") as f:
            return [json.loads(line) for line in f if line.strip()]
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as e:
        sys.exit(f"{path}: not a wiktextract JSONL file ({e})")


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def _groups(kowikt: Path, en_rows: Path, excluded: set[str]) -> tuple[dict[str, list[Group]], dict]:
    header, rows = wikt_en_rows.read_rows(en_rows)
    return (merge_groups(kowikt_groups(_read_jsonl(kowikt)), enwikt_groups(rows), excluded), header)


def sample_sql() -> str:
    """The sample built as SQL text (packages/krdict_block loads it in memory); the Basic
    Korean Dictionary keys left out are those of build_ko_glossary's sample."""
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "ko.sqlite"
        ko.build_db(ko.read_source(ko.SAMPLE), path, built_on=SAMPLE_BUILT_ON)
        excluded = krdict_keys(path)
        krdict_sha = hashlib.sha256(path.read_bytes()).hexdigest()
    groups, header = _groups(SAMPLE_KO, SAMPLE_EN, excluded)
    info = {"kowikt_dump": SAMPLE_KO_DUMP, "en_dump": header["dump"], "krdict_sqlite_sha256": krdict_sha}
    db = sqlite3.connect(":memory:")
    try:
        _fill(db, groups, info, SAMPLE_BUILT_ON)
        lines = [line for line in db.iterdump() if line not in ("BEGIN TRANSACTION;", "COMMIT;")]
    finally:
        db.close()
    head = ["-- Built by tools/dict/build_wikt_glossary.py --sample-sql from",
            "-- tools/dict/testdata/wikt_sample_*.jsonl (made-up entries). Do not edit.",
            f"PRAGMA user_version = {SCHEMA_VERSION};"]
    return "\n".join(head + lines) + "\n"


def _krdict(krdict_dir: Path, work: Path) -> tuple[set[str], str]:
    """The Basic Korean Dictionary asset's keys and SQLite sha256; exits unless it matches its edition."""
    gz_name, edition_name = asset_check.ASSETS["ko-glossary"]
    problems = asset_check.check_asset("ko-glossary", krdict_dir / gz_name, krdict_dir / edition_name)
    if problems:
        sys.exit("the Basic Korean Dictionary asset does not match its edition: " + "; ".join(problems))
    raw = gzip.decompress((krdict_dir / gz_name).read_bytes())
    path = work / "krdict.sqlite"
    path.write_bytes(raw)
    return krdict_keys(path), hashlib.sha256(raw).hexdigest()


def build_asset(kowikt: Path, en_rows: Path, krdict_dir: Path, out_dir: Path, *, built_on: str,
                kowikt_dump: str, expect_kowikt_sha256: str | None = None,
                expect_en_sha256: str | None = None) -> dict:
    """Build the gzip and its edition file into [out_dir] and return the edition."""
    for day, name in ((built_on, "--built-on"), (kowikt_dump, "--kowikt-dump")):
        if not ko.DAY.fullmatch(day):
            sys.exit(f"{name} must be YYYY-MM-DD, got {day!r}")
    kowikt, en_rows, out_dir = Path(kowikt), Path(en_rows), Path(out_dir)
    for path in (kowikt, en_rows):
        if not path.is_file():
            sys.exit(f"source not found: {path} (see --help for where to get it)")
    kowikt_sha = _sha256(kowikt)
    if expect_kowikt_sha256 and kowikt_sha != expect_kowikt_sha256.lower():
        sys.exit(f"sha256 mismatch: {kowikt} is {kowikt_sha}, expected {expect_kowikt_sha256}")
    header, _ = wikt_en_rows.read_rows(en_rows)
    if expect_en_sha256 and header.get("source_sha256") != expect_en_sha256.lower():
        sys.exit(f"sha256 mismatch: {en_rows} is from {header.get('source_sha256')}, "
                 f"expected {expect_en_sha256}")
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=out_dir) as tmp:
        excluded, krdict_sha = _krdict(Path(krdict_dir), Path(tmp))
        groups, header = _groups(kowikt, en_rows, excluded)
        info = {"kowikt_dump": kowikt_dump, "en_dump": header["dump"], "krdict_sqlite_sha256": krdict_sha}
        db_path = Path(tmp) / "wikt-glossary.sqlite"
        db = sqlite3.connect(db_path)
        try:
            meta = _fill(db, groups, info, built_on)
            db.commit()
            db.execute("VACUUM")
        finally:
            db.close()
        raw = db_path.read_bytes()
        packed = gzip.compress(raw, compresslevel=9, mtime=0)
        edition = {
            "variant": "lean",
            "schema": SCHEMA_VERSION,
            "built_on": built_on,
            "sources": [
                {**KOWIKT, "edition": kowikt_dump, "source_sha256": kowikt_sha},
                {**ENWIKT, "edition": header["dump"], "source_sha256": header["source_sha256"]},
            ],
            "attribution": f"위키낱말사전(한국어판·영어판) 기여자, {LICENSE}, "
                           f"{kowikt_dump}·{header['dump']}판을 가공함",
            "krdict_sqlite_sha256": krdict_sha,
            "senses": int(meta["senses"]),
            "keys": int(meta["keys"]),
            "sqlite_bytes": len(raw),
            "sqlite_sha256": hashlib.sha256(raw).hexdigest(),
            "gzip_bytes": len(packed),
        }
        # As build_ko_glossary.py: the old edition goes first and the new one last.
        gz_part = Path(tmp) / ASSET_NAME
        gz_part.write_bytes(packed)
        edition_part = Path(tmp) / EDITION_NAME
        edition_part.write_text(json.dumps(edition, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                                encoding="utf-8")
        (out_dir / EDITION_NAME).unlink(missing_ok=True)
        os.replace(gz_part, out_dir / ASSET_NAME)
        os.replace(edition_part, out_dir / EDITION_NAME)
    return edition


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--kowikt", type=Path, help="kaikki kowiktionary raw-wiktextract-data.jsonl(.gz)")
    ap.add_argument("--kowikt-dump", help="date of that kowiktionary dump (YYYY-MM-DD)")
    ap.add_argument("--expect-kowikt-sha256", help="stop unless the kowiktionary file has this sha256")
    ap.add_argument("--en-rows", type=Path, help="the rows file wikt_en_rows.py wrote")
    ap.add_argument("--expect-en-sha256", help="stop unless the rows came from a raw dump with this sha256")
    ap.add_argument("--krdict-dir", type=Path, default=DEFAULT_OUT,
                    help="folder of the Basic Korean Dictionary asset (default: app/assets/dict)")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT, help="default: app/assets/dict")
    ap.add_argument("--built-on", default=dt.datetime.now(dt.timezone.utc).date().isoformat(),
                    help="build day written to the edition file (default: today, UTC)")
    ap.add_argument("--sample-sql", action="store_true",
                    help=f"rewrite {SAMPLE_SQL.relative_to(REPO)} from the made-up samples and stop")
    ap.add_argument("--check", action="store_true",
                    help="build nothing: check the asset in --out-dir against its edition file")
    a = ap.parse_args(argv)
    if a.check:
        return asset_check.report(a.out_dir, names=("wikt-glossary",))
    if a.sample_sql:
        SAMPLE_SQL.parent.mkdir(parents=True, exist_ok=True)
        SAMPLE_SQL.write_text(sample_sql(), encoding="utf-8")
        print(f"wrote {SAMPLE_SQL.relative_to(REPO)}", file=sys.stderr)
        return 0
    if a.kowikt is None or a.en_rows is None or a.kowikt_dump is None:
        ap.error("--kowikt, --kowikt-dump and --en-rows are required (nothing is downloaded here)")
    edition = build_asset(a.kowikt, a.en_rows, a.krdict_dir, a.out_dir, built_on=a.built_on,
                          kowikt_dump=a.kowikt_dump, expect_kowikt_sha256=a.expect_kowikt_sha256,
                          expect_en_sha256=a.expect_en_sha256)
    print(f"wrote {a.out_dir / ASSET_NAME} ({edition['gzip_bytes']:,} bytes, "
          f"SQLite {edition['sqlite_bytes']:,}) and {EDITION_NAME}", file=sys.stderr)
    print(json.dumps(edition, ensure_ascii=False, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
