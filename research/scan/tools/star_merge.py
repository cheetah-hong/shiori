#!/usr/bin/env python3
"""Simulate an extra star-only OCR pass: keep the colour photo's two passes, add the star glyphs
found by a third pass on a cleaned-up copy (same frame, no warp), then score with parse_eval.

usage: python3 tools/star_merge.py <base_fixtures> <star_source_fixtures> <out_dir>
Only the star is taken from the source pass: every star glyph in a source line becomes a line "★" at the
glyph's estimated position (lines read like "★ かず"), so the base headword / reading / meaning lines stay
exactly as they were. ☆ counts as ★ (the book prints only ★; the OCR sometimes returns ☆).
"""
import argparse
import json
from pathlib import Path
from typing import List

from run_eval import WORK, fmt, score
from text_recall import STAR, is_star_line


def star_lines(source: List[dict]) -> List[dict]:
    out = []
    for l in source:
        if not is_star_line(l["t"]):
            continue
        char_w = l["w"] / max(len(l["t"]), 1)
        for m in STAR.finditer(l["t"]):
            out.append({"t": "★", "c": l["c"], "x": round(l["x"] + m.start() * char_w, 4), "y": l["y"],
                        "w": round(char_w, 4), "h": l["h"]})
    return out


def merge(base: Path, src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for f in sorted(base.glob("*.json")):
        data = json.loads(f.read_text())
        if f.name.endswith(".ja.json"):
            extra = star_lines(json.loads((src / f.name).read_text())["lines"])
            data = {**data, "lines": data["lines"] + extra}
        (out / f.name).write_text(json.dumps(data, ensure_ascii=False, indent=0))


def main() -> None:
    ap = argparse.ArgumentParser(description="add star glyphs from a third OCR pass and score")
    ap.add_argument("base", type=Path)
    ap.add_argument("source", type=Path)
    ap.add_argument("out", type=Path)
    args = ap.parse_args()
    merge(args.base, args.source, args.out)
    label = f"{args.base.name} + ★ from {args.source.parent.name}/{args.source.name}"
    print(fmt(label, score(args.out, args.out.name, WORK / "scores")))


if __name__ == "__main__":
    main()
