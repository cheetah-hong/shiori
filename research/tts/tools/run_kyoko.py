#!/usr/bin/env python3
"""Baseline: macOS `say` with a Japanese system voice (default accent only).

`say` gives no mora timing, so the voiced stretch of the F0 track (first to last
voiced frame) is cut into N equal parts, N = morae of word + が, and each part's
median log-F0 goes through the same pitch rule as VOICEVOX. This is ROUGH:
morae differ in length and devoiced morae shift the cut points.

usage (from research/tts):
  .cache/venv/bin/python tools/run_kyoko.py --audio-dir ../../.private/tts/wav \
      --out .cache/results/kyoko.json
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

import pitch
import words

PARTICLE = "が"


def say_to_wav(voice: str, text: str, wav: Path) -> float:
    aiff = wav.with_suffix(".aiff")
    t0 = time.perf_counter()
    subprocess.run(["say", "-v", voice, "-o", str(aiff), "--", text], check=True)
    elapsed = time.perf_counter() - t0
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", str(aiff), str(wav)], check=True)
    aiff.unlink()
    return elapsed


def equal_split_f0(wav: Path, parts: int) -> list[float]:
    import numpy as np
    import parselmouth

    track = parselmouth.Sound(str(wav)).to_pitch(time_step=0.005, pitch_floor=75,
                                                 pitch_ceiling=600)
    times = track.xs()
    f0 = track.selected_array["frequency"]
    voiced = np.nonzero(f0 > 0)[0]
    if len(voiced) == 0:
        return [0.0] * parts
    start, end = times[voiced[0]], times[voiced[-1]]
    edges = np.linspace(start, end, parts + 1)
    out = []
    for a, b in zip(edges[:-1], edges[1:], strict=True):
        sel = f0[(times >= a) & (times <= b) & (f0 > 0)]
        out.append(round(float(np.log(np.median(sel))), 3) if len(sel) else 0.0)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--voice", default="Kyoko")
    ap.add_argument("--words", type=Path, default=Path("words.tsv"))
    ap.add_argument("--audio-dir", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    voices = subprocess.run(["say", "-v", "?"], capture_output=True, text=True, check=True).stdout
    if not any(line.split()[0] == args.voice for line in voices.splitlines() if line.strip()):
        print(f"voice {args.voice} is not installed", file=sys.stderr)
        return 1
    args.audio_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for w in words.load_words(args.words):
        wav = args.audio_dir / f"{w.surface}_{w.reading}_{args.voice.lower()}.wav"
        sec = say_to_wav(args.voice, w.surface + PARTICLE, wav)
        f0 = equal_split_f0(wav, w.morae + 1)
        patt = pitch.pitch_pattern(f0) if any(x > 0 for x in f0) else "?" * len(f0)
        rows.append({"surface": w.surface, "reading": w.reading, "expected": list(w.expected),
                     "f0": f0, "pattern": patt, "say_sec": round(sec, 3), "wav": wav.name})
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"voice": args.voice, "words": rows},
                                   ensure_ascii=False, indent=1))
    print(f"wrote {args.out} ({len(rows)} words)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
