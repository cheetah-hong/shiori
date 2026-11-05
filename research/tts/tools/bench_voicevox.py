#!/usr/bin/env python3
"""Synthesis speed of VOICEVOX core: median of repeated runs per text.

usage (from research/tts):
  .cache/venv/bin/python tools/bench_voicevox.py --core .cache/voicevox_core --threads 0
  .cache/venv/bin/python tools/bench_voicevox.py --core .cache/voicevox_core --threads 1
"""
from __future__ import annotations

import argparse
import os
import statistics
import sys
import time
from pathlib import Path

REPEAT = 5
SAMPLE_RATE = 24000


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--core", type=Path, required=True)
    ap.add_argument("--threads", type=int, default=0, help="0 = engine default")
    ap.add_argument("--words", type=Path, default=Path("words.tsv"))
    ap.add_argument("--sentences", type=Path, default=Path("sentences.tsv"))
    args = ap.parse_args()
    os.environ["VV_THREADS"] = str(args.threads)

    import engine_vv
    import words
    from run_voicevox import MAIN_STYLE, PARTICLE, load_sentences

    t0 = time.perf_counter()
    engine = engine_vv.load_engine(args.core)
    load_sec = time.perf_counter() - t0
    texts = {
        "단어+が": [w.surface + PARTICLE for w in words.load_words(args.words)],
        "예문": [s.text for s in load_sentences(args.sentences)],
    }
    engine.synth.synthesis(engine.synth.create_audio_query("準備", MAIN_STYLE), MAIN_STYLE)
    print(f"threads={args.threads} load={load_sec:.2f}s")
    for label, items in texts.items():
        q_times, s_times, rtfs = [], [], []
        for text in items:
            q_runs, s_runs = [], []
            for _ in range(REPEAT):
                t = time.perf_counter()
                q = engine.synth.create_audio_query(text, MAIN_STYLE)
                q_runs.append(time.perf_counter() - t)
                t = time.perf_counter()
                wav = engine.synth.synthesis(q, MAIN_STYLE)
                s_runs.append(time.perf_counter() - t)
            audio_sec = (len(wav) - 44) / 2 / SAMPLE_RATE
            q_times.append(statistics.median(q_runs))
            s_times.append(statistics.median(s_runs))
            rtfs.append(statistics.median(s_runs) / audio_sec)
        print(f"{label}: n={len(items)} query={1000 * statistics.median(q_times):.1f}ms "
              f"synth={1000 * statistics.median(s_times):.0f}ms "
              f"(max {1000 * max(s_times):.0f}ms) RTF={statistics.median(rtfs):.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
