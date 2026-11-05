#!/usr/bin/env python3
"""Reference prototype: OCR lines (two passes) -> textbook entries, scored against ground truth.

This is the behaviour spec the Dart `core` package must reproduce (templates + correctors).
Input: <data>/<page>.{ja,ko}.json (OCR probe output, normalized boxes, top-left origin) and
       <data>/ground_truth.json.
Usage: python3 tools/reference/parse_eval.py [--verbose] [--data DIR]
  --data: default $SHIORI_PRIVATE_DIR/textbook/vocab_n5n3 (SHIORI_PRIVATE_DIR defaults to
          <repo>/.private; the recorded textbook pages are not in the repository).
          The synthetic pages in the repository: --data packages/core/test/fixtures/synthetic

The parsing and scoring logic is frozen; only the data location is configurable.
"""
import difflib
import json
import os
import re
import statistics
import sys
import unicodedata
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PRIVATE = Path(os.environ.get("SHIORI_PRIVATE_DIR") or REPO / ".private")
DATA = (Path(sys.argv[sys.argv.index("--data") + 1]) if "--data" in sys.argv[:-1]
        else PRIVATE / "textbook" / "vocab_n5n3")
VERBOSE = "--verbose" in sys.argv

# ---------------------------------------------------------------- text helpers

def is_hira(c): return "぀" <= c <= "ゟ"
def is_kata(c): return "゠" <= c <= "ヿ"
def is_kanji(c): return "一" <= c <= "鿿" or c in "々〆"
def is_hangul(c): return "가" <= c <= "힣"
def is_jp(c): return is_hira(c) or is_kata(c) or is_kanji(c) or c in "、。「」？！・ー〜?!，,0123456789０１２３４５６７８９"

def kana_only(s):
    s = s.replace(" ", "").replace("/", "")
    return bool(s) and all(is_hira(c) or is_kata(c) for c in s)

def ratio(s, pred):
    chars = [c for c in s if not c.isspace()]
    return sum(pred(c) for c in chars) / len(chars) if chars else 0.0

def nfkc(s): return unicodedata.normalize("NFKC", s)

# ---------------------------------------------------------------- page model

class Line:
    def __init__(self, d):
        self.t = d["t"]; self.c = d["c"]
        self.x, self.y, self.w, self.h = d["x"], d["y"], d["w"], d["h"]
        self.cy = self.y + self.h / 2

def load(fixture):
    ja = [Line(d) for d in json.load(open(DATA / f"{fixture}.ja.json"))["lines"]]
    ko = [Line(d) for d in json.load(open(DATA / f"{fixture}.ko.json"))["lines"]]
    return ja, ko

ID_RE = re.compile(r"^\s*([0-9Il|]{4})(?=\s|$|[□口ロコ■])")
SHORT_ID_RE = re.compile(r"^\s*([0-9Il|]{2,3})\s*[□口ロコ■]{2,}")

def anchors(ja):
    out = []
    for l in ja:
        m = ID_RE.match(l.t)
        if m:
            digits = m.group(1).replace("I", "1").replace("l", "1").replace("|", "1")
            if digits.isdigit():
                out.append((l, digits))
        elif SHORT_ID_RE.match(l.t):
            out.append((l, None))  # id digits lost; fill from the sequence
    out.sort(key=lambda a: a[0].cy)
    for i, (l, no) in enumerate(out):
        if no is None:
            prev = out[i - 1][1] if i and out[i - 1][1] else None
            nxt = out[i + 1][1] if i + 1 < len(out) and out[i + 1][1] else None
            no = f"{int(prev) + 1:04d}" if prev else (f"{int(nxt) - 1:04d}" if nxt else None)
            out[i] = (l, no)
    return out

# checkbox squares and the POS badge are read as these glyphs
NOISE_RUN = re.compile(r"^[□口ロコ■LDレ目問gG8]{2,}\s*")
NOISE_ONE = re.compile(r"^[□口ロコ■LDレ目問gG8]\s+")

def clean_head(s, over_checkbox=False):
    s = re.sub(r"^\s*[0-9Il|]{4}\s*", "", s)
    if over_checkbox:
        s = re.sub(r"^[□口ロコ■NLDレ目問gG8\s]+", "", s)
    s = NOISE_RUN.sub("", s); s = NOISE_ONE.sub("", s)
    return s.replace("★", "").replace(" ", "").strip()

POS_MAP = {"명": "명", "몀": "명", "동": "동", "통": "동", "형": "형", "い형": "い형", "な형": "な형",
           "부": "부", "접": "접", "감": "감", "연": "연", "조": "조"}
POS_RE = re.compile(r"^(い형|な형|명|몀|동|통|형|부|접|감|연|조)(?:\s*[.:·]?\s+|$)")

def split_pos(meaning):
    m = POS_RE.match(meaning)
    if not m: return None, meaning
    return POS_MAP[m.group(1)], meaning[m.end():].strip()

def clean_meaning(s):
    s = nfkc(s).replace("，", ",")
    s = re.sub(r"\s+", " ", s).strip(" .")
    return s

def parse_readings(s):
    s = nfkc(s).replace(" ", "")
    if s in {"-", "–", "—", "ー", "−", "一", ""}: return []
    return [p for p in (re.sub(r"[^぀-ヿ]", "", x) for x in s.split("/")) if p]

def norm_title(t): return re.sub(r"\s*[•·・]\s*", "·", t.strip())

def footer_meta(ko, ja=()):
    jday = next((int(m.group(1)) for l in ja for m in [re.search(r"DAY\s*0?(\d{1,2})\b", nfkc(l.t))] if m), None)
    for l in sorted(ko, key=lambda l: -l.cy):
        m = re.search(r"DAY\s*(\S{1,2})\s+(.+?)\s+(\d{1,3})\s*$", nfkc(l.t))
        if m:
            tok = {"이": "01", "ㅇ1": "01"}.get(m.group(1), m.group(1))
            day = int(tok) if tok.isdigit() else jday
            return day, norm_title(m.group(2)), int(m.group(3))
    day = title = page = None
    days = [l for l in ko if l.t.strip().upper() == "DAY"]
    if days:
        d = days[0]
        nums = [l for l in ko if l.t.strip().isdigit() and abs(l.cy - d.cy) < 0.05]
        if nums: day = int(nums[0].t)
        titles = [l for l in ko if abs(l.cy - d.cy) < 0.05 and ratio(l.t, is_hangul) > 0.5]
        if titles: title = titles[0].t.strip()
    for l in ko:
        m = re.match(r"^(\d{1,3})\s+\D", l.t)
        if m and l.cy > 0.9: page = int(m.group(1))
    return day, title, page

# ---------------------------------------------------------------- correctors

CONFUSABLE_WHOLE = {"ー": "一", "-": "一", "—": "一", "+": "十", "ニ": "二", "ハ": "八", "ロ": "口"}
CONFUSABLE_IN_KANJI = {"タ": "夕", "ロ": "口", "エ": "工", "カ": "力", "ニ": "二", "ハ": "八"}

def correct(e):
    h = e["headword"]
    if h in CONFUSABLE_WHOLE and e["readings"]:
        e["headword"] = CONFUSABLE_WHOLE[h]; e["issues"].append("headword:corrected")
    elif any(is_kanji(c) for c in h) and any(c in CONFUSABLE_IN_KANJI for c in h):
        e["headword"] = "".join(CONFUSABLE_IN_KANJI.get(c, c) for c in h); e["issues"].append("headword:corrected")
    h = e["headword"]; rd = e["readings"][0] if e["readings"] else ""
    if rd and any(is_kata(c) for c in h) and all(is_hira(c) for c in rd) and not any(c in "ー" for c in h):
        # e.g. 力む read as カム: trailing kana that match the reading become hiragana, look-alikes become kanji
        chars = list(h)
        k = len(rd) - 1
        for i in range(len(chars) - 1, -1, -1):
            c = chars[i]
            hira = chr(ord(c) - 0x60) if is_kata(c) else c
            if k >= 0 and hira == rd[k]:
                chars[i] = hira; k -= 1
            elif c in CONFUSABLE_IN_KANJI:
                chars[i] = CONFUSABLE_IN_KANJI[c]
            else:
                break
        fixed = "".join(chars)
        if fixed != h:
            e["headword"] = fixed; e["issues"].append("headword:corrected")
    if not e["headword"]:
        e["issues"].append("headword:missing")
    if any(is_kanji(c) for c in e["headword"]) and not e["readings"]:
        e["issues"].append("readings:missing")
    if not e["meaning"]:
        e["issues"].append("meaning:missing")
    if e["pos"] is None:
        e["issues"].append("pos:missing")
    return e

# ---------------------------------------------------------------- template A: one row per word

LEGEND_RE = re.compile(r"표시\s*=|기출 단어|^\s*DAY\b|^\s*PART\b|mp3")

def parse_list(ja, ko):
    anc = [a for a in anchors(ja) if a[1]]
    gap = statistics.median([b[0].cy - a[0].cy for a, b in zip(anc, anc[1:])]) if len(anc) > 1 else 0.045
    # cluster anchors by x: a photo may include the neighbouring page
    clusters = []
    for a in sorted(anc, key=lambda a: a[0].x):
        if clusters and abs(a[0].x - clusters[-1][-1][0].x) < 0.12: clusters[-1].append(a)
        else: clusters.append([a])
    entries = []
    for ci, cl in enumerate(clusters):
        ax0 = statistics.median([a[0].x for a in cl])
        right = statistics.median([a[0].x for a in clusters[ci + 1]]) - 0.03 if ci + 1 < len(clusters) else 1.01
        mine = lambda ls: [l for l in ls if ax0 - 0.04 <= l.x < right and not LEGEND_RE.search(l.t)]
        jl_all, kl_all = mine(ja), mine(ko)
        is_reading = lambda l, ax: ax + 0.195 <= l.x <= ax + 0.33 and (kana_only(l.t) or nfkc(l.t).strip() in {"-", "–", "—", "−", "一"})
        # page geometry: id label offset (b) and row slope (s) from word/reading pairs
        offs, slopes = [], []
        for a, _ in cl:
            w = [l for l in jl_all if a.x + 0.02 <= l.x < a.x + 0.17 and abs(l.cy - a.cy) < 0.6 * gap and l.h > 0.012]
            r = [l for l in jl_all if is_reading(l, a.x) and abs(l.cy - a.cy) < 0.6 * gap]
            if w:
                w0 = min(w, key=lambda l: abs(l.cy - a.cy)); offs.append(w0.cy - a.cy)
                if r:
                    r0 = min(r, key=lambda l: abs(l.cy - w0.cy))
                    if r0.x - w0.x > 0.05: slopes.append((r0.cy - w0.cy) / (r0.x - w0.x))
        b = statistics.median(offs) if offs else 0.0
        sl = statistics.median(slopes) if slopes else 0.0
        # rows: (ref_x, ref_y, anchor_x, id); ref = word-column point
        rows = [(a.x + 0.045, a.cy + b, a.x, no) for a, no in cl]
        for l in jl_all:  # rows whose id was not read, found through the reading column
            if is_reading(l, ax0):
                pred = lambda r: r[1] + sl * (l.x - r[0])
                if all(abs(l.cy - pred(r)) > 0.5 * gap for r in rows):
                    rows.append((l.x, l.cy, ax0, None))
        rows.sort(key=lambda r: r[1])
        for i, r in enumerate(rows):  # infer missing ids from neighbours
            if r[3] is None:
                prev = next((rows[j][3] for j in range(i - 1, -1, -1) if rows[j][3]), None)
                nxt = next((rows[j][3] for j in range(i + 1, len(rows)) if rows[j][3]), None)
                k = (int(prev) + 1) if prev else (int(nxt) - 1 if nxt else None)
                rows[i] = (r[0], r[1], r[2], f"{k:04d}" if k is not None else None)
        # assign every line to its nearest row along the slope
        buckets = {i: ([], []) for i in range(len(rows))}
        for side, ls in ((0, jl_all), (1, kl_all)):
            for l in ls:
                d = [(abs(l.cy - (r[1] + sl * (l.x - r[0]))), i) for i, r in enumerate(rows)]
                dist, i = min(d)
                if dist < 0.55 * gap: buckets[i][side].append(l)
        for i, (rx, ry, ax, no) in enumerate(rows):
            jl, kl = buckets[i]
            head_parts = [l for l in jl if l.x < ax + 0.17 and l.x + l.w > ax + 0.02]
            head = "".join(clean_head(l.t, over_checkbox=l.x < ax + 0.03) for l in sorted(head_parts, key=lambda l: l.x))
            rd = [l for l in jl if is_reading(l, ax)]
            readings = parse_readings(min(rd, key=lambda l: l.x).t) if rd else []
            mparts = [l for l in kl if ax + 0.34 <= l.x <= ax + 0.56]
            meaning = clean_meaning(" ".join(l.t for l in sorted(mparts, key=lambda l: l.x)))
            pos, meaning = split_pos(meaning)
            if not rd:
                continue  # cut-off neighbour rows: no reading column visible
            entries.append(correct({"no": no, "headword": head, "readings": readings, "pos": pos,
                                    "meaning": meaning, "example": None, "issues": []}))
    return entries

# ---------------------------------------------------------------- template B: entry block with example

def parse_entry(ja, ko):
    anc = anchors(ja)
    left = min(a[0].x for a in anc) - 0.03
    entries = []
    for i, (al, no) in enumerate(anc):
        ax, top = al.x, al.cy
        bottom = anc[i + 1][0].cy - 0.004 if i + 1 < len(anc) else 0.93
        inblk = lambda ls, lo, hi: [l for l in ls if lo <= l.cy < hi and l.x >= left]
        row = inblk(ja, top + 0.002, top + 0.05)
        heads = [l for l in row if ax - 0.02 <= l.x < ax + 0.15 and not ID_RE.match(l.t)]
        head = "".join(clean_head(l.t) for l in sorted(heads, key=lambda l: l.x))
        rds = [l for l in row if ax + 0.15 <= l.x <= ax + 0.32 and l.h >= 0.012]
        rd = min(rds, key=lambda l: l.cy) if rds else None
        readings = parse_readings(rd.t) if rd else []
        mrow = [l for l in inblk(ko, top - 0.012, top + 0.05) if l.x >= ax + 0.36 and ratio(l.t, is_hangul) > 0.3]
        meaning = clean_meaning(" ".join(l.t for l in sorted(mrow, key=lambda l: (round(l.cy, 2), l.x))))
        pos, meaning = split_pos(meaning)
        # example: big Japanese lines below the word row (furigana are much shorter)
        ref_h = rd.h if rd else 0.016
        ex_top = (rd.cy if rd else top + 0.02) + 0.012
        cuts = [l.cy for l in inblk(ko, ex_top, bottom) if "관련어" in l.t or "문형" in l.t]
        ex_bottom = min(cuts) - 0.004 if cuts else bottom
        sent = [l for l in inblk(ja, ex_top, ex_bottom) if l.x >= ax + 0.15 and l.h >= 0.75 * ref_h
                and ratio(l.t, is_jp) >= 0.85 and ratio(l.t, is_hangul) == 0 and not re.match(r"^[\[【]", l.t)]
        sent.sort(key=lambda l: l.cy)
        ex_ja = "".join(l.t.strip() for l in sent)
        trans = []
        if sent:
            for l in sorted(inblk(ko, sent[0].cy - 0.005, bottom), key=lambda l: (round(l.cy, 2), l.x)):
                if l.x < ax + 0.15 or "문형" in l.t or "관련어" in l.t: continue
                toks = l.t.split()
                while toks and sum(is_hangul(c) for c in toks[0]) < 2: toks.pop(0)  # glued Japanese tail
                txt = " ".join(toks)
                if txt and ratio(txt, is_hangul) > 0.5: trans.append(txt)
        ex_ko = " ".join(trans)
        example = {"ja": ex_ja, "ko": ex_ko} if ex_ja else None
        e = {"no": no, "headword": head, "readings": readings, "pos": pos, "meaning": meaning,
             "example": example, "issues": []}
        if example is None: e["issues"].append("example:missing")
        entries.append(correct(e))
    return entries

# ---------------------------------------------------------------- template selection

def detect(ja):
    anc = anchors(ja)
    if len(anc) < 2: return "list"
    gap = statistics.median([b[0].cy - a[0].cy for a, b in zip(anc, anc[1:])])
    return "entry" if gap > 0.08 else "list"

# ---------------------------------------------------------------- scoring

def norm_m(s): return re.sub(r"\s+", "", nfkc(s or "")).replace("，", ",")
def sim(a, b): return difflib.SequenceMatcher(None, nfkc(a or ""), nfkc(b or "")).ratio()

def main():
    if not (DATA / "ground_truth.json").is_file():
        sys.exit(f"ground truth not found: {DATA / 'ground_truth.json'} (set SHIORI_PRIVATE_DIR or pass --data DIR)")
    gt = json.load(open(DATA / "ground_truth.json"))
    fields = ["headword", "readings", "pos", "meaning"]
    tot = {f: [0, 0] for f in fields + ["ex_ja", "ex_ko", "row", "found"]}
    silent = flagged_wrong = flagged_ok = 0
    report = []
    for pg in gt["pages"]:
        ja, ko = load(pg["fixture"])
        tpl = detect(ja)
        got = (parse_list if tpl == "list" else parse_entry)(ja, ko)
        byno = {e["no"]: e for e in got}
        day, title, page = footer_meta(ko, ja)
        per = {f: 0 for f in fields}; rows_ok = ex_ja_ok = ex_ko_ok = 0; found = 0
        for g in pg["entries"]:
            e = byno.get(g["no"])
            tot["found"][1] += 1; tot["row"][1] += 1
            if not e:
                if VERBOSE: print(f'  MISS {pg["page"]} {g["no"]} {g["headword"]}')
                continue
            found += 1; tot["found"][0] += 1
            ok = {"headword": e["headword"] == g["headword"], "readings": e["readings"] == g["readings"],
                  "pos": e["pos"] == g["pos"], "meaning": norm_m(e["meaning"]) == norm_m(g["meaning"])}
            for f in fields:
                tot[f][1] += 1; tot[f][0] += ok[f]; per[f] += ok[f]
            row_ok = all(ok.values())
            if "example" in g:
                ja_ok = bool(e["example"]) and sim(e["example"]["ja"], g["example"]["ja"]) >= 0.9
                ko_ok = bool(e["example"]) and sim(e["example"]["ko"], g["example"]["ko"]) >= 0.9
                tot["ex_ja"][1] += 1; tot["ex_ja"][0] += ja_ok; ex_ja_ok += ja_ok
                tot["ex_ko"][1] += 1; tot["ex_ko"][0] += ko_ok; ex_ko_ok += ko_ok
            tot["row"][0] += row_ok; rows_ok += row_ok
            flagged = bool(e["issues"]) and any(not i.startswith("example") for i in e["issues"])
            core_ok = all(ok[f] for f in ("headword", "readings", "meaning"))
            if not core_ok and not flagged: silent += 1
            if not core_ok and flagged: flagged_wrong += 1
            if core_ok and flagged: flagged_ok += 1
            if VERBOSE and (not row_ok or e["issues"]):
                bad = [f for f in fields if not ok[f]]
                print(f'  {pg["page"]} {g["no"]} bad={bad} issues={e["issues"]} got={e["headword"]}|{"/".join(e["readings"])}|{e["pos"]}|{e["meaning"]}')
        n = len(pg["entries"])
        report.append((pg["page"], tpl, n, found, per, rows_ok, ex_ja_ok, ex_ko_ok,
                       (day, title, page) == (pg["day"], pg["title"], pg["page"]), (day, title, page)))
    print("page tpl  n found head read pos  mean row  exJA exKO meta")
    for p, tpl, n, found, per, rows_ok, exj, exk, meta_ok, meta in report:
        exs = f"{exj:>4} {exk:>4}" if tpl == "entry" else "   -    -"
        print(f"{p:>4} {tpl:<5}{n:>2} {found:>5} {per['headword']:>4} {per['readings']:>4} {per['pos']:>4} "
              f"{per['meaning']:>4} {rows_ok:>4} {exs} {'ok' if meta_ok else meta}")
    print("\nTOTAL  " + "  ".join(f"{k}={v[0]}/{v[1]}" for k, v in tot.items()))
    print(f"core fields wrong but NOT flagged (silent errors): {silent}")
    print(f"core fields wrong and flagged for review: {flagged_wrong};  flagged but actually correct: {flagged_ok}")

if __name__ == "__main__":
    main()
