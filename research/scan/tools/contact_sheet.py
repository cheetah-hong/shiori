#!/usr/bin/env python3
"""Draw detected page quads on the upright photo and put the processed variants next to it.

usage: python3 contact_sheet.py <out_dir> <name> [<name> ...]
  reads <out_dir>/meta/<name>.json, writes <out_dir>/sheets/<name>.jpg
  red = VNDetectDocumentSegmentationRequest, blue = VNDetectRectanglesRequest, thick = the quad used
Upright photo = EXIF + the extra rotation scan.swift recorded in the meta ("rotate"; older metas fall back
to the local-only photo table, run_eval.load_pages()).
"""
import argparse
import json
from pathlib import Path
from typing import Dict, Optional, Tuple

from PIL import Image, ImageDraw, ImageOps

from run_eval import load_pages

THUMB_H = 900
GAP = 12
COLOURS = {"segmentation": (230, 40, 40), "rectangles": (40, 90, 230)}


def upright(meta: dict, pages: Optional[Dict[str, Tuple[str, int]]] = None) -> Image.Image:
    rot = meta.get("rotate")
    if rot is None:
        rot = (load_pages() if pages is None else pages).get(meta["name"], ("", 0))[1]
    with Image.open(meta["photo"]) as src:
        im = ImageOps.exif_transpose(src) if meta.get("exif", True) else src.copy()
    return im.rotate(rot, expand=True) if rot else im


def same_quad(a: dict, b: dict) -> bool:
    return a["source"] == b["source"] and all(a[k] == b[k] for k in ("tl", "tr", "br", "bl"))


def draw_quads(im: Image.Image, meta: dict) -> Image.Image:
    im = im.convert("RGB")
    im.thumbnail((THUMB_H * 2, THUMB_H))
    d = ImageDraw.Draw(im)
    w, h = im.size
    for src, colour in COLOURS.items():
        for q in meta["candidates"][src]:
            pts = [(q[k][0] * w, q[k][1] * h) for k in ("tl", "tr", "br", "bl")]
            d.line(pts + [pts[0]], fill=colour, width=8 if same_quad(q, meta["page"]) else 3)
    return im


def thumb(path: str) -> Image.Image:
    with Image.open(path) as src:
        t = src.convert("RGB")
    t.thumbnail((THUMB_H * 2, THUMB_H))
    return t


def main() -> None:
    ap = argparse.ArgumentParser(description="quad overlay + variant contact sheet")
    ap.add_argument("out_dir", type=Path)
    ap.add_argument("names", nargs="+")
    args = ap.parse_args()
    (args.out_dir / "sheets").mkdir(parents=True, exist_ok=True)
    pages = None  # the photo table, read once and only for metas without "rotate"
    for name in args.names:
        meta = json.loads((args.out_dir / "meta" / f"{name}.json").read_text())
        if "rotate" not in meta and pages is None:
            pages = load_pages()
        tiles = [draw_quads(upright(meta, pages), meta)] + [thumb(o["file"]) for o in meta["outputs"]]
        sheet = Image.new("RGB", (sum(t.width for t in tiles) + GAP * (len(tiles) - 1), THUMB_H), "white")
        x = 0
        for t in tiles:
            sheet.paste(t, (x, (THUMB_H - t.height) // 2))
            x += t.width + GAP
        dest = args.out_dir / "sheets" / f"{name}.jpg"
        sheet.save(dest, quality=80)
        print(dest)


if __name__ == "__main__":
    main()
