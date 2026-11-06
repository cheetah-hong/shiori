#!/usr/bin/env python3
"""Score WAV files made by another speech engine (a phone's built-in voice) with
the same rough rule as the macOS baseline (`run_kyoko.py`).

Each word is expected as `<audio-dir>/<surface>_<reading>_<tag>.wav`, spoken as
word + が. The voiced stretch is cut into equal parts (morae + 1), read with the
pitch rule, and scored three ways:
  - strict: the H/L pattern matches an expected one,
  - loose: the same without the last mora (the sentence-final fall pulls it down),
  - contrast: the order checks of the minimal sets (make_report.contrast_checks),
and pairs with the same reading whose parts are all within 0.01 are listed
(the engine said them the same way, so one of a differing pair is wrong).

usage (from research/tts):
  .cache/venv/bin/python tools/measure_wavs.py --audio-dir <dir> --tag ios-kyoko \
      --out .cache/results/ios-kyoko.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import accent
import pitch
import words
from make_report import contrast_checks
from run_kyoko import equal_split_f0

SAME_TOLERANCE = 0.01


def measure(audio_dir: Path, tag: str, word_list: list[words.Word]) -> list[dict]:
    rows = []
    for w in word_list:
        wav = audio_dir / f"{w.surface}_{w.reading}_{tag}.wav"
        if not wav.exists():
            rows.append({"surface": w.surface, "reading": w.reading,
                         "expected": list(w.expected), "missing": True})
            continue
        f0 = equal_split_f0(wav, w.morae + 1)
        patt = pitch.pitch_pattern(f0) if any(x > 0 for x in f0) else "?" * len(f0)
        rows.append({"surface": w.surface, "reading": w.reading, "expected": list(w.expected),
                     "f0": f0, "pattern": patt, "wav": wav.name})
    return rows


def summarize(rows: list[dict]) -> dict:
    present = [r for r in rows if not r.get("missing")]
    strict = loose = 0
    for r in present:
        n = accent.count_morae(r["reading"])
        exp = [accent.pattern_for(a, n) for a in r["expected"]]
        strict += any(accent.patterns_match(e, r["pattern"]) for e in exp)
        loose += any(accent.patterns_match(e[:-1], r["pattern"][:-1]) for e in exp)
    checks = contrast_checks([dict(r, m=[{"pitches": r["f0"]}]) for r in present], "m")
    same = [
        (a["surface"], b["surface"])
        for i, a in enumerate(present) for b in present[i + 1:]
        if a["reading"] == b["reading"] and a["expected"] != b["expected"]
        and all(abs(x - y) <= SAME_TOLERANCE for x, y in zip(a["f0"], b["f0"], strict=True))
    ]
    return {
        "words": len(present), "missing": len(rows) - len(present),
        "strict": strict, "loose": loose,
        "contrast": [sum(ok for _, ok in checks), len(checks)],
        "contrast_failed": [name for name, ok in checks if not ok],
        "same_reading_same_sound": same,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio-dir", type=Path, required=True)
    ap.add_argument("--tag", required=True, help="file name suffix, e.g. ios-kyoko")
    ap.add_argument("--words", type=Path, default=Path("words.tsv"))
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    rows = measure(args.audio_dir, args.tag, words.load_words(args.words))
    summary = summarize(rows)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"tag": args.tag, "summary": summary, "words": rows},
                                   ensure_ascii=False, indent=1))
    print(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
