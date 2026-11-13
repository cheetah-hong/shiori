#!/usr/bin/env python3
"""Meaning overrides (시오리 보정): a reviewed private table of short Korean meanings -> the app's file.

  python3 tools/dict/build_meaning_overrides.py --built-on YYYY-MM-DD
      [--table $SHIORI_PRIVATE_DIR/meaning/overrides.tsv] [--jmdict-dir app/assets/dict | --jmdict-sqlite FILE]
      [--out-dir app/assets/dict]
  python3 tools/dict/build_meaning_overrides.py --check [same inputs]

The table (tab separated, git-ignored) has a row per word whose dictionary meaning is off: level,
headword, reading, entry (JMdict ent_seq), meaning and reviewed; other columns are left alone.
Every row needs a reviewer in `reviewed`, or `skip` to leave the word as the dictionary has it. A
row's meaning goes to its headword and to the kanji spellings of its entry read so — for a word
written in kanji only those of the same kanji (戸締り, 戸締まり) —; never a kanji word's meaning to its
kana. The meanings
were written from JMdict's English glosses (CC BY-SA 4.0) and are shipped under the same licence.

Out: meaning-overrides.json (one row a line: {"f": spellings, "r": reading, "m": meaning}) and
meaning-overrides.edition.json (table and JMdict, size and sha256 of the file). The same inputs
give the same bytes. --check compares the file with its edition and, when the table and JMdict
the edition names are at hand, with a rebuild.
"""
from __future__ import annotations

import argparse
import contextlib
import csv
import gzip
import hashlib
import io
import json
import os
import re
import sqlite3
import sys
import tempfile
import unicodedata
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEFAULT_OUT = ROOT / "app" / "assets" / "dict"
OVERRIDES_NAME = "meaning-overrides.json"
EDITION_NAME = "meaning-overrides.edition.json"
FORMAT = "shiori-meaning-overrides"
VERSION = 1
COLUMNS = ("level", "headword", "reading", "entry", "meaning", "reviewed")
SKIP = "skip"
LICENSE = "CC BY-SA 4.0"
ATTRIBUTION = ("뜻 보정: 이 앱이 JMdict(EDRDG, CC BY-SA 4.0)의 영어 뜻을 보고 쓴 짧은 한국어 뜻. "
               "CC BY-SA 4.0.")
BUILD_COMMAND = ("python3 tools/dict/build_meaning_overrides.py --built-on <day> "
                 "(table: $SHIORI_PRIVATE_DIR/meaning/overrides.tsv)")
MAX_MEANING = 40
_JAPANESE = re.compile(r"[぀-ヿ㐀-䶿一-鿿豈-﫿々〆]")
_KANA = re.compile(r"^[぀-ヿ]+$")
_DAY = re.compile(r"\d{4}-\d{2}-\d{2}")


class BuildError(Exception):
    """A build stops: a row not reviewed, incomplete, or not about a JMdict word."""


def private_dir() -> Path:
    """$SHIORI_PRIVATE_DIR, else <repo>/.private."""
    return Path(os.environ.get("SHIORI_PRIVATE_DIR") or ROOT / ".private")


def default_table() -> Path:
    return private_dir() / "meaning" / "overrides.tsv"


def hira(s: str) -> str:
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in s)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


@dataclass(frozen=True)
class Entry:
    kanji: tuple[str, ...]
    readings: tuple[str, ...]
    # reading -> the kanji forms it is limited to (absent: all)
    restr: dict[str, tuple[str, ...]]


def read_jmdict(path: Path) -> tuple[dict[int, Entry], str]:
    """The entries of the app's JMdict SQLite (build_jmdict_db.py schema) and its creation day."""
    with contextlib.closing(sqlite3.connect(f"file:{path}?mode=ro", uri=True)) as db:
        kanji: dict[int, list[str]] = {}
        for i, text in db.execute("SELECT entry_id, text FROM kanji ORDER BY entry_id, ord"):
            kanji.setdefault(i, []).append(text)
        readings: dict[int, list[str]] = {}
        restr: dict[int, dict[str, tuple[str, ...]]] = {}
        for i, text, r in db.execute("SELECT entry_id, text, restr FROM reading ORDER BY entry_id, ord"):
            readings.setdefault(i, []).append(text)
            if r:
                restr.setdefault(i, {})[text] = tuple(r.split("\t"))
        ids = [i for (i,) in db.execute("SELECT id FROM entry")]
        meta = dict(db.execute("SELECT key, value FROM meta"))
    entries = {i: Entry(tuple(kanji.get(i, ())), tuple(readings.get(i, ())), restr.get(i, {})) for i in ids}
    return entries, meta.get("jmdict_created", "")


def read_table(path: Path) -> tuple[list[dict], int]:
    """The table's rows to ship and the number of skipped rows; stops on a row not reviewed or
    incomplete."""
    text = path.read_text(encoding="utf-8")
    reader = csv.DictReader(io.StringIO(text), delimiter="\t", quoting=csv.QUOTE_NONE)
    rows = list(reader)
    missing = [c for c in COLUMNS if c not in (reader.fieldnames or [])]
    if missing:
        raise BuildError(f"meaning overrides table needs the columns {', '.join(missing)}")
    kept, skipped = [], 0
    for r in rows:
        cells = {c: unicodedata.normalize("NFC", (r.get(c) or "").strip()) for c in COLUMNS}
        word = f"{cells['level']} {cells['headword']} {cells['reading']} {cells['entry']}"
        if not cells["reviewed"]:
            raise BuildError(f"meaning overrides row not reviewed: {word}")
        if cells["reviewed"].lower() == SKIP:
            skipped += 1
            continue
        for c in ("headword", "reading", "entry", "meaning"):
            if not cells[c]:
                raise BuildError(f"meaning overrides row needs {c}: {word}")
        if not cells["entry"].isdigit():
            raise BuildError(f"meaning overrides entry {cells['entry']!r} is not a number: {word}")
        if _JAPANESE.search(cells["meaning"]):
            raise BuildError(f"meaning overrides meaning has Japanese ({cells['meaning']}): {word}")
        if len(cells["meaning"]) > MAX_MEANING:
            raise BuildError(f"meaning overrides meaning longer than {MAX_MEANING}: {word}")
        kept.append(cells)
    return kept, skipped


def forms_of(row: dict, entries: dict[int, Entry]) -> tuple[list[str], str]:
    """The spellings a row's meaning goes to, and its reading as the entry writes it."""
    seq = int(row["entry"])
    entry = entries.get(seq)
    word = f"{row['headword']} {row['reading']} {seq}"
    if entry is None:
        raise BuildError(f"meaning overrides: entry {seq} is not in JMdict ({word})")
    reading = row["reading"] if row["reading"] in entry.readings else next(
        (r for r in entry.readings if hira(r) == hira(row["reading"])), None)
    if reading is None:
        raise BuildError(f"meaning overrides: entry {seq} is not read {row['reading']} ({word})")
    head = row["headword"]
    kanji = entry.restr.get(reading, entry.kanji)
    if _KANA.match(head):
        if hira(head) != hira(reading):
            raise BuildError(f"meaning overrides: a kana headword is its reading ({word})")
    elif head not in kanji:
        raise BuildError(f"meaning overrides: entry {seq} is not written {head} read {reading} ({word})")
    # A kana word reaches every kanji spelling of its entry; a kanji word only the spellings of the
    # same kanji (戸締り → 戸締まり, never 翔る → 駆ける: other kanji may be another nuance).
    same = (lambda k: True) if _KANA.match(head) else (lambda k: _kanji_of(k) == _kanji_of(head))
    forms = [head] + [k for k in entry.kanji if k in kanji and k != head and same(k)]
    return forms, reading


def _kanji_of(text: str) -> frozenset[str]:
    """The kanji of a spelling, the honorific 御 left out (御飯 and ご飯 are the same kanji), as the
    deck build compares spellings."""
    return frozenset(c for c in text if _JAPANESE.match(c) and not _KANA.match(c)) - {"御"}


def render(rows: list[dict], entries: dict[int, Entry], built_on: str) -> bytes:
    """The file: rows by reading and spelling, each spelling and reading once. A row's own
    headword comes before the spellings other rows reach through their entry (いらいら's row
    reaches 苛々, but 苛々's own row gives 苛々 its meaning); two rows with the same headword and
    reading and different meanings stop the build."""
    # In a fixed order, so the table's own row order never changes the file.
    ordered = sorted(rows, key=lambda r: (hira(r["reading"]), r["headword"], int(r["entry"]), r["meaning"]))
    spelled = [(r, *forms_of(r, entries)) for r in ordered]
    taken: dict[tuple[str, str], str] = {}
    for r, forms, reading in spelled:
        key = (forms[0], hira(reading))
        if key in taken and taken[key] != r["meaning"]:
            raise BuildError(f"meaning overrides: {forms[0]} {reading} twice, as {taken[key]} and {r['meaning']}")
        taken[key] = r["meaning"]
    out = []
    reached: dict[tuple[str, str], str] = {}
    for r, forms, reading in spelled:
        mine = []
        for i, f in enumerate(forms):
            key = (f, hira(reading))
            if i == 0:
                if f in {x for o in out for x in o["f"] if hira(o["r"]) == hira(reading)}:
                    continue
                mine.append(f)
            elif key not in taken:
                taken[key] = r["meaning"]
                reached[key] = r["headword"]
                mine.append(f)
            elif key in reached and taken[key] != r["meaning"]:
                raise BuildError(f"meaning overrides: {f} {reading} reached by {reached[key]} and "
                                 f"{r['headword']} with different meanings")
        if mine:
            out.append({"f": mine, "r": reading, "m": r["meaning"]})
    out.sort(key=lambda x: (hira(x["r"]), x["f"][0], x["m"]))
    head = json.dumps({"format": FORMAT, "version": VERSION, "edition": built_on}, ensure_ascii=False)
    lines = [json.dumps(x, ensure_ascii=False, separators=(",", ":")) for x in out]
    return (head[:-1] + ',"rows":[\n' + ",\n".join(lines) + "\n]}\n").encode("utf-8")


def edition(raw: bytes, *, built_on: str, rows: int, skipped: int, table_sha: str, jmdict_created: str) -> bytes:
    doc = {
        "attribution": ATTRIBUTION,
        "built_on": built_on,
        "format": FORMAT,
        "jmdict_created": jmdict_created,
        "json_bytes": len(raw),
        "json_sha256": hashlib.sha256(raw).hexdigest(),
        "license": LICENSE,
        "rows": rows,
        "skipped": skipped,
        "table_sha256": table_sha,
        "version": VERSION,
    }
    return (json.dumps(doc, ensure_ascii=False, indent=1, sort_keys=True) + "\n").encode("utf-8")


def build_asset(table: Path, jmdict_sqlite: Path, out_dir: Path, *, built_on: str) -> dict:
    """Builds the file and its edition into [out_dir]; returns the edition."""
    if not _DAY.fullmatch(built_on):
        raise BuildError("--built-on is YYYY-MM-DD")
    rows, skipped = read_table(table)
    entries, created = read_jmdict(jmdict_sqlite)
    raw = render(rows, entries, built_on)
    shipped = json.loads(raw)["rows"]
    ed = edition(raw, built_on=built_on, rows=len(shipped), skipped=skipped, table_sha=sha256(table),
                 jmdict_created=created)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / OVERRIDES_NAME).write_bytes(raw)
    (out_dir / EDITION_NAME).write_bytes(ed)
    print(f"meaning overrides: {len(shipped)} rows ({skipped} skipped), {len(raw)} bytes -> {out_dir}")
    return json.loads(ed)


def check(out_dir: Path) -> list[str]:
    """What is wrong with the file in [out_dir] against its edition file."""
    path, edition_path = out_dir / OVERRIDES_NAME, out_dir / EDITION_NAME
    missing = [p.name for p in (path, edition_path) if not p.exists()]
    if missing:
        return [f"meaning overrides: {', '.join(missing)} missing in {out_dir} (build: {BUILD_COMMAND})"]
    raw = path.read_bytes()
    try:
        ed = json.loads(edition_path.read_text(encoding="utf-8"))
        doc = json.loads(raw)
    except (ValueError, UnicodeDecodeError) as e:
        return [f"meaning overrides: unreadable file ({e}) (build: {BUILD_COMMAND})"]
    problems = []
    if ed.get("json_sha256") != hashlib.sha256(raw).hexdigest() or ed.get("json_bytes") != len(raw):
        problems.append(f"meaning overrides: {OVERRIDES_NAME} sha256/size differ from {EDITION_NAME} "
                        f"(build: {BUILD_COMMAND})")
    if doc.get("format") != FORMAT or doc.get("version") != VERSION:
        problems.append(f"meaning overrides: not a {FORMAT} v{VERSION} file")
    elif len(doc.get("rows", [])) != ed.get("rows"):
        problems.append(f"meaning overrides: {len(doc.get('rows', []))} rows, the edition says {ed.get('rows')}")
    return problems


def rebuild_problems(table: Path, jmdict_sqlite: Path | None, out_dir: Path) -> list[str]:
    """With the table and JMdict the edition names at hand, a rebuild must give the same bytes;
    else the byte check is skipped with a line saying why."""
    ed = json.loads((out_dir / EDITION_NAME).read_text(encoding="utf-8"))
    if jmdict_sqlite is None or not table.exists():
        print("meaning overrides: byte check skipped: table or JMdict not found")
        return []
    try:
        created = read_jmdict(jmdict_sqlite)[1]
    except (OSError, sqlite3.Error) as e:
        return [f"meaning overrides: JMdict {jmdict_sqlite} cannot be read: {e}"]
    if sha256(table) != ed.get("table_sha256") or created != ed.get("jmdict_created"):
        print("meaning overrides: byte check skipped: the table or JMdict is not the one the edition names")
        return []
    with tempfile.TemporaryDirectory() as tmp:
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                build_asset(table, jmdict_sqlite, Path(tmp), built_on=ed["built_on"])
        except (BuildError, OSError, sqlite3.Error) as e:
            return [f"meaning overrides: a rebuild of its inputs fails: {e}"]
        return [f"meaning overrides: {name} differs from a rebuild of its inputs (build: {BUILD_COMMAND})"
                for name in (OVERRIDES_NAME, EDITION_NAME)
                if (Path(tmp) / name).read_bytes() != (out_dir / name).read_bytes()]


def jmdict_from_assets(jmdict_dir: Path, work: Path) -> Path | None:
    """The app's JMdict asset in [jmdict_dir] unpacked into [work]; None without it."""
    gz = jmdict_dir / "jmdict-full-lean.sqlite.gz"
    if not gz.exists():
        return None
    out = work / "jmdict.sqlite"
    out.write_bytes(gzip.decompress(gz.read_bytes()))
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="build nothing: check the file against its edition")
    ap.add_argument("--table", type=Path, help="default: $SHIORI_PRIVATE_DIR/meaning/overrides.tsv")
    ap.add_argument("--jmdict-sqlite", type=Path, help="an unpacked JMdict SQLite file (instead of --jmdict-dir)")
    ap.add_argument("--jmdict-dir", type=Path, default=DEFAULT_OUT, help="folder of the JMdict asset (default: app/assets/dict)")
    ap.add_argument("--built-on", help="build day written to the files (YYYY-MM-DD)")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT, help="default: app/assets/dict")
    a = ap.parse_args(argv)
    table = a.table or default_table()
    with tempfile.TemporaryDirectory() as tmp:
        jmdict = a.jmdict_sqlite or jmdict_from_assets(a.jmdict_dir, Path(tmp))
        if a.check:
            problems = check(a.out_dir)
            if not problems:
                problems = rebuild_problems(table, jmdict, a.out_dir)
            for p in problems:
                print(p)
            if not problems:
                print(f"meaning overrides: ok ({a.out_dir / OVERRIDES_NAME})")
            return 1 if problems else 0
        if not a.built_on:
            ap.error("a build needs --built-on")
        if jmdict is None:
            ap.error(f"no JMdict: give --jmdict-sqlite or build the JMdict asset in {a.jmdict_dir}")
        try:
            build_asset(table, jmdict, a.out_dir, built_on=a.built_on)
        except (BuildError, OSError, sqlite3.Error) as e:
            print(f"error: {e}")
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
