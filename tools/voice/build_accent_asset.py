#!/usr/bin/env python3
"""Build the app's pitch accent table from the Kanjium accents.txt.

  python3 tools/voice/build_accent_asset.py [--cache DIR] [--source-dir DIR ...] [--offline]
                                            [--out-dir app/assets/accent]

Writes into app/assets/accent/ (not committed):
  kanjium-accents.tsv.gz        one line per word: surface TAB reading TAB accents
  kanjium-accents.edition.json  sizes, sha256, line count, source, licence, attribution

Each line of the source is `surface TAB reading TAB accents`. The reading is left empty
when it is the surface itself (kana words; Kanjium often leaves it empty already). Only
the accent numbers are kept, joined by commas, each once and in order: `(副)1,(名)0`
becomes `1,0`. A line without any accent number is left out. UTF-8 without BOM, every
line ends in `\\n`; the gzip has mtime 0, so the same source and build day give the same
bytes. The source is pinned by URL (a fixed commit) and sha256, and is taken from the
cache (default research/tts/.cache/voice-src), a --source-dir, or downloaded (not with
--offline), like build_voice_asset.py. --check builds nothing and checks the table in
--out-dir. Only the Python 3 standard library is used.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO / "tools" / "dict"))

import asset_check  # noqa: E402
from voice_sources import Source, SourceError, gzip_to, mismatch, obtain  # noqa: E402

VARIANT = "kanjium-accents"
ASSET_NAME, EDITION_NAME = asset_check.ACCENT_FILES
LICENSE = "CC BY-SA 4.0"
# The text the Kanjium README asks applications to show (its section 1).
ATTRIBUTION = ("The pitch accent notation, verb particle data, phonetics, homonyms and other additions "
               "or modifications to EDICT, KANJIDIC or KRADFILE were provided by Uros O. through his "
               "free database.")
KANJIUM_COMMIT = "9ebca4589565c696e7c39e089e2e928ad65f678c"
SOURCE = Source(
    "accents.txt",
    f"https://raw.githubusercontent.com/mifunetoshiro/kanjium/{KANJIUM_COMMIT}/data/source_files/raw/accents.txt",
    3_226_405, "8bd0dd127dab32ceec94cb03ab1ba6b68858ea73421dfa1731af2f373deb4f20",
    "Kanjium accents.txt", LICENSE)
DEFAULT_OUT = REPO / "app" / "assets" / "accent"
DEFAULT_CACHE = REPO / "research" / "tts" / ".cache" / "voice-src"
ACCENT_NUMBER = re.compile(r"[0-9]+")
DAY = re.compile(r"\d{4}-\d{2}-\d{2}")


def convert_line(line: str) -> str | None:
    """One source line as a table line (no newline), or None when it has no accent number."""
    if not line:
        return None
    fields = line.split("\t")
    if len(fields) != 3:
        raise SourceError(f"not 3 tab-separated columns: {line!r}")
    surface, reading, accents = fields
    numbers = list(dict.fromkeys(ACCENT_NUMBER.findall(accents)))
    if not surface or not numbers:
        return None
    if reading == surface:
        reading = ""
    return f"{surface}\t{reading}\t{','.join(numbers)}"


def convert_text(text: str) -> str:
    """The whole table for the whole source text (BOM and CR dropped)."""
    if text.startswith("﻿"):
        text = text[1:]
    lines = (convert_line(line.rstrip("\r")) for line in text.split("\n"))
    return "".join(f"{line}\n" for line in lines if line is not None)


def build_accent_asset(path: Path, out_dir: Path, *, built_on: str, source: Source | None = None) -> dict:
    """Check [path] against the pin, write both files into [out_dir]; returns the edition."""
    source = SOURCE if source is None else source
    if not DAY.fullmatch(built_on):
        sys.exit(f"--built-on must be YYYY-MM-DD, got {built_on!r}")
    problem = mismatch(source, path)
    if problem:
        raise SourceError(f"refusing {path}: {problem}")
    try:
        text = path.read_bytes().decode("utf-8")
    except UnicodeDecodeError as e:
        raise SourceError(f"{path} is not UTF-8 ({e})") from e
    table = convert_text(text).encode("utf-8")
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=out_dir, prefix=".build-") as tmp_name:
        tmp = Path(tmp_name)
        gzip_bytes = gzip_to(table, tmp / ASSET_NAME)
        edition = {
            "variant": VARIANT,
            "built_on": built_on,
            "gzip_bytes": gzip_bytes,
            "tsv_bytes": len(table),
            "tsv_sha256": hashlib.sha256(table).hexdigest(),
            "entries": table.count(b"\n"),
            "source_url": source.url,
            "source_sha256": source.sha256,
            "license": LICENSE,
            "attribution": ATTRIBUTION,
        }
        edition_part = tmp / EDITION_NAME
        edition_part.write_text(json.dumps(edition, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                                encoding="utf-8")
        # Old edition first, new edition last (as build_voice_asset.py does).
        (out_dir / EDITION_NAME).unlink(missing_ok=True)
        os.replace(tmp / ASSET_NAME, out_dir / ASSET_NAME)
        os.replace(edition_part, out_dir / EDITION_NAME)
    return edition


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache", type=Path, default=DEFAULT_CACHE,
                    help="where the source is kept (default: research/tts/.cache/voice-src)")
    ap.add_argument("--source-dir", type=Path, action="append", default=[],
                    help="a folder holding accents.txt (repeatable)")
    ap.add_argument("--offline", action="store_true", help="never download; fail when the file is not at hand")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT, help="default: app/assets/accent")
    ap.add_argument("--built-on", default=dt.datetime.now(dt.timezone.utc).date().isoformat(),
                    help="build day written to the edition file (default: today, UTC)")
    ap.add_argument("--check", action="store_true",
                    help="build nothing: check the table in --out-dir against its edition (asset_check.py)")
    a = ap.parse_args(argv)
    if a.check:
        return asset_check.report(a.out_dir, names=(), accent_dir=a.out_dir)
    try:
        path = obtain(SOURCE, cache=a.cache, source_dirs=a.source_dir, offline=a.offline)
        edition = build_accent_asset(path, a.out_dir, built_on=a.built_on, source=SOURCE)
    except SourceError as e:
        sys.exit(f"error: {e}")
    print(f"wrote {a.out_dir / ASSET_NAME} ({edition['gzip_bytes']:,} bytes, TSV {edition['tsv_bytes']:,}, "
          f"{edition['entries']:,} entries) and {EDITION_NAME}", file=sys.stderr)
    print(json.dumps(edition, ensure_ascii=False, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
