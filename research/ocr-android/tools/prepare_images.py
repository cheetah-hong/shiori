#!/usr/bin/env python3
"""Photos -> upright JPEGs for the ML Kit probe, made exactly like research/ocr/tools/make_fixture.py
(PIL exif_transpose, optional extra rotation, RGB, JPEG quality 92) so ML Kit sees the same pixels as Apple Vision.

usage: python3 prepare_images.py [--photos DIR]
  --photos: folder with the photos and pages.json ({"pages": {"p012": {"photo": ..., "rotate": -90}}});
            default $SHIORI_PRIVATE_DIR/textbook/photos (SHIORI_PRIVATE_DIR defaults to <repo>/.private)
  writes <data>/work/images/upright/<page>.jpg  (made upright, no EXIF)
         <data>/work/images/orig/<page>.jpg     (byte copy of the original photo, EXIF kept; for the fromFilePath test)
  <data> = $SHIORI_PRIVATE_DIR/textbook/ocr-android. Photos are textbook pages: they never enter the repository.
"""
import json
import os
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageOps

HERE = Path(__file__).resolve().parents[1]
PRIVATE = Path(os.environ.get("SHIORI_PRIVATE_DIR") or HERE.parents[1] / ".private")
WORK = PRIVATE / "textbook" / "ocr-android" / "work" / "images"


def load_pages(photos):
    """[(page fixture name, photo file, extra rotation after EXIF in PIL degrees, counter-clockwise)]"""
    table = photos / "pages.json"
    if not table.is_file():
        sys.exit(f"{table} not found: the textbook photos are local only (pass --photos or set SHIORI_PRIVATE_DIR)")
    try:
        pages = json.loads(table.read_text(encoding="utf-8"))["pages"]
        return [(page, p["photo"], int(p["rotate"])) for page, p in pages.items()]
    except (ValueError, KeyError, TypeError) as e:
        sys.exit(f"{table}: expected {{\"pages\": {{page: {{\"photo\": ..., \"rotate\": deg}}}}}} ({e})")


def main():
    photos = Path(sys.argv[sys.argv.index("--photos") + 1]) if "--photos" in sys.argv[:-1] else PRIVATE / "textbook" / "photos"
    pages = load_pages(photos)
    (WORK / "upright").mkdir(parents=True, exist_ok=True)
    (WORK / "orig").mkdir(parents=True, exist_ok=True)
    for page, name, rotate in pages:
        src = photos / name
        im = ImageOps.exif_transpose(Image.open(src))
        if rotate:
            im = im.rotate(rotate, expand=True)
        out = WORK / "upright" / f"{page}.jpg"
        im.convert("RGB").save(out, quality=92)
        shutil.copyfile(src, WORK / "orig" / f"{page}.jpg")
        print(f"{page}  {name}  rotate={rotate:>4}  upright={im.size[0]}x{im.size[1]}")


if __name__ == "__main__":
    main()
