#!/usr/bin/env python3
"""Build the dictionary asset the app ships: JMdict full-lean, gzipped, plus its edition file.

  python3 tools/dict/build_app_asset.py [--expect-sha256 <source sha256>] [--out-dir app/assets/dict]

Writes into --out-dir (default app/assets/dict, git-ignored):
  jmdict-full-lean.sqlite.gz      every JMdict entry, no glosses (docs/dictionary.md 2.3)
  jmdict-full-lean.edition.json   source sha256, JMdict date, build day; the app unpacks again
                                  whenever this file changes and shows it on the 정보 screen

The source is tools/dict/.cache/JMdict_e.gz, downloaded from EDRDG when missing
(build_jmdict_db.py). Same source and build day give byte-identical files.
Only the Python 3 standard library is used.
"""
from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import build_jmdict_db as jmdict  # noqa: E402

VARIANT = "full-lean"
ASSET_NAME = f"jmdict-{VARIANT}.sqlite.gz"
EDITION_NAME = f"jmdict-{VARIANT}.edition.json"
DEFAULT_OUT = HERE.parent.parent / "app" / "assets" / "dict"
DAY = re.compile(r"\d{4}-\d{2}-\d{2}")


def build_asset(source: Path, out_dir: Path, *, built_on: str, expect_sha256: str | None = None,
                url: str = jmdict.DEFAULT_URL) -> dict:
    """Build both files into [out_dir] and return the edition. Exits on a bad source or day."""
    if not DAY.fullmatch(built_on):
        sys.exit(f"--built-on must be YYYY-MM-DD, got {built_on!r}")
    if not source.exists():
        if source.resolve() != jmdict.DEFAULT_SOURCE:
            sys.exit(f"source not found: {source}")
        jmdict.fetch(url, source)
    text, info = jmdict.read_source(source)
    if expect_sha256 and info["source_sha256"] != expect_sha256.lower():
        sys.exit(f"sha256 mismatch: {source} is {info['source_sha256']}, expected {expect_sha256}")
    entities, body = jmdict.split_dtd(text)
    del text

    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=out_dir) as tmp:
        db_path = Path(tmp) / "jmdict.sqlite"
        jmdict.build(entities, body, {"source_url": url, **info}, entries="all", glosses="none", out=db_path)
        raw = db_path.read_bytes()
        packed = gzip.compress(raw, compresslevel=9, mtime=0)
        edition = {
            "variant": VARIANT,
            "source_sha256": info["source_sha256"],
            "jmdict_created": info["jmdict_created"],
            "source_last_modified": info["source_last_modified"],
            "built_on": built_on,
            "sqlite_bytes": len(raw),
            "sqlite_sha256": hashlib.sha256(raw).hexdigest(),
            "gzip_bytes": len(packed),
            "license": jmdict.LICENSE,
        }
        # The app unpacks again only when the edition file changes, so the old
        # edition goes first and the new one last: a build cut short in between
        # leaves no edition file (the app has no dictionary) rather than an old
        # edition next to a new archive.
        gz_part = Path(tmp) / ASSET_NAME
        gz_part.write_bytes(packed)
        edition_part = Path(tmp) / EDITION_NAME
        edition_part.write_text(json.dumps(edition, indent=1, sort_keys=True) + "\n", encoding="utf-8")
        (out_dir / EDITION_NAME).unlink(missing_ok=True)
        os.replace(gz_part, out_dir / ASSET_NAME)
        os.replace(edition_part, out_dir / EDITION_NAME)
    return edition


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", type=Path, default=jmdict.DEFAULT_SOURCE, help="JMdict_e(.gz) path")
    ap.add_argument("--url", default=jmdict.DEFAULT_URL, help="download URL when --source is missing")
    ap.add_argument("--expect-sha256", help="stop unless the source file has this sha256")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT, help="default: app/assets/dict")
    ap.add_argument("--built-on", default=dt.datetime.now(dt.timezone.utc).date().isoformat(),
                    help="build day written to the edition file (default: today, UTC)")
    a = ap.parse_args(argv)
    edition = build_asset(a.source, a.out_dir, built_on=a.built_on, expect_sha256=a.expect_sha256, url=a.url)
    print(f"wrote {a.out_dir / ASSET_NAME} ({edition['gzip_bytes']:,} bytes, "
          f"SQLite {edition['sqlite_bytes']:,}) and {EDITION_NAME}", file=sys.stderr)
    print(json.dumps(edition, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
