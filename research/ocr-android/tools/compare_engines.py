#!/usr/bin/env python3
"""Apple Vision vs ML Kit fixtures: line counts, confidence values, box geometry, ★ and POS badge reading.

usage: python3 compare_engines.py --vision DIR --mlkit DIR --gt ground_truth.json [--raw DIR]
  --raw: raw/ folder of the probe; adds the crop test (headword/star columns read again from a crop)
Prints plain-text tables (the README summarises them). Matching is by text, so it needs no parser;
the badge and star counts are approximate.
"""
import json
import re
import statistics
import sys
import unicodedata
from collections import Counter
from pathlib import Path


def arg(name, required=True):
    if name not in sys.argv or sys.argv.index(name) + 1 >= len(sys.argv):
        if required:
            sys.exit(__doc__)
        return None
    return Path(sys.argv[sys.argv.index(name) + 1])


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


VISION, MLKIT, GT, RAW = arg("--vision"), arg("--mlkit"), arg("--gt"), arg("--raw", required=False)
PAGES = [p["fixture"] for p in read_json(GT)["pages"]]
STARS = "★*☆＊"
POS = "명몀동통형부접감연조"


def lines(d, page, lang):
    return read_json(d / f"{page}.{lang}.json")["lines"]


def med(xs, fmt="{:.4f}"):
    return fmt.format(statistics.median(xs)) if xs else "n/a"


def norm(s):
    return re.sub(r"\s+", "", unicodedata.normalize("NFKC", s)).replace("，", ",")


def section(title):
    print(f"\n## {title}")


def counts():
    section("line counts per pass (Vision / ML Kit)")
    for page in PAGES:
        row = [f"{len(lines(VISION, page, l))}/{len(lines(MLKIT, page, l))}" for l in ("ja", "ko")]
        print(f"{page}  ja {row[0]:>7}   ko {row[1]:>7}")


def confidence():
    section("confidence values")
    for name, d in (("vision", VISION), ("mlkit", MLKIT)):
        cs = [l["c"] for p in PAGES for lang in ("ja", "ko") for l in lines(d, p, lang)]
        distinct = sorted(Counter(round(c, 2) for c in cs).items(), key=lambda kv: -kv[1])
        q = statistics.quantiles(cs, n=10) if len(cs) >= 2 else [float("nan")]
        print(f"{name:<7} n={len(cs)} distinct={len(distinct)} top={distinct[:4]} "
              f"p10={q[0]:.2f} median={med(cs, '{:.2f}')} p90={q[-1]:.2f}")
    # ML Kit garbage: a pass reading the other script
    garbage = [l for p in PAGES for l in lines(MLKIT, p, "ko") if sum("가" <= c <= "힣" for c in l["t"]) / max(1, len(l["t"].replace(" ", ""))) < 0.5
               and re.search(r"[A-Za-z]", l["t"]) and len(l["t"]) > 6]
    print(f"mlkit ko lines that look like garbage (<50% Hangul, Latin mixed, >6 chars): {len(garbage)}, "
          f"median c={med([l['c'] for l in garbage], '{:.2f}')}")


def geometry():
    section("same text in both engines: box differences (page fraction)")
    for lang in ("ja", "ko"):
        dx, dy, hr, wr = [], [], [], []
        for page in PAGES:
            vis = {}
            for l in lines(VISION, page, lang):
                vis.setdefault(norm(l["t"]), []).append(l)
            for m in lines(MLKIT, page, lang):
                cand = vis.get(norm(m["t"]))
                if not cand or len(norm(m["t"])) < 2:
                    continue
                v = min(cand, key=lambda v: abs(v["y"] - m["y"]) + abs(v["x"] - m["x"]))
                if abs(v["y"] - m["y"]) > 0.02 or abs(v["x"] - m["x"]) > 0.03 or not v["h"] or not v["w"]:
                    continue
                dx.append(m["x"] - v["x"]); dy.append((m["y"] + m["h"] / 2) - (v["y"] + v["h"] / 2))
                hr.append(m["h"] / v["h"]); wr.append(m["w"] / v["w"])
        print(f"{lang}: matched={len(dx)}  x shift median={med(dx, '{:+.4f}')}  "
              f"center-y shift median={med(dy, '{:+.4f}')}  height ratio median={med(hr, '{:.2f}')}  "
              f"width ratio median={med(wr, '{:.2f}')}")
    for name, d in (("vision", VISION), ("mlkit", MLKIT)):
        ids = [l["h"] for p in PAGES for l in lines(d, p, "ja") if re.match(r"^[0-9OoD]{4}$", l["t"].strip())]
        print(f"{name:<7} id-only lines: n={len(ids)} median height={med(ids)}")


def stars():
    section("★ on starred entries (ground truth important=True), Japanese pass")
    gt = read_json(GT)
    starred = sum(e["important"] for p in gt["pages"] for e in p["entries"])
    for name, d in (("vision", VISION), ("mlkit", MLKIT)):
        alone = glued = 0
        for page in PAGES:
            for l in lines(d, page, "ja"):
                t = l["t"].strip()
                if "=" in t or "2010" in t:
                    continue  # legend line at the top
                n = sum(t.count(s) for s in STARS)
                if n and len(t) == 1: alone += 1
                elif n: glued += 1
        print(f"{name:<7} starred entries={starred}  star as its own line={alone}  star glued into another line={glued}  "
              f"not output at all≈{starred - alone - glued}")


def badges():
    section("POS badge in the Korean pass, per ground-truth entry")
    gt = read_json(GT)
    for name, d in (("vision", VISION), ("mlkit", MLKIT)):
        kinds = Counter()
        for p in gt["pages"]:
            ko = lines(d, p["fixture"], "ko")
            for e in p["entries"]:
                m = norm(e["meaning"])
                head = m[:3] if len(m) >= 3 else m
                hit = next((l for l in ko if head and head in norm(l["t"])), None)
                if not hit:
                    kinds["meaning line not found"] += 1; continue
                t = unicodedata.normalize("NFKC", hit["t"]).strip()
                pre = t[:t.rfind(e["meaning"][:2])] if e["meaning"][:2] in t else ""  # rfind: meaning "동" after badge "동"
                cy = hit["y"] + hit["h"] / 2
                own_line = next((l for l in ko if l is not hit and abs(l["y"] + l["h"] / 2 - cy) < 0.012
                                 and -0.01 <= hit["x"] - (l["x"] + l["w"]) < 0.04 and l["t"].strip()[:1] in POS + "8g"), None)
                if not pre.strip() and own_line:
                    kinds["badge read as its own line"] += 1
                elif pre.strip() and pre.strip()[0] in POS and pre.endswith(" "): kinds["badge read, separated"] += 1
                elif pre.strip() and pre.strip()[0] in POS: kinds["badge glued to the meaning"] += 1
                elif pre.strip().startswith("8"): kinds["badge read as 8"] += 1
                elif not pre.strip(): kinds["badge not output"] += 1
                else: kinds[f"other prefix"] += 1
        print(f"{name:<7} " + ", ".join(f"{k}={v}" for k, v in kinds.most_common()))


def crop_test():
    """Lines with a star glyph and lone single-stroke kanji, whole photo vs the headword/star column crop."""
    full, crop = RAW / "upright-bitmap", RAW / "crop-bitmap"
    pages = sorted(p.name.split(".")[0] for p in crop.glob("*.ja.raw.json"))
    if not pages:
        return
    section(f"crop test (Japanese pass, pages {' '.join(pages)}): whole photo -> headword/star columns only")
    for name, d in (("whole", full), ("crop", crop)):
        texts = [l["t"].strip() for p in pages for b in read_json(d / f"{p}.ja.raw.json")["blocks"] for l in b["lines"]]
        stars = sum(any(s in t for s in STARS) for t in texts if "2010" not in t)
        singles = sum(t in ("一", "二", "三", "十") for t in texts)
        print(f"{name:<6} lines={len(texts)}  lines with a star glyph={stars}  lone 一二三十 lines={singles}")


if __name__ == "__main__":
    counts(); confidence(); geometry(); stars(); badges()
    if RAW:
        crop_test()
