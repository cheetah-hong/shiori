#!/usr/bin/env python3
"""Look up each word of words.tsv in UniDic (aType/aConType) and Kanjium.

UniDic: tokenize the surface with MeCab (fugashi) and keep the analyses (n-best) that
are ONE token whose reading equals the expected reading. Words that UniDic splits
into several tokens (compounds, conjugated forms) get no single value; their tokens
are recorded so the combination can be read by hand.

usage (from research/tts):
  .cache/venv/bin/python tools/lookup_data.py --kanjium .cache/kanjium/accents.txt \
      --out .cache/results/data.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import words

NBEST = 10


def hira_to_kata(text: str) -> str:
    return "".join(chr(ord(c) + 0x60) if "ぁ" <= c <= "ゖ" else c for c in text)


def load_kanjium(path: Path) -> dict[tuple[str, str], tuple[int, ...]]:
    table: dict[tuple[str, str], tuple[int, ...]] = {}
    with path.open(encoding="utf-8") as fh:
        for n, line in enumerate(fh, start=1):
            if not line.strip():
                continue
            try:
                word, reading, accents = words.parse_kanjium_line(line)
            except ValueError as exc:
                print(f"kanjium line {n} skipped: {exc}", file=sys.stderr)
                continue
            table[(word, reading)] = accents
    return table


def unidic_lookup(tagger, surface: str, reading: str) -> dict:
    """Return {"values": [...], "tokens": [...]} for one word."""
    want = hira_to_kata(reading)
    values: list[int] = []
    best_tokens = None
    for path in tagger.nbestToNodeList(surface, NBEST):
        tokens = [(n.surface, n.feature.kana, n.feature.aType, n.feature.aConType)
                  for n in path]
        if best_tokens is None:
            best_tokens = tokens
        if len(tokens) == 1 and tokens[0][1] == want:
            for a in words.parse_atype(tokens[0][2] or "*"):
                if a not in values:
                    values.append(a)
    return {"values": values, "tokens": best_tokens or []}


def make_tagger(dicdir: str):
    import fugashi
    return fugashi.Tagger(f'-d "{dicdir}" -r "{dicdir}/mecabrc"')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--words", type=Path, default=Path("words.tsv"))
    ap.add_argument("--kanjium", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    import unidic
    import unidic_lite

    dicts = {"unidic_lite": unidic_lite.DICDIR, "unidic": unidic.DICDIR}
    taggers = {}
    versions = {}
    for name, d in dicts.items():
        dicdir = Path(d)
        if not (dicdir / "sys.dic").exists():
            print(f"{name}: dictionary not found at {dicdir}", file=sys.stderr)
            return 1
        taggers[name] = make_tagger(d)
        versions[name] = (dicdir / "version").read_text().strip()
    kanjium = load_kanjium(args.kanjium)

    rows = []
    for w in words.load_words(args.words):
        row = {"surface": w.surface, "reading": w.reading, "expected": list(w.expected),
               "kanjium": list(kanjium.get((w.surface, w.reading), ()))}
        for name, tagger in taggers.items():
            row[name] = unidic_lookup(tagger, w.surface, w.reading)
        rows.append(row)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"versions": versions, "kanjium_entries": len(kanjium),
                                    "rows": rows}, ensure_ascii=False, indent=1))
    print(f"wrote {args.out} ({len(rows)} words)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
