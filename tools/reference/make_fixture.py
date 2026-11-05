#!/usr/bin/env python3
"""Photo -> upright image -> two Apple Vision passes -> <out>/<name>.{ja,ko}.json

usage: python3 make_fixture.py <photo.jpg> <name> [--rotate DEG] [--out DIR]
  --rotate: extra counter-clockwise rotation after applying EXIF (e.g. -90 for a page shot sideways)
  --out:    default $SHIORI_PRIVATE_DIR/textbook/vocab_n5n3 (SHIORI_PRIVATE_DIR defaults to <repo>/.private).
            Textbook pages stay out of the repository.
Requires Pillow and the probe built at /tmp/vision_ocr (swiftc -O vision_ocr.swift -o /tmp/vision_ocr).
"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageOps

REPO = Path(__file__).resolve().parents[2]
PRIVATE = Path(os.environ.get("SHIORI_PRIVATE_DIR") or REPO / ".private")
FIXTURES = PRIVATE / "textbook" / "vocab_n5n3"
PROBE = "/tmp/vision_ocr"


def main():
    if len(sys.argv) < 3 or sys.argv[-1] in ("--rotate", "--out"):
        sys.exit(__doc__)
    photo, name = sys.argv[1], sys.argv[2]
    rotate = float(sys.argv[sys.argv.index("--rotate") + 1]) if "--rotate" in sys.argv else 0
    out_dir = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else FIXTURES
    out_dir.mkdir(parents=True, exist_ok=True)
    im = ImageOps.exif_transpose(Image.open(photo))
    if rotate:
        im = im.rotate(rotate, expand=True)
    with tempfile.NamedTemporaryFile(suffix=".jpg") as tmp:
        im.convert("RGB").save(tmp.name, quality=92)
        for tag, langs in (("ja", "ja-JP,ko-KR"), ("ko", "ko-KR,ja-JP")):
            raw = json.loads(subprocess.run([PROBE, tmp.name, langs], capture_output=True, check=True, text=True).stdout)
            lines = [{k: (round(o[k], 4) if isinstance(o[k], float) else o[k]) for k in ("t", "c", "x", "y", "w", "h")}
                     for o in raw["obs"]]
            out = {"engine": "apple-vision", "langs": raw["langs"], "ms": round(raw["ms"]), "lines": lines}
            (out_dir / f"{name}.{tag}.json").write_text(json.dumps(out, ensure_ascii=False, indent=0))
            print(f"{name}.{tag}.json  lines={len(lines)}  {out['ms']}ms")


if __name__ == "__main__":
    main()
