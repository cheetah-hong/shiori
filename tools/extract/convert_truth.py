#!/usr/bin/env python3
"""Turn template answers (ground_truth.json with "entries") into word-extraction answers.

  python3 tools/extract/convert_truth.py IN.json OUT.json

Every entry becomes a printed word (headword, readings, meaning) matched by headword; the
template answers list no sentence words, so "scores_sentences" is false (the scorer then
neither scores nor counts words from the page's example sentences). The Dart scorer reads
template answers directly too (ExtractTruth.fromAnyJson); this file is for keeping the
converted answers next to recorded pages. Only the Python 3 standard library is used.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def convert(legacy: dict) -> dict:
    pages = legacy.get("pages")
    if not isinstance(pages, list):
        raise ValueError('template answers need a "pages" list')
    return {
        "_note": "Converted from template answers by tools/extract/convert_truth.py.",
        "format": "general-1",
        "pages": [
            {
                "page": str(p["page"]),
                "fixture": p["fixture"],
                "kind": "template",
                "scores_sentences": False,
                "vocab": [
                    {"headword": e["headword"], "readings": list(e["readings"]), "meaning": e["meaning"]}
                    for e in p["entries"]
                ],
                "sentence_words": [],
                "ignore": [],
            }
            for p in pages
        ],
    }


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    src, dst = Path(argv[0]), Path(argv[1])
    out = convert(json.loads(src.read_text(encoding="utf-8")))
    dst.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {dst} ({sum(len(p['vocab']) for p in out['pages'])} words)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
