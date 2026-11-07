#!/usr/bin/env python3
"""Japanese–Korean rows from the English Wiktionary, kept while the raw dump downloads.

  curl -s https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz \\
      | python3 tools/dict/wikt_en_rows.py --dump 2026-10-01 --out en-rows.jsonl [--expect-sha256 HEX]
  python3 tools/dict/wikt_en_rows.py --source raw-wiktextract-data.jsonl.gz --dump 2026-10-01 --out …

The raw file (kaikki.org, wiktextract of the enwiktionary dump, about 3 GB gzip) is too
big to keep, so it is read once from stdin (or --source) and only the rows the Korean
fallback glossary needs are written: for every English entry, each sense of its
translation table that has both a Japanese and a Korean term. The sha256 and size of
the gzip as read are written in the first line of the output, so the rows file names the
exact dump it came from; with --expect-sha256 a different dump writes nothing and exits 1.
build_wikt_glossary.py reads the rows file. Only the Python 3 standard library is used.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import BinaryIO, Iterable, Iterator

ROWS_KIND = "enwikt-ja-ko-rows"
SOURCE_URL = "https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz"
DAY = re.compile(r"\d{4}-\d{2}-\d{2}")
_CHUNK = 1 << 20


class HashingReader:
    """A binary stream that hashes and counts every byte read from it."""

    def __init__(self, inner: BinaryIO) -> None:
        self._inner = inner
        self.sha256 = hashlib.sha256()
        self.size = 0

    def read(self, n: int = -1) -> bytes:
        data = self._inner.read(n)
        self.sha256.update(data)
        self.size += len(data)
        return data

    def drain(self) -> None:
        """Read (and hash) whatever is left, e.g. bytes after the gzip stream."""
        while self.read(_CHUNK):
            pass


def pivot_rows(entry: dict) -> list[dict]:
    """The rows of one English entry: its translations grouped by the English
    sense they translate, kept when a group has both a Japanese and a Korean term."""
    if entry.get("lang_code") not in (None, "en"):
        return []
    translations = list(entry.get("translations") or [])
    for s in entry.get("senses") or []:
        translations += s.get("translations") or []
    groups: dict[str, dict[str, list[dict]]] = {}
    for t in translations:
        lang = t.get("lang_code") or t.get("code")
        if lang not in ("ja", "ko") or not t.get("word"):
            continue
        g = groups.setdefault(t.get("sense") or "", {"ja": [], "ko": []})
        g[lang].append({"word": t["word"], "alt": t.get("alt")})
    return [
        {"word": entry.get("word"), "sense": sense, "ja": g["ja"], "ko": g["ko"]}
        for sense, g in groups.items()
        if g["ja"] and g["ko"]
    ]


def rows_of(lines: Iterable[str]) -> Iterator[dict]:
    """The rows of JSONL entries (lines naming neither language are not parsed)."""
    for line in lines:
        if '"ja"' not in line or '"ko"' not in line:
            continue
        yield from pivot_rows(json.loads(line))


def extract(stream: BinaryIO, out: Path, *, dump: str, expect_sha256: str | None = None,
            source_url: str = SOURCE_URL) -> dict:
    """Write the rows of the gzip [stream] to [out] (header line first) and return the
    header. Nothing is written when the stream's sha256 is not [expect_sha256]."""
    if not DAY.fullmatch(dump):
        sys.exit(f"--dump must be YYYY-MM-DD, got {dump!r}")
    reader = HashingReader(stream)
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=out.parent, delete=False,
                                     suffix=".part") as body:
        try:
            with gzip.open(reader, "rt", encoding="utf-8") as text:  # type: ignore[arg-type]
                for row in rows_of(text):
                    body.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
                    count += 1
            reader.drain()
        except (OSError, EOFError, UnicodeDecodeError, json.JSONDecodeError) as e:
            body.close()
            os.unlink(body.name)
            sys.exit(f"not a wiktextract gzip JSONL stream ({e})")
    digest = reader.sha256.hexdigest()
    if expect_sha256 and digest != expect_sha256.lower():
        os.unlink(body.name)
        sys.exit(f"sha256 mismatch: the stream is {digest}, expected {expect_sha256}")
    header = {"kind": ROWS_KIND, "source_url": source_url, "source_sha256": digest,
              "source_bytes": reader.size, "dump": dump, "rows": count}
    # The finished file replaces [out] in one step: a run cut short leaves no half file.
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=out.parent, delete=False,
                                     suffix=".part") as f, open(body.name, encoding="utf-8") as b:
        f.write(json.dumps(header, ensure_ascii=False, sort_keys=True) + "\n")
        for line in b:
            f.write(line)
    os.unlink(body.name)
    os.replace(f.name, out)
    return header


def read_rows(path: Path) -> tuple[dict, list[dict]]:
    """(header, rows) of a rows file; exits on a file this script did not write."""
    with open(path, encoding="utf-8") as f:
        try:
            header = json.loads(f.readline())
        except json.JSONDecodeError as e:
            sys.exit(f"{path}: not a rows file ({e})")
        if not isinstance(header, dict) or header.get("kind") != ROWS_KIND:
            sys.exit(f"{path}: not a rows file of {Path(__file__).name}")
        try:
            rows = [json.loads(line) for line in f if line.strip()]
        except json.JSONDecodeError as e:
            sys.exit(f"{path}: a row does not read ({e}; cut short?)")
    if len(rows) != header.get("rows"):
        sys.exit(f"{path}: {len(rows)} rows, the header says {header.get('rows')} (cut short?)")
    return header, rows


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", type=Path, help="the raw gzip (default: read stdin)")
    ap.add_argument("--dump", required=True, help="date of the enwiktionary dump (YYYY-MM-DD)")
    ap.add_argument("--out", type=Path, required=True, help="the rows file to write")
    ap.add_argument("--expect-sha256", help="write nothing unless the gzip has this sha256")
    ap.add_argument("--source-url", default=SOURCE_URL, help="where the gzip came from (written in the header)")
    a = ap.parse_args(argv)
    if a.source is not None:
        with open(a.source, "rb") as f:
            header = extract(f, a.out, dump=a.dump, expect_sha256=a.expect_sha256, source_url=a.source_url)
    else:
        header = extract(sys.stdin.buffer, a.out, dump=a.dump, expect_sha256=a.expect_sha256,
                         source_url=a.source_url)
    print(json.dumps(header, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
