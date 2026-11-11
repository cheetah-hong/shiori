#!/usr/bin/env python3
"""Build the example sentence asset the app ships: one Tatoeba sentence per JMdict entry
(and reading), for study cards whose page printed no example.

  python3 tools/dict/build_examples.py --tatoeba-dir <folder of the exports> --tatoeba-export YYYY-MM-DD
      [--expect-sha256 NAME=HEX ...] [--jmdict-dir app/assets/dict] [--out-dir app/assets/dict]
  python3 tools/dict/build_examples.py --sample-sql   # test fixture of packages/example_block
  python3 tools/dict/build_examples.py --check [--out-dir app/assets/dict]

Source (not in the repository, nothing is downloaded here; docs/dictionary.md 14 has the
commands): the Tatoeba weekly exports, https://downloads.tatoeba.org/exports/ —
per_language/jpn/jpn_sentences_detailed.tsv.bz2, jpn_indices.tar.bz2 (the word indices,
the Tanaka Corpus "B lines"), per_language/jpn/jpn-kor_links.tsv.bz2,
per_language/kor/kor_sentences_detailed.tsv.bz2, per_language/jpn/jpn-eng_links.tsv.bz2,
per_language/eng/eng_sentences.tsv.bz2 and per_language/jpn/jpn_tags.tsv.bz2 (plain .tsv /
jpn_indices.csv are read too). Tatoeba serves the latest export only: the sha256 of every
file goes into the edition file, and --expect-sha256 stops a build on another file.
Licence: CC BY 2.0 FR (no share-alike).

Rules (docs/dictionary.md 14; the survey is research/examples/README.md):
- A sentence is filed under every JMdict entry its index names: the index gives each word in
  its dictionary form (汚す{汚して}), its reading when ambiguous (空(から)) or the entry
  itself (が(#2028930)). Entries come from the app's JMdict asset; a word in kana stands for
  its kana-only common entry, else the usually-kana common one, else (in that order)
  kana-only, usually-kana, common, all.
- Under an entry with more than one reading the row names the reading the sentence uses
  (from the index, else a kana surface); '' when it is not known or the entry has one.
- A card sentence: MIN_LEN..MAX_LEN characters with kana, no Hangul, Latin letters, list
  marks or markup, no Tatoeba tag of BAD_TAGS, no word of SENSITIVE.
- Per entry and reading the best one: a Korean translation of this very sentence, then the
  index's "good and checked" mark (~), then an English translation, then fewest kanji
  outside KNOWN_NF (kanji of the most frequent words, a stand-in for the JLPT N5-N3 lists
  the survey used, which cannot ship), then a full sentence, then nearest TARGET_LEN
  characters, then the lowest sentence number.
- ko: the Korean sentence linked to it (the lowest number); en only without ko.
Writes examples.sqlite.gz and examples.edition.json into --out-dir (git-ignored). Same
inputs and build day give byte-identical files. Only the Python 3 standard library is used.
"""
from __future__ import annotations

import argparse
import bz2
import contextlib
import datetime as dt
import gzip
import hashlib
import io
import json
import os
import re
import sqlite3
import sys
import tarfile
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, NamedTuple

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))

import asset_check  # noqa: E402

DEFAULT_OUT = REPO / "app" / "assets" / "dict"
SAMPLE_DIR = HERE / "testdata" / "tatoeba_sample"
SAMPLE_JMDICT = REPO / "packages" / "dict_jmdict" / "test" / "fixtures" / "mini_jmdict.sql"
SAMPLE_SQL = REPO / "packages" / "example_block" / "test" / "fixtures" / "mini_examples.sql"
SAMPLE_BUILT_ON = "2026-11-12"
SAMPLE_EXPORT = "2026-11-07"

ASSET_NAME, EDITION_NAME = "examples.sqlite.gz", "examples.edition.json"
SCHEMA_VERSION = 1
VARIANT = "one-per-reading"

LICENSE = "CC BY 2.0 FR"
LICENSE_URL = "https://creativecommons.org/licenses/by/2.0/fr/"
TATOEBA_URL = "https://tatoeba.org"
SOURCE = {"source": "tatoeba", "name": "Tatoeba", "publisher": "Tatoeba 기여자",
          "license": LICENSE, "license_url": LICENSE_URL, "url": TATOEBA_URL}

# Logical name -> the file names it may have (the export, then a plain copy).
SOURCE_FILES = {
    "jpn_sentences_detailed": ("jpn_sentences_detailed.tsv.bz2", "jpn_sentences_detailed.tsv"),
    "jpn_indices": ("jpn_indices.tar.bz2", "jpn_indices.csv"),
    "jpn-kor_links": ("jpn-kor_links.tsv.bz2", "jpn-kor_links.tsv"),
    "kor_sentences_detailed": ("kor_sentences_detailed.tsv.bz2", "kor_sentences_detailed.tsv"),
    "jpn-eng_links": ("jpn-eng_links.tsv.bz2", "jpn-eng_links.tsv"),
    "eng_sentences": ("eng_sentences.tsv.bz2", "eng_sentences.tsv"),
    "jpn_tags": ("jpn_tags.tsv.bz2", "jpn_tags.tsv"),
}

MIN_LEN, MAX_LEN, TARGET_LEN = 6, 30, 14
# Kanji of the words with an nfXX band at most this (the 5,000 most frequent) count as known.
KNOWN_NF = 10
COMMON_MASK = 1 | 4 | 16 | 32 | 64  # news1 ichi1 spec1 spec2 gai1 (packages/core lexicon.dart)

# Tatoeba tags that mark a sentence as unfit for a learner's card.
BAD_TAGS = frozenset({
    "@needs native check", "not a sentence", "@possible copyright infringement",
    "Classical Japanese (Bungo)", "old kana", "@change", "@check translation",
    "@wrong transliteration", "extra-long sentence", "dialectal", "Kansai dialect",
    "vulgar", "@check", "@delete", "@neologism", "old-fashioned", "poetry",
    "not for WWWJDIC", "@needs native check (jpn)",
})
# Words a learner's card does not show (a coarse net: research/examples/README.md 2.2).
SENSITIVE = (
    "殺", "死ね", "自殺", "死体", "セックス", "性交", "レイプ", "強姦", "売春",
    "麻薬", "覚醒剤", "爆弾", "テロ", "拳銃", "ヌード", "裸", "エロ", "ポルノ",
    "売女", "ばか野郎", "くそ", "クソ", "畜生", "ちくしょう", "黒人", "ユダヤ",
    "ナチ", "ヒトラー", "レズ", "ホモ", "おっぱい", "ちんちん", "ちんこ", "まんこ",
)

_KANA = "ぁ-ゖァ-ヺー"
_KANJI = "㐀-䶿一-鿿豈-﫿々"
_KANA_RE = re.compile(f"[{_KANA}]")
_KANJI_RE = re.compile(f"[{_KANJI}]")
_KANA_ONLY = re.compile(f"^[{_KANA}]+$")
_HANGUL = re.compile("[가-힣ㄱ-ㆎ]")
_LATIN = re.compile("[A-Za-z]")
_NOT_A_SENTENCE = "/／＝=;；^:："
_ENDS = "。！？!?」』…"
_DAY = re.compile(r"\d{4}-\d{2}-\d{2}")
_SHA256 = re.compile(r"[0-9a-f]{64}")


# ------------------------------------------------------------------ text


def is_card_sentence(text: str) -> bool:
    t = text.strip()
    return (MIN_LEN <= len(t) <= MAX_LEN and bool(_KANA_RE.search(t)) and not _HANGUL.search(t)
            and not _LATIN.search(t) and not any(c in t for c in _NOT_A_SENTENCE))


def is_sensitive(text: str) -> bool:
    return any(w in text for w in SENSITIVE)


def to_hiragana(text: str) -> str:
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in text)


def reading_agrees(seen: str, reading: str) -> bool:
    """[seen] (a reading or a kana surface) is [reading] up to its inflected last kana."""
    a, b = to_hiragana(seen), to_hiragana(reading)
    n = max(1, len(b) - 1)
    return a[:n] == b[:n]


class IndexWord(NamedTuple):
    headword: str
    reading: str | None
    surface: str | None
    checked: bool


# headword(reading)[sense]{surface}~ ; every part after the headword optional.
_BWORD = re.compile(r"^(?P<h>[^(\[{~]+)(?:\((?P<r>[^)]*)\))?(?:\[(?P<s>\d+)\])?"
                    r"(?:\{(?P<f>[^}]*)\})?(?P<c>~)?$")


def parse_bline(line: str) -> list[IndexWord]:
    """``は 二十歳(はたち){２０歳} 為る(する){しました}~`` → its words; malformed tokens go."""
    out = []
    for tok in line.split():
        m = _BWORD.match(tok)
        if m:
            out.append(IndexWord(m["h"], m["r"] or None, m["f"] or None, bool(m["c"])))
    return out


# ------------------------------------------------------------------ JMdict


@dataclass(frozen=True)
class Entry:
    id: int
    readings: tuple[str, ...]
    kana_only: bool
    usually_kana: bool
    common_readings: frozenset[str]


class Jmdict:
    """The app's JMdict SQLite (build_jmdict_db.py schema), as far as the join needs it."""

    def __init__(self, db: sqlite3.Connection):
        misc = {i: set(m.split()) for i, m in db.execute("SELECT id, misc FROM entry")}
        kanji: dict[int, list[str]] = {}
        self.by_kanji: dict[str, list[int]] = {}
        self.known_kanji: set[str] = set()
        for i, text, nf in db.execute("SELECT entry_id, text, nf FROM kanji ORDER BY entry_id, ord"):
            kanji.setdefault(i, []).append(text)
            self.by_kanji.setdefault(text, []).append(i)
            if nf is not None and nf <= KNOWN_NF:
                self.known_kanji |= set(_KANJI_RE.findall(text))
        readings: dict[int, list[str]] = {}
        common: dict[int, set[str]] = {}
        self.by_reading: dict[str, list[int]] = {}
        for i, text, pri in db.execute("SELECT entry_id, text, pri FROM reading ORDER BY entry_id, ord"):
            readings.setdefault(i, []).append(text)
            self.by_reading.setdefault(text, []).append(i)
            if pri & COMMON_MASK:
                common.setdefault(i, set()).add(text)
        self.entries = {
            i: Entry(i, tuple(readings.get(i, ())), i not in kanji, "uk" in m, frozenset(common.get(i, ())))
            for i, m in misc.items()}
        meta = dict(db.execute("SELECT key, value FROM meta")) if _has_table(db, "meta") else {}
        self.created = meta.get("jmdict_created", "")

    def lookup(self, word: IndexWord) -> list[Entry]:
        """The entries an index word names."""
        if word.reading and word.reading.startswith("#"):
            e = self.entries.get(int(word.reading[1:])) if word.reading[1:].isdigit() else None
            return [e] if e else []
        ids = self.by_kanji.get(word.headword)
        found = [self.entries[i] for i in ids] if ids else self._kana(word.headword)
        if word.reading:
            narrowed = [e for e in found if word.reading in e.readings]
            if narrowed:
                return narrowed
        return found

    def _kana(self, form: str) -> list[Entry]:
        read = [self.entries[i] for i in self.by_reading.get(form, ())]
        for keep in (lambda e: e.kana_only and form in e.common_readings,
                     lambda e: e.usually_kana and form in e.common_readings,
                     lambda e: e.kana_only, lambda e: e.usually_kana,
                     lambda e: form in e.common_readings):
            kept = [e for e in read if keep(e)]
            if kept:
                return kept
        return read


def _has_table(db: sqlite3.Connection, name: str) -> bool:
    return db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)).fetchone() is not None


def reading_key(entry: Entry, word: IndexWord) -> str:
    """The entry's reading the sentence uses; '' for one reading or when not known."""
    if len(entry.readings) < 2:
        return ""
    seen = word.reading if word.reading and not word.reading.startswith("#") else (
        word.surface if word.surface and _KANA_ONLY.match(word.surface) else None)
    if not seen:
        return ""
    if seen in entry.readings:
        return seen
    return next((r for r in entry.readings if reading_agrees(seen, r)), "")


# ------------------------------------------------------------------ Tatoeba files


def source_paths(folder: Path) -> dict[str, Path]:
    """The file of every SOURCE_FILES name in [folder]; exits naming a missing one."""
    out = {}
    for name, candidates in SOURCE_FILES.items():
        path = next((folder / c for c in candidates if (folder / c).is_file()), None)
        if path is None:
            sys.exit(f"{folder}: no {' or '.join(candidates)} (see --help for where to get it)")
        out[name] = path
    return out


def _lines(path: Path) -> Iterator[str]:
    if path.name.endswith(".tar.bz2"):
        with tarfile.open(path, "r:bz2") as tar:
            member = next((m for m in tar.getmembers() if m.isfile()), None)
            if member is None:
                sys.exit(f"{path}: empty archive")
            with io.TextIOWrapper(tar.extractfile(member), encoding="utf-8") as f:
                yield from f
        return
    opener = bz2.open if path.suffix == ".bz2" else open
    with opener(path, "rt", encoding="utf-8") as f:
        yield from f


def _cells(path: Path, n: int) -> Iterator[list[str]]:
    for line in _lines(path):
        cells = line.rstrip("\n").split("\t")
        if len(cells) >= n and cells[0].isdigit():
            yield cells


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def _texts(path: Path) -> dict[int, str]:
    return {int(c[0]): c[2] for c in _cells(path, 3)}


def _first_links(path: Path) -> dict[int, list[int]]:
    out: dict[int, list[int]] = {}
    for c in _cells(path, 2):
        if c[1].isdigit():
            out.setdefault(int(c[0]), []).append(int(c[1]))
    return {k: sorted(v) for k, v in out.items()}


def _translation(sid: int, links: dict[int, list[int]], texts: dict[int, str]) -> str | None:
    return next((texts[t] for t in links.get(sid, ()) if t in texts), None)


# ------------------------------------------------------------------ choosing


class Candidate(NamedTuple):
    sentence: int
    ja: str
    ko: str | None
    en: str | None
    surface: str | None
    checked: bool


def rank(c: Candidate, known_kanji: set[str]) -> tuple:
    unknown = len(set(_KANJI_RE.findall(c.ja)) - known_kanji)
    return (c.ko is None, not c.checked, c.en is None, unknown, c.ja.strip()[-1:] not in _ENDS,
            abs(len(c.ja) - TARGET_LEN), c.sentence)


def choose(paths: dict[str, Path], jm: Jmdict) -> dict[tuple[int, str], Candidate]:
    """The best card sentence per (entry, reading)."""
    jpn = _texts(paths["jpn_sentences_detailed"])
    kor = _texts(paths["kor_sentences_detailed"])
    eng = _texts(paths["eng_sentences"])
    to_kor = _first_links(paths["jpn-kor_links"])
    to_eng = _first_links(paths["jpn-eng_links"])
    tags: dict[int, set[str]] = {}
    for c in _cells(paths["jpn_tags"], 2):
        tags.setdefault(int(c[0]), set()).add(c[1])
    best: dict[tuple[int, str], Candidate] = {}
    for c in _cells(paths["jpn_indices"], 3):
        sid = int(c[0])
        ja = jpn.get(sid)
        if ja is None or not is_card_sentence(ja) or is_sensitive(ja) or tags.get(sid, set()) & BAD_TAGS:
            continue
        ko = _translation(sid, to_kor, kor)
        en = None if ko else _translation(sid, to_eng, eng)
        seen: set[tuple[int, str]] = set()
        for word in parse_bline(c[2]):
            for entry in jm.lookup(word):
                key = (entry.id, reading_key(entry, word))
                if key in seen:
                    continue
                seen.add(key)
                cand = Candidate(sid, ja.strip(), ko, en, word.surface, word.checked)
                old = best.get(key)
                if old is None or rank(cand, jm.known_kanji) < rank(old, jm.known_kanji):
                    best[key] = cand
    return best


# ------------------------------------------------------------------ database

SCHEMA = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
CREATE TABLE example (
  entry INTEGER NOT NULL,   -- JMdict ent_seq
  reading TEXT NOT NULL,    -- the entry's reading the sentence uses; '' = any
  sentence INTEGER NOT NULL,-- Tatoeba sentence number
  ja TEXT NOT NULL,
  ko TEXT,                  -- Korean translation of this sentence
  en TEXT,                  -- English translation, only without ko
  surface TEXT,             -- the word as written in the sentence, when the index gives it
  PRIMARY KEY (entry, reading)
) WITHOUT ROWID;
"""


def _fill(db: sqlite3.Connection, best: dict[tuple[int, str], Candidate], *, built_on: str,
          export: str, jmdict_created: str) -> dict[str, str]:
    db.executescript(SCHEMA)
    db.executemany("INSERT INTO example VALUES (?,?,?,?,?,?,?)", [
        (entry, reading, c.sentence, c.ja, c.ko, c.en, c.surface)
        for (entry, reading), c in sorted(best.items())])
    meta = {
        "schema": str(SCHEMA_VERSION), "variant": VARIANT, "built_on": built_on,
        "source": "tatoeba", "tatoeba.edition": export, "tatoeba.license": LICENSE,
        "tatoeba.license_url": LICENSE_URL, "tatoeba.url": TATOEBA_URL,
        "jmdict_created": jmdict_created, "examples": str(len(best)),
    }
    db.executemany("INSERT INTO meta VALUES (?,?)", sorted(meta.items()))
    db.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
    return meta


def _counts(best: dict[tuple[int, str], Candidate]) -> dict[str, int]:
    korean = sum(c.ko is not None for c in best.values())
    english = sum(c.ko is None and c.en is not None for c in best.values())
    return {"examples": len(best), "entries": len({e for e, _ in best}), "korean": korean,
            "english": english, "untranslated": len(best) - korean - english}


def _check_days(**days: str) -> None:
    for name, day in days.items():
        if not _DAY.fullmatch(day or ""):
            sys.exit(f"--{name.replace('_', '-')} must be YYYY-MM-DD, got {day!r}")


def build_asset(tatoeba_dir: Path, jmdict_sqlite: Path, out_dir: Path, *, built_on: str,
                tatoeba_export: str, expect_sha256: dict[str, str] | None = None) -> dict:
    """Build the gzip and its edition file into [out_dir] and return the edition."""
    _check_days(built_on=built_on, tatoeba_export=tatoeba_export)
    paths = source_paths(Path(tatoeba_dir))
    files = {name: _sha256(path) for name, path in paths.items()}
    for name, want in (expect_sha256 or {}).items():
        if name not in files:
            sys.exit(f"--expect-sha256: no source file named {name} ({', '.join(SOURCE_FILES)})")
        if files[name] != want.lower():
            sys.exit(f"sha256 mismatch: {paths[name]} is {files[name]}, expected {want}")
    with contextlib.closing(sqlite3.connect(f"file:{jmdict_sqlite}?mode=ro", uri=True)) as db:
        jm = Jmdict(db)
    best = choose(paths, jm)
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=out_dir) as tmp:
        db_path = Path(tmp) / "examples.sqlite"
        db = sqlite3.connect(db_path)
        try:
            _fill(db, best, built_on=built_on, export=tatoeba_export, jmdict_created=jm.created)
            db.commit()
            db.execute("VACUUM")
        finally:
            db.close()
        raw = db_path.read_bytes()
        packed = gzip.compress(raw, compresslevel=9, mtime=0)
        manifest = "\n".join(f"{n} {files[n]}" for n in sorted(files))
        edition = {
            "variant": VARIANT,
            "schema": SCHEMA_VERSION,
            "built_on": built_on,
            "sources": [{**SOURCE, "edition": tatoeba_export,
                         "source_sha256": hashlib.sha256(manifest.encode()).hexdigest()}],
            "files": files,
            "attribution": f"Tatoeba ({TATOEBA_URL}) 문장, {LICENSE}, {tatoeba_export} 내보내기",
            "jmdict_created": jm.created,
            **_counts(best),
            "sqlite_bytes": len(raw),
            "sqlite_sha256": hashlib.sha256(raw).hexdigest(),
            "gzip_bytes": len(packed),
        }
        # As the other builders: the old edition goes first and the new one last.
        gz_part = Path(tmp) / ASSET_NAME
        gz_part.write_bytes(packed)
        edition_part = Path(tmp) / EDITION_NAME
        edition_part.write_text(json.dumps(edition, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                                encoding="utf-8")
        (out_dir / EDITION_NAME).unlink(missing_ok=True)
        os.replace(gz_part, out_dir / ASSET_NAME)
        os.replace(edition_part, out_dir / EDITION_NAME)
    return edition


def jmdict_from_assets(jmdict_dir: Path, work: Path) -> Path:
    """The app's JMdict asset in [jmdict_dir], checked against its edition, unpacked into [work]."""
    gz_name, edition_name = asset_check.ASSETS["jmdict-full-lean"]
    jmdict_dir = Path(jmdict_dir)
    problems = asset_check.check_asset("jmdict-full-lean", jmdict_dir / gz_name, jmdict_dir / edition_name)
    if problems:
        sys.exit("the JMdict asset does not match its edition: " + "; ".join(problems))
    work = Path(work)
    work.mkdir(parents=True, exist_ok=True)
    out = work / "jmdict.sqlite"
    out.write_bytes(gzip.decompress((jmdict_dir / gz_name).read_bytes()))
    return out


def sample_sql() -> str:
    """The sample built as SQL text (packages/example_block loads it in memory)."""
    with tempfile.TemporaryDirectory() as tmp:
        jm_path = Path(tmp) / "jmdict.sqlite"
        with contextlib.closing(sqlite3.connect(jm_path)) as db:
            db.executescript(SAMPLE_JMDICT.read_text(encoding="utf-8"))
        with contextlib.closing(sqlite3.connect(f"file:{jm_path}?mode=ro", uri=True)) as db:
            jm = Jmdict(db)
        best = choose(source_paths(SAMPLE_DIR), jm)
    db = sqlite3.connect(":memory:")
    try:
        _fill(db, best, built_on=SAMPLE_BUILT_ON, export=SAMPLE_EXPORT, jmdict_created=jm.created)
        lines = [line for line in db.iterdump() if line not in ("BEGIN TRANSACTION;", "COMMIT;")]
    finally:
        db.close()
    head = ["-- Built by tools/dict/build_examples.py --sample-sql from",
            "-- tools/dict/testdata/tatoeba_sample/ (made-up sentences) and the JMdict test",
            "-- fixture of packages/dict_jmdict. Do not edit.",
            f"PRAGMA user_version = {SCHEMA_VERSION};"]
    return "\n".join(head + lines) + "\n"


def _expectations(pairs: list[str]) -> dict[str, str]:
    out = {}
    for pair in pairs:
        name, _, value = pair.partition("=")
        if not name or not _SHA256.fullmatch(value.lower()):
            sys.exit(f"--expect-sha256 wants NAME=<sha256>, got {pair!r}")
        out[name] = value.lower()
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tatoeba-dir", type=Path, help="folder of the Tatoeba export files")
    ap.add_argument("--tatoeba-export", help="day of that export (YYYY-MM-DD, its Last-Modified)")
    ap.add_argument("--expect-sha256", action="append", default=[], metavar="NAME=HEX",
                    help=f"stop unless that file has this sha256 ({', '.join(SOURCE_FILES)})")
    ap.add_argument("--jmdict-dir", type=Path, default=DEFAULT_OUT,
                    help="folder of the JMdict asset the sentences are joined to (default: app/assets/dict)")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT, help="default: app/assets/dict")
    ap.add_argument("--built-on", default=dt.datetime.now(dt.timezone.utc).date().isoformat(),
                    help="build day written to the edition file (default: today, UTC)")
    ap.add_argument("--sample-sql", action="store_true",
                    help=f"rewrite {SAMPLE_SQL.relative_to(REPO)} from the made-up sample and stop")
    ap.add_argument("--check", action="store_true",
                    help="build nothing: check the asset in --out-dir against its edition file")
    a = ap.parse_args(argv)
    if a.check:
        return asset_check.report(a.out_dir, names=("examples",))
    if a.sample_sql:
        SAMPLE_SQL.parent.mkdir(parents=True, exist_ok=True)
        SAMPLE_SQL.write_text(sample_sql(), encoding="utf-8")
        print(f"wrote {SAMPLE_SQL.relative_to(REPO)}", file=sys.stderr)
        return 0
    if a.tatoeba_dir is None or a.tatoeba_export is None:
        ap.error("--tatoeba-dir and --tatoeba-export are required (nothing is downloaded here)")
    expect = _expectations(a.expect_sha256)
    with tempfile.TemporaryDirectory() as tmp:
        jm = jmdict_from_assets(a.jmdict_dir, Path(tmp))
        edition = build_asset(a.tatoeba_dir, jm, a.out_dir, built_on=a.built_on,
                              tatoeba_export=a.tatoeba_export, expect_sha256=expect)
    print(f"wrote {a.out_dir / ASSET_NAME} ({edition['gzip_bytes']:,} bytes, "
          f"SQLite {edition['sqlite_bytes']:,}) and {EDITION_NAME}", file=sys.stderr)
    print(json.dumps(edition, ensure_ascii=False, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
