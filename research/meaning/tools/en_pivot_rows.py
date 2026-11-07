"""Japanese–Korean rows from en.wiktionary translation tables (research only).

Reads kaikki.org's English JSONL on stdin (one entry per line) and writes,
for every English sense whose translation table has both Japanese and
Korean terms, one JSON line ``{word, sense, ja: [...], ko: [...]}`` —
the same rows the app's builder keeps (tools/dict/wikt_en_rows.py, whose
rules this reuses). gap_sources.build_enwikt reads these rows.

    curl -s --compressed https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl \\
        | python3 en_pivot_rows.py OUT.jsonl
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools" / "dict"))
from wikt_en_rows import pivot_rows, rows_of  # noqa: E402,F401


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    kept = 0
    with open(argv[1], "w", encoding="utf-8") as out:
        for row in rows_of(sys.stdin):
            kept += 1
            out.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"rows {kept}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
