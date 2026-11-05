#!/usr/bin/env python3
"""Orientation check without EXIF: every photo turned 0/90/180/270 degrees plus its raw (EXIF-ignored) pixels.

usage: python3 tools/orient_eval.py [--max-side 1600,1024]   -> <private>/textbook/scan/scores/orientation.md (+ .json)
Signal 1 (cheap, 0/90 only): median width/height of VNDetectTextRectanglesRequest boxes < 1.5 -> sideways.
Signal 2 (direction): reading-direction votes from VNRecognizeTextRequest quads (topLeft -> topRight).
"""
import argparse
import json
from pathlib import Path

from run_eval import PHOTOS, SCAN_BIN, WORK, load_pages, run

NORM = {0: 0, 90: 90, 180: 180, 270: -90, -90: -90, -180: 180, -270: 90}


def orient(photo: Path, rotate: int, max_side: str, no_exif: bool = False) -> dict:
    cmd = [SCAN_BIN, "orient", photo, "--rotate", rotate, "--max-side", max_side] + (["--no-exif"] if no_exif else [])
    return json.loads(run(cmd))


def main() -> None:
    ap = argparse.ArgumentParser(description="orientation check without EXIF")
    ap.add_argument("--max-side", default="1600,1024", help="comma-separated long sides to test")
    sides = ap.parse_args().max_side.split(",")
    rows, cases = [], []
    for side in sides:
        ok_dir = ok_aspect = n = 0
        times = []
        for page, (photo, upright_rot) in load_pages().items():
            tests = [(f"{k * 90}°", upright_rot + k * 90, NORM[(-k * 90) % 360], False) for k in range(4)]
            tests.append(("EXIF 무시", 0, -90, True))  # all five raw files need a clockwise quarter turn
            for label, rot, expected, raw in tests:
                r = orient(PHOTOS / photo, rot, side, no_exif=raw)
                sideways = expected in (90, -90)
                hit_dir = r["correction"] == expected
                hit_aspect = r["sideways_by_aspect"] == sideways
                ok_dir += hit_dir
                ok_aspect += hit_aspect
                n += 1
                times.append(r["ms"]["recognize"] + r["ms"]["text_rects"])
                cases.append({"max_side": side, "page": page, "case": label, "expected": expected, **r})
                rows.append(f"| {side} | {page} | {label} | {expected} | {r['correction']} {'✓' if hit_dir else '✗'} | "
                            f"{r['share']:.2f} | {r['votes_0_90_180_270']} | {r['text_rect_median_w_over_h']} "
                            f"{'✓' if hit_aspect else '✗'} | {r['ms']['text_rects']:.0f} + {r['ms']['recognize']:.0f} |")
        times.sort()
        rows.append(f"| **{side} 합계** | | | | **{ok_dir}/{n}** | | | **{ok_aspect}/{n}** | 중앙값 {times[len(times) // 2]:.0f} |")
    head = ("| 긴 변(px) | 쪽 | 입력 | 정답 보정(°) | 글 방향 투표 결과 | 득표율 | 글자 수 [0,90,180,270] | 상자 w/h 중앙값(옆으로 누움 판별) | ms(글상자+판독) |\n"
            "|---|---|---|---|---|---|---|---|---|")
    out = WORK / "scores"
    out.mkdir(exist_ok=True)
    (out / "orientation.md").write_text(head + "\n" + "\n".join(rows) + "\n")
    (out / "orientation.json").write_text(json.dumps(cases, ensure_ascii=False, indent=1))
    print(head)
    print("\n".join(rows))


if __name__ == "__main__":
    main()
