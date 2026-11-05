#!/usr/bin/env python3
"""ML Kit raw dumps (<data>/raw/<run>/<page>.<lang>.raw.json) -> fixtures in the Apple Vision format read by parse_eval.py.

<data> = $SHIORI_PRIVATE_DIR/textbook/ocr-android (SHIORI_PRIVATE_DIR defaults to <repo>/.private): the dumps are
OCR of textbook pages and stay out of the repository.

  {"engine": "mlkit", "langs": ["ja"], "ms": N, "lines": [{"t", "c", "x", "y", "w", "h"}]}
  boxes = axis-aligned ML Kit boundingBox / input size, top-left origin, 4 decimals (same as make_fixture.py)

usage: python3 raw_to_fixture.py <run> <unit> <out_dir> [--auto-rotate]
  run:  folder under raw/ (e.g. upright-bitmap)
  unit: line | element | segment
        line     Text.Line as one fixture line
        element  Text.Element as one fixture line
        segment  Text.Line cut where ML Kit glued two table columns together: at an element gap wider than
                 SEG_GAP x line height, and around a star symbol (★ * ☆ ＊). Cut pieces get exact symbol boxes.
                 A line that needs no cut is written exactly as the line unit writes it.
                 Pieces keep the line's top/bottom (the parser's height thresholds were tuned on line boxes).
  --auto-rotate: if the median line angle says the text is not upright (a sideways photo without EXIF),
                 turn every box by quarter turns before writing. ML Kit reports Line.angle in the input bitmap's
                 frame, so the rotation passed with the image is added back first.
"""
import copy
import os
import statistics
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
PRIVATE = Path(os.environ.get("SHIORI_PRIVATE_DIR") or HERE.parents[1] / ".private")
DATA = PRIVATE / "textbook" / "ocr-android"
LANG_TAG = {"ja": "ja", "ko": "ko"}
STARS = set("★*☆＊")
# Element gaps on the 5 pages: words inside a footer or a meaning <= 0.98 line heights, table columns >= 1.22
SEG_GAP = 1.1


def union(boxes):
    return [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]


def runs(element):
    """An element as runs of symbols; a star symbol is a run of its own. Pieces without any box are dropped."""
    syms = [s for s in element["symbols"] if s["box"] is not None]
    if not syms:
        if element["box"] is None:
            return []
        return [{"t": element["t"], "box": element["box"], "star": False, "cs": [element["c"]]}]
    out = []
    for s in syms:
        star = s["t"] in STARS
        if out and not star and not out[-1]["star"]:
            out[-1]["t"] += s["t"]; out[-1]["boxes"].append(s["box"]); out[-1]["cs"].append(s["c"])
        else:
            out.append({"t": s["t"], "boxes": [s["box"]], "star": star, "cs": [s["c"]]})
    return [{"t": r["t"], "box": union(r["boxes"]), "star": r["star"], "cs": r["cs"]} for r in out]


def segments(line):
    if line["box"] is None:
        return []
    lh = line["box"][3] - line["box"][1]
    segs, prev_right = [], None
    for e in line["elements"]:
        for k, r in enumerate(runs(e)):
            wide_gap = k == 0 and prev_right is not None and r["box"][0] - prev_right > SEG_GAP * lh
            if not segs or r["star"] or segs[-1]["star"] or wide_gap:
                segs.append({"t": r["t"], "boxes": [r["box"]], "cs": list(r["cs"]), "star": r["star"]})
            else:
                seg = segs[-1]
                seg["t"] += (" " if k == 0 else "") + r["t"]
                seg["boxes"].append(r["box"]); seg["cs"] += r["cs"]
            prev_right = r["box"][2]
    if len(segs) <= 1:
        return [line]
    # x from the symbols, y from the line box: the parser's height thresholds were set on line boxes;
    # confidence = mean symbol confidence (one bad glyph like a "|" must not sink the whole piece)
    top, bottom = line["box"][1], line["box"][3]
    out = []
    for seg in segs:
        cs = [c for c in seg["cs"] if c is not None]
        left, _, right, _ = union(seg["boxes"])
        out.append({"t": seg["t"], "c": sum(cs) / len(cs) if cs else line["c"], "box": [left, top, right, bottom]})
    return out


def items(raw, unit):
    for block in raw["blocks"]:
        for line in block["lines"]:
            if unit == "line":
                yield line
            elif unit == "element":
                yield from line["elements"]
            else:
                yield from segments(line)


def frame(raw):
    """Width/height of the frame the boxes live in: ML Kit boxes are in the rotation-applied frame."""
    if "frame" in raw:
        return raw["frame"]
    rot = raw["input_rotation"]
    return (raw["input_h"], raw["input_w"]) if rot in (90, 270) else (raw["input_w"], raw["input_h"])


def text_turns(raw):
    """Clockwise quarter turns that make the text upright (0 when it already is or the angle is unclear)."""
    angles = [l["angle"] for b in raw["blocks"] for l in b["lines"] if l["angle"] is not None and len(l["t"].strip()) >= 3]
    if not angles:
        return 0
    a = (statistics.median(angles) + raw["input_rotation"] + 180) % 360 - 180
    snapped = min((0, 90, -90, 180, -180), key=lambda t: abs(a - t))
    if abs(a - snapped) > 20:
        return 0
    return {0: 0, -90: 1, 180: 2, -180: 2, 90: 3}[snapped]


def turned(raw, turns):
    """Copy of raw with every box turned clockwise `turns` quarter turns."""
    raw = copy.deepcopy(raw)
    w, h = frame(raw)
    nodes = [n for b in raw["blocks"] for n in [b, *b["lines"]]]
    nodes += [n for b in raw["blocks"] for l in b["lines"] for e in l["elements"] for n in [e, *e["symbols"]]]
    for _ in range(turns):
        for n in nodes:
            if n.get("box"):
                l, t, r, bt = n["box"]
                n["box"] = [h - bt, l, h - t, r]
        w, h = h, w
    raw["frame"] = (w, h)
    return raw


def to_fixture(raw, unit):
    w, h = frame(raw)
    lines, no_conf = [], 0
    for it in items(raw, unit):
        if it["box"] is None:
            continue
        l, t, r, b = it["box"]
        c = it["c"]
        if c is None:
            c, no_conf = 1.0, no_conf + 1  # confidence not provided: 1.0 by convention
        lines.append({"t": it["t"], "c": round(c, 4), "x": round(l / w, 4), "y": round(t / h, 4),
                      "w": round((r - l) / w, 4), "h": round((b - t) / h, 4)})
    out = {"engine": "mlkit", "langs": [LANG_TAG[raw["lang"]]], "ms": raw["ms"], "lines": lines}
    return out, no_conf


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 3 or args[1] not in ("line", "element", "segment"):
        sys.exit(__doc__)
    run, unit, out_dir = args[0], args[1], Path(args[2])
    auto_rotate = "--auto-rotate" in sys.argv
    paths = sorted((DATA / "raw" / run).glob("*.raw.json"))
    if not paths:
        sys.exit(f"no *.raw.json under {DATA / 'raw' / run}")
    out_dir.mkdir(parents=True, exist_ok=True)
    for path in paths:
        raw = json.loads(path.read_text(encoding="utf-8"))
        turns = text_turns(raw) if auto_rotate else 0
        fx, no_conf = to_fixture(turned(raw, turns) if turns else raw, unit)
        name = path.name.replace(".raw.json", ".json")
        (out_dir / name).write_text(json.dumps(fx, ensure_ascii=False, indent=0), encoding="utf-8")
        note = f"  (no confidence on {no_conf}, wrote c=1.0)" if no_conf else ""
        note += f"  turned {turns * 90} deg clockwise" if turns else ""
        print(f"{name:<14} {unit:<7} lines={len(fx['lines']):>3}  {fx['ms']}ms{note}")


if __name__ == "__main__":
    main()
