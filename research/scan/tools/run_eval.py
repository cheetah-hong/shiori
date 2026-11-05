#!/usr/bin/env python3
"""Scan variants -> OCR fixtures -> parse_eval scores, side by side with the current method.

usage: python3 tools/run_eval.py [--process] [--variants a-persp,b-gray,...] [--tag SUFFIX] [-- extra scan args]
  --process   (re)run the Swift tool first (writes out/<variant>/<page>.* and out/meta/<page>.json)
  --tag       suffix for out/fixtures/scores folders, e.g. "-1600" together with `-- --max-side 1600`

Photos and every output (processed images, OCR fixtures, scores) are textbook content and stay out of the
repository, under $SHIORI_PRIVATE_DIR (default <repo>/.private):
  textbook/photos/            the photos and pages.json ({"pages": {"p012": {"photo": ..., "rotate": -90}}})
  textbook/scan/              out*/, fixtures*/, scores*/ written here
  textbook/vocab_n5n3/      ground_truth.json read by the reference parser
  env PHOTOS overrides the photo folder.

For every variant two fixture sets are scored with the unchanged reference parser (research/ocr/prototype):
  <variant>-page : OCR boxes in the rectified page's own coordinates (what the app gets if it OCRs the scan)
  <variant>-photo: the same boxes mapped back through the page quad into the upright photo's coordinates.
                   parse_eval's column offsets were tuned in photo coordinates, so this isolates OCR quality.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Callable, Dict, List, Tuple

HERE = Path(__file__).resolve().parent
SCAN = HERE.parent
REPO = SCAN.parents[1]
OCR = REPO / "research" / "ocr"
MAKE_FIXTURE = OCR / "tools" / "make_fixture.py"
PARSE_EVAL = OCR / "prototype" / "parse_eval.py"
SCAN_BIN = SCAN / ".build" / "scan"
PRIVATE = Path(os.environ.get("SHIORI_PRIVATE_DIR") or REPO / ".private")
PHOTOS = Path(os.environ.get("PHOTOS") or PRIVATE / "textbook" / "photos")
WORK = PRIVATE / "textbook" / "scan"
GT = PRIVATE / "textbook" / "vocab_n5n3" / "ground_truth.json"

ALL_VARIANTS = ["a-persp", "b-gray", "c-flat", "c-flatcolor", "d-binary"]

Point = Tuple[float, float]


def load_pages(photos: Path = PHOTOS) -> Dict[str, Tuple[str, int]]:
    """page -> (photo file, extra CCW rotation after EXIF), from <photos>/pages.json (local only)."""
    table = photos / "pages.json"
    if not table.is_file():
        raise SystemExit(f"{table} not found: the textbook photos are local only (set SHIORI_PRIVATE_DIR or PHOTOS)")
    try:
        pages = json.loads(table.read_text(encoding="utf-8"))["pages"]
        return {page: (p["photo"], int(p["rotate"])) for page, p in pages.items()}
    except (ValueError, KeyError, TypeError) as e:
        raise SystemExit(f"{table}: expected {{\"pages\": {{page: {{\"photo\": ..., \"rotate\": deg}}}}}} ({e})")


def run(cmd: List[object]) -> str:
    """Run a command and return stdout; on failure show the child's stderr before raising."""
    try:
        return subprocess.run([str(c) for c in cmd], check=True, capture_output=True, text=True).stdout
    except subprocess.CalledProcessError as e:
        print(f"command failed ({e.returncode}): {' '.join(str(c) for c in cmd)}\n{e.stderr}", file=sys.stderr)
        raise


# ---------------------------------------------------------------- page quad -> photo coordinates

def square_to_quad(q: Dict[str, List[float]]) -> Callable[[float, float], Point]:
    """Projective map from the unit square (page, top-left origin) to the quad (photo, top-left origin)."""
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = q["tl"], q["tr"], q["br"], q["bl"]
    dx1, dx2, dx3 = x1 - x2, x3 - x2, x0 - x1 + x2 - x3
    dy1, dy2, dy3 = y1 - y2, y3 - y2, y0 - y1 + y2 - y3
    den = dx1 * dy2 - dx2 * dy1
    if abs(den) < 1e-12:
        raise ValueError(f"degenerate page quad: {q}")
    g = (dx3 * dy2 - dx2 * dy3) / den
    h = (dx1 * dy3 - dx3 * dy1) / den
    a, b, c = x1 - x0 + g * x1, x3 - x0 + h * x3, x0
    d, e, f = y1 - y0 + g * y1, y3 - y0 + h * y3, y0

    def apply(u: float, v: float) -> Point:
        k = g * u + h * v + 1
        return (a * u + b * v + c) / k, (d * u + e * v + f) / k
    return apply


def remap_line(line: dict, m: Callable[[float, float], Point]) -> dict:
    x, y, w, h = line["x"], line["y"], line["w"], line["h"]
    pts = [m(u, v) for u, v in ((x, y), (x + w, y), (x + w, y + h), (x, y + h))]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return {**line, "x": round(min(xs), 4), "y": round(min(ys), 4),
            "w": round(max(xs) - min(xs), 4), "h": round(max(ys) - min(ys), 4)}


def remap_fixture(src: Path, dst: Path, quad: Dict[str, List[float]]) -> None:
    m = square_to_quad(quad)
    data = json.loads(src.read_text())
    out = {**data, "lines": [remap_line(l, m) for l in data["lines"]], "remapped_from": "page quad -> upright photo"}
    dst.write_text(json.dumps(out, ensure_ascii=False, indent=0))


# ---------------------------------------------------------------- scoring

TOTAL_RE = re.compile(r"(\w+)=(\d+)/(\d+)")
# parse_eval prints f"{page:>4} {tpl:<5}{n:>2} ..." so "entry" and a two-digit n can touch ("entry12")
PAGE_ROW_RE = re.compile(r"^\s*(\d+)\s+(list|entry)\s*(\d+)\s+(.*)$")


def parse_scores(out: str) -> dict:
    total = next((l for l in out.splitlines() if l.startswith("TOTAL")), None)
    silent = re.search(r"silent errors\): (\d+)", out)
    flagged = re.search(r"flagged for review: (\d+);\s+flagged but actually correct: (\d+)", out)
    if total is None or silent is None or flagged is None:
        raise ValueError("parse_eval output not understood:\n" + out[-800:])
    res = {k: (int(a), int(b)) for k, a, b in TOTAL_RE.findall(total)}
    res["silent"] = int(silent.group(1))
    res["flagged_wrong"], res["flagged_ok"] = int(flagged.group(1)), int(flagged.group(2))
    res["per_page_rows"] = {}
    for l in out.splitlines():
        m = PAGE_ROW_RE.match(l)
        if m:  # remaining columns: found head read pos mean star row ...
            res["per_page_rows"][f"p{int(m.group(1)):03d}"] = int(m.group(4).split()[6])
    return res


def score(fixtures: Path, label: str, scores_dir: Path) -> dict:
    out = run(["python3", PARSE_EVAL, "--fixtures", fixtures, "--verbose"])
    scores_dir.mkdir(parents=True, exist_ok=True)
    (scores_dir / f"{label}.txt").write_text(out)
    return parse_scores(out)


def fmt(label: str, r: dict) -> str:
    g = lambda k: f"{r[k][0]}/{r[k][1]}"
    pp = " ".join(f"{p[1:]}:{n}" for p, n in sorted(r["per_page_rows"].items()))
    return (f"| {label} | **{g('row')}** | {g('headword')} | {g('readings')} | {g('pos')} | {g('meaning')} | "
            f"{g('important')} | {g('ex_ja')} | {g('ex_ko')} | {r['silent']} | {r['flagged_wrong']} | {pp} |")


def fixtures_complete(d: Path, pages: Dict[str, Tuple[str, int]]) -> bool:
    return all((d / f"{page}.{lang}.json").exists() for page in pages for lang in ("ja", "ko"))


def parse_args(argv: List[str]) -> Tuple[argparse.Namespace, List[str]]:
    """Own options before "--", scan.swift options after it. Tags start with "-" ("-nowarp"), which argparse
    would read as an option, so "--tag X" is passed on as "--tag=X"."""
    own, extra = (argv[:argv.index("--")], argv[argv.index("--") + 1:]) if "--" in argv else (argv, [])
    joined, it = [], iter(own)
    for a in it:
        joined.append(f"--tag={next(it, '')}" if a == "--tag" else a)
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--process", action="store_true")
    ap.add_argument("--variants", default=",".join(ALL_VARIANTS))
    ap.add_argument("--tag", default="")
    return ap.parse_args(joined), extra


def main() -> None:
    args, extra = parse_args(sys.argv[1:])
    variants = args.variants.split(",")
    pages = load_pages()
    out_dir, fx_root, scores_dir = WORK / f"out{args.tag}", WORK / f"fixtures{args.tag}", WORK / f"scores{args.tag}"

    if args.process:
        for page, (photo, rot) in pages.items():
            print(run([SCAN_BIN, "process", PHOTOS / photo, "--name", page, "--out", out_dir, "--rotate", rot, *extra]).strip())

    rows = []
    base_fx = fx_root / "orig"
    if not fixtures_complete(base_fx, pages):  # current method, regenerated to confirm the baseline is reproducible
        for page, (photo, rot) in pages.items():
            run(["python3", MAKE_FIXTURE, PHOTOS / photo, page, "--out", base_fx, *(["--rotate", rot] if rot else [])])
    rows.append(fmt("원본 (지금 방식, 재생성)", score(base_fx, "orig", scores_dir)))

    for v in variants:
        page_fx, photo_fx = fx_root / f"{v}-page", fx_root / f"{v}-photo"
        photo_fx.mkdir(parents=True, exist_ok=True)
        for page in pages:
            meta = json.loads((out_dir / "meta" / f"{page}.json").read_text())
            img = next(Path(o["file"]) for o in meta["outputs"] if o["variant"] == v)
            run(["python3", MAKE_FIXTURE, img, page, "--out", page_fx])
            for lang in ("ja", "ko"):
                remap_fixture(page_fx / f"{page}.{lang}.json", photo_fx / f"{page}.{lang}.json", meta["page"])
        rows.append(fmt(f"{v} · 사진 좌표", score(photo_fx, f"{v}-photo", scores_dir)))
        rows.append(fmt(f"{v} · 페이지 좌표", score(page_fx, f"{v}-page", scores_dir)))
        print(rows[-2])
        print(rows[-1])

    header = ("| 변형 | 줄 전체 | 표제어 | 읽기 | 품사 | 뜻 | ★ | 예문(일) | 예문(한) | 조용한 오류 | 표시된 오류 | 쪽별 줄 전체 |\n"
              "|---|---|---|---|---|---|---|---|---|---|---|---|")
    table = header + "\n" + "\n".join(rows)
    (scores_dir / "summary.md").write_text(table + "\n")
    print(table)


if __name__ == "__main__":
    main()
