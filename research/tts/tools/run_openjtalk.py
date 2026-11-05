#!/usr/bin/env python3
"""Text -> accent estimate of pyopenjtalk (no audio), to compare with VOICEVOX's
own front end.

Accent phrases are read from the NJD features: a phrase starts at a node whose
chain_flag is not 1; its accent is the `acc` of that first node and its length the
sum of `mora_size`. Punctuation nodes (mora_size 0) are skipped.
Note: pyopenjtalk downloads its Open JTalk dictionary on first use.

usage (from research/tts):
  .cache/venv/bin/python tools/run_openjtalk.py --out .cache/results/openjtalk.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import words
from run_voicevox import PARTICLE, load_sentences


def phrases(text: str) -> list[dict]:
    import pyopenjtalk

    out: list[dict] = []
    for node in pyopenjtalk.run_frontend(text):
        if node["mora_size"] == 0:
            continue
        pron = node["pron"].replace("’", "")
        if node["chain_flag"] == 1 and out:
            out[-1]["kana"] += pron
            out[-1]["morae"] += node["mora_size"]
        else:
            out.append({"kana": pron, "morae": node["mora_size"], "acc": node["acc"]})
    for p in out:
        p["nucleus"] = 0 if p["acc"] in (0, p["morae"]) else p["acc"]
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--words", type=Path, default=Path("words.tsv"))
    ap.add_argument("--sentences", type=Path, default=Path("sentences.tsv"))
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    import pyopenjtalk

    word_rows = [{"surface": w.surface, "reading": w.reading, "expected": list(w.expected),
                  "phrases": phrases(w.surface + PARTICLE)}
                 for w in words.load_words(args.words)]
    sent_rows = [{"text": s.text, "expected": [list(p) for p in s.phrases],
                  "phrases": phrases(s.text)} for s in load_sentences(args.sentences)]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"pyopenjtalk": pyopenjtalk.__version__,
                                    "words": word_rows, "sentences": sent_rows},
                                   ensure_ascii=False, indent=1))
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
