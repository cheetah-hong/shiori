#!/usr/bin/env python3
"""Can the photo-tuned parser read a scanner-cropped page if its coordinates are shrunk by one constant?

usage: python3 tools/page_units.py <page_fixtures_dir> K [K ...]
  writes <dir>-K<k>/ with every box mapped to 0.5 + K * (v - 0.5) (both axes) and scores it with parse_eval.
A page that fills the frame (scanner output) then looks like a page that fills K of the photo, which is
what the column offsets in parse_eval were tuned on (p013/p185: the page covers ~0.70-0.76 of the photo width).
"""
import argparse
import json
from pathlib import Path

from run_eval import PARSE_EVAL, WORK, fmt, score


def shrink_line(line: dict, k: float) -> dict:
    return {**line, "x": round(0.5 + k * (line["x"] - 0.5), 4), "y": round(0.5 + k * (line["y"] - 0.5), 4),
            "w": round(k * line["w"], 4), "h": round(k * line["h"], 4)}


def shrink(src_dir: Path, k: float) -> Path:
    dst = src_dir.parent / f"{src_dir.name}-K{round(k * 100)}"
    dst.mkdir(exist_ok=True)
    for f in sorted(src_dir.glob("*.json")):
        data = json.loads(f.read_text())
        out = {**data, "lines": [shrink_line(l, k) for l in data["lines"]]}
        (dst / f.name).write_text(json.dumps(out, ensure_ascii=False, indent=0))
    return dst


def main() -> None:
    ap = argparse.ArgumentParser(description="score page-frame fixtures shrunk by constant factors")
    ap.add_argument("fixtures", type=Path)
    ap.add_argument("k", type=float, nargs="+")
    args = ap.parse_args()
    if not PARSE_EVAL.exists():
        raise SystemExit(f"parse_eval.py not found at {PARSE_EVAL}")
    for k in args.k:
        dst = shrink(args.fixtures, k)
        print(fmt(f"{args.fixtures.name} · 페이지 좌표 × {k}", score(dst, dst.name, WORK / "scores")))


if __name__ == "__main__":
    main()
