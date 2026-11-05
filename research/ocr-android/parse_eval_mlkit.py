#!/usr/bin/env python3
"""ML Kit variant of the reference parser/scorer (research/ocr/prototype/parse_eval.py).

Same templates, correctors and scoring; every change is a named rule that can be switched off, so its effect on the
score can be measured. With every rule off (`--off all`) the output equals the reference parser on any fixtures.

usage: python3 parse_eval_mlkit.py --fixtures DIR [--gt FILE] [--verbose] [--strict] [--off r1,r2|all] [--ablation]
  --fixtures: folder of <page>.{ja,ko}.json (Vision format); default $SHIORI_PRIVATE_DIR/textbook/ocr-android/fixtures
  --gt:       ground_truth.json; default $SHIORI_PRIVATE_DIR/textbook/vocab_n5n3/ground_truth.json
  SHIORI_PRIVATE_DIR defaults to <repo>/.private: recorded textbook pages are not in the repository.
  --off:      rules to disable;  --ablation: score with all rules, each rule removed, and rules added one by one
  --strict:   also count "strict silent" errors: a wrong core field whose own field carries no issue
              (the reference counts an entry as flagged when it has any issue, e.g. only pos:inferred)

Rules (see README.md "보정 규칙" for the evidence behind each):
  id_ocr          id digits read as O/o/D -> 0, checkbox read as O glued after the id ("1212O")
  star_split      ★ (or * ☆ ＊) glued to the reading or headword is split off into its own line ("★かわ")
  reading_token   a reading is the first space-separated token ("ひかる で" -> ひかる)
  kata_lookalike  katakana look-alikes inside a hiragana reading become hiragana (のリかえる -> のりかえる)
  keep_anchored   A: a row whose id was read is kept even if its reading was not read (flagged readings:missing)
  row_ids         A: rows whose id was not read count on from the nearest read id (the reference can give two rows
                  the same id when unread rows follow each other)
  entry_fallback  B: entries whose id line was not read are found from the headword / reading row
  sentence_geom   B: example and translation lines may start left of the column (stray glyph glued in front),
                  kana-only lines are furigana not sentence, height reference is capped by the page median reading height
  pos_8           POS badge 동 read as "8"
  pos_glued       POS badge glued to the meaning ("명산", "명3, 셋") is split off when it sits where badges sit
  pos_infer       badge not read at all: 동 for kanji + u-row okurigana, 명 for kanji-only; flagged pos:inferred
  low_conf        lines with confidence < 0.2 are dropped (ML Kit garbage when one language reads the other)
  meta_day        DAY number fallback must sit next to the DAY label (not the neighbour page's id "0013")
  ko_period       a period between Hangul words in a title or meaning is a comma ("자연. 몸", "싸다. 포장하다")
  bar_noise       a "|" glued in front of a headword or reading is dropped ("|揺れる", "| ゆれる")
  sentence_conf   B: example lines need confidence >= 0.4 (the Japanese pass reads Korean lines as garbage)
  entry_reading   B: the reading must contain kana and must not sit right on top of a sentence (furigana)
  meaning_cut     a meaning that ends with "," lost its last word ("7,"): flagged meaning:suspect
"""
import difflib
import json
import os
import re
import statistics
import sys
import unicodedata
from pathlib import Path


def arg(name, default=None):
    if name not in sys.argv:
        return default
    i = sys.argv.index(name) + 1
    if i >= len(sys.argv):
        sys.exit(f"{name} needs a value (usage at the top of {Path(__file__).name})")
    return sys.argv[i]


HERE = Path(__file__).resolve().parent
PRIVATE = Path(os.environ.get("SHIORI_PRIVATE_DIR") or HERE.parents[1] / ".private")
VERBOSE = "--verbose" in sys.argv
FIXTURES = Path(arg("--fixtures", PRIVATE / "textbook" / "ocr-android" / "fixtures"))
GROUND_TRUTH = Path(arg("--gt", PRIVATE / "textbook" / "vocab_n5n3" / "ground_truth.json"))

RULES_ALL = ["id_ocr", "star_split", "reading_token", "kata_lookalike", "keep_anchored", "row_ids", "entry_fallback",
             "sentence_geom", "pos_8", "pos_glued", "pos_infer", "low_conf", "meta_day", "ko_period",
             "bar_noise", "sentence_conf", "entry_reading", "meaning_cut"]
_off = [r for r in arg("--off", "").split(",") if r]
if set(_off) - set(RULES_ALL) - {"all"}:
    sys.exit(f"unknown rule in --off: {', '.join(sorted(set(_off) - set(RULES_ALL) - {'all'}))}")
RULES = set() if "all" in _off else set(RULES_ALL) - set(_off)


def on(rule):
    return rule in RULES

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

LOW_CONF = 0.2
SENTENCE_CONF = 0.4
STARS = "★*☆＊"

def split_stars(lines):
    """[mlkit:star_split] ML Kit reads ★ as part of the neighbouring text ("★かわ", "乗り換える*のりかえる").
    Split it into its own line; piece positions are estimated from the character count (no glyph boxes here)."""
    out = []
    for l in lines:
        if len(l.t.strip()) <= 1 or not any(c in STARS for c in l.t):
            lone_star = l.t.strip() and l.t.strip() in STARS  # "*" cut off on its own is the ★ too
            out.append(Line({"t": "★", "c": l.c, "x": l.x, "y": l.y, "w": l.w, "h": l.h}) if lone_star else l)
            continue
        cw = l.w / len(l.t)
        pos = 0
        for piece in re.split(f"([{STARS}])", l.t):
            body = piece.strip()
            if body:
                lead = len(piece) - len(piece.lstrip())
                out.append(Line({"t": "★" if body in STARS else body, "c": l.c, "x": l.x + (pos + lead) * cw,
                                 "y": l.y, "w": len(body) * cw, "h": l.h}))
            pos += len(piece)
    return out

def load(fixture):
    read = lambda lang: json.loads((FIXTURES / f"{fixture}.{lang}.json").read_text(encoding="utf-8"))["lines"]
    ja = [Line(d) for d in read("ja")]
    ko = [Line(d) for d in read("ko")]
    if on("low_conf"):  # a lone star glyph scores low but is checked by position, keep it
        ja = [l for l in ja if l.c >= LOW_CONF or l.t.strip() in STARS]
        ko = [l for l in ko if l.c >= LOW_CONF]
    if on("star_split"):
        ja = split_stars(ja)
    return ja, ko

ID_RE_REF = re.compile(r"^\s*([0-9Il|]{4})(?=\s|$|[□口ロコ■])")
# [mlkit:id_ocr] "O007", "DO17", "1409O" (checkbox read as O right after the digits)
ID_RE_OCR = re.compile(r"^\s*([0-9OoDIl|]{4})(?=\s|$|[□口ロコ■Oo])")
SHORT_ID_RE = re.compile(r"^\s*([0-9Il|]{2,3})\s*[□口ロコ■]{2,}")
ID_DIGITS = str.maketrans({"I": "1", "l": "1", "|": "1", "O": "0", "o": "0", "D": "0"})

def id_re(): return ID_RE_OCR if on("id_ocr") else ID_RE_REF

def id_digits(token):
    """4 id characters -> digits, or None. The OCR variant needs at least two real digits."""
    if on("id_ocr"):
        if sum(c.isdigit() for c in token) < 2: return None
        digits = token.translate(ID_DIGITS)
    else:
        digits = token.replace("I", "1").replace("l", "1").replace("|", "1")
    return digits if digits.isdigit() else None

def anchors(ja):
    out = []
    for l in ja:
        m = id_re().match(l.t)
        if m:
            digits = id_digits(m.group(1))
            if digits:
                out.append((l, digits))
        elif SHORT_ID_RE.match(l.t):
            out.append((l, None))  # id digits lost; fill from the sequence
    out.sort(key=lambda a: a[0].cy)
    return fill_ids(out)

def interpolate_ids(ids):
    """Unknown ids (None) count on from the nearest known id by position, so a run of unknowns cannot collide with
    a known id. Used by [mlkit:row_ids] and [mlkit:entry_fallback]."""
    known = [(i, int(no)) for i, no in enumerate(ids) if no]
    if not known: return list(ids)
    out = []
    for i, no in enumerate(ids):
        if not no:
            j, k = min(known, key=lambda jk: (abs(jk[0] - i), jk[0] > i))
            n = k + (i - j)
            no = f"{n:04d}" if n >= 0 else None
        out.append(no)
    return out

def fill_ids_runs(out):
    return list(zip([l for l, _ in out], interpolate_ids([no for _, no in out])))

def fill_ids(out):
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
    if on("id_ocr"):
        s = re.sub(r"^\s*[0-9OoDIl|]{4}[Oo]?\s*", "", s)
    s = re.sub(r"^\s*[0-9Il|]{4}\s*", "", s)
    if on("bar_noise"):
        s = re.sub(r"^[|｜]+(?=\S)", "", s)
    if over_checkbox:
        s = re.sub(r"^[□口ロコ■NLDレ目問gG8\s]+", "", s)
    s = NOISE_RUN.sub("", s); s = NOISE_ONE.sub("", s)
    return s.replace("★", "").replace(" ", "").strip()

POS_MAP = {"명": "명", "몀": "명", "동": "동", "통": "동", "형": "형", "い형": "い형", "な형": "な형",
           "부": "부", "접": "접", "감": "감", "연": "연", "조": "조", "8": "동"}
POS_RE_REF = re.compile(r"^(い형|な형|명|몀|동|통|형|부|접|감|연|조)(?:\s*[.:·]?\s+|$)")
POS_RE_8 = re.compile(r"^(い형|な형|명|몀|동|통|형|부|접|감|연|조|8)(?:\s*[.:·]?\s+|$)")  # [mlkit:pos_8]
POS_CHARS = "명몀동통형부접감연조"

def split_pos(meaning):
    m = (POS_RE_8 if on("pos_8") else POS_RE_REF).match(meaning)
    if not m: return None, meaning
    return POS_MAP[m.group(1)], meaning[m.end():].strip()

KO_PERIOD = re.compile(r"(?<=[가-힣])\.\s+(?=[가-힣])")

def clean_meaning(s):
    s = nfkc(s).replace("，", ",")
    s = re.sub(r"\s+", " ", s).strip(" .")
    if on("ko_period"):
        s = KO_PERIOD.sub(", ", s)
    return s

KATA_LOOKALIKE = str.maketrans({"リ": "り", "ヘ": "へ", "ベ": "べ", "ペ": "ぺ"})

def parse_readings(s):
    s = nfkc(s)
    if on("bar_noise"):
        s = re.sub(r"^\s*[|｜]\s*", "", s)
    if on("reading_token") and s.split():
        s = s.split()[0]  # glued neighbour text after a space ("ひかる で")
    s = s.replace(" ", "")
    if s in {"-", "–", "—", "ー", "−", "一", ""}: return []
    out = [p for p in (re.sub(r"[^぀-ヿ]", "", x) for x in s.split("/")) if p]
    if on("kata_lookalike"):
        fixed = [p.translate(KATA_LOOKALIKE) for p in out]
        out = [f if any(is_hira(c) for c in p) and all(is_hira(c) or c == "ー" for c in f) else p
               for p, f in zip(out, fixed)]
    return out

def norm_title(t):
    t = re.sub(r"\s*[•·・]\s*", "·", t.strip())
    if on("ko_period"):
        t = KO_PERIOD.sub(", ", t)
    return t

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
        near = lambda l: abs(l.cy - d.cy) < 0.05
        if on("meta_day"):  # the big DAY digits sit under the label; ids of the next page ("0017") are not it
            near = lambda l: abs(l.cy - d.cy) < 0.05 and abs(l.x - d.x) < 0.1 and len(l.t.strip()) <= 2
        nums = [l for l in ko if l.t.strip().isdigit() and near(l)]
        if nums: day = int(nums[0].t)
        titles = [l for l in ko if abs(l.cy - d.cy) < 0.05 and ratio(l.t, is_hangul) > 0.5]
        if titles: title = norm_title(titles[0].t) if on("ko_period") else titles[0].t.strip()
    for l in ko:
        m = re.match(r"^(\d{1,3})\s+\D", l.t)
        if m and l.cy > 0.9: page = int(m.group(1))
    return day, title, page

# ---------------------------------------------------------------- correctors

CONFUSABLE_WHOLE = {"ー": "一", "-": "一", "—": "一", "+": "十", "ニ": "二", "ハ": "八", "ロ": "口"}
CONFUSABLE_IN_KANJI = {"タ": "夕", "ロ": "口", "エ": "工", "カ": "力", "ニ": "二", "ハ": "八"}
U_ROW = set("うくぐすつぬぶむる")

def infer_pos(h):
    """[mlkit:pos_infer] Fallback when the badge was not read: verbs end in u-row okurigana after a kanji."""
    if len(h) >= 2 and any(is_kanji(c) for c in h) and h[-1] in U_ROW: return "동"
    if h and all(is_kanji(c) for c in h): return "명"
    return None

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
    elif on("meaning_cut") and e["meaning"].endswith((",", "·")):
        e["issues"].append("meaning:suspect")
    if e["pos"] is None and on("pos_infer"):
        e["pos"] = infer_pos(e["headword"])
        if e["pos"]: e["issues"].append("pos:inferred")
    if e["pos"] is None:
        e["issues"].append("pos:missing")
    return e

# ---------------------------------------------------------------- template A: one row per word

LEGEND_RE = re.compile(r"표시\s*=|기출 단어|^\s*DAY\b|^\s*PART\b|mp3")
BADGE_ZONE = 0.012  # [mlkit:pos_glued] how close a glued badge must sit to the badges of neighbouring rows

def unglue_badges(rowdata):
    """[mlkit:pos_glued] "명3, 셋" -> "명 3, 셋" always; "명산" -> "명 산" only when the line starts where the
    separated badges of nearby rows start (a meaning that merely begins with 명/동/부… starts further right)."""
    sep_x = {i: r["mx"] for i, r in enumerate(rowdata) if r["meaning"] and split_pos(r["meaning"])[0]}
    for i, r in enumerate(rowdata):
        m = r["meaning"]
        if len(m) < 2 or m[0] not in POS_CHARS or split_pos(m)[0]: continue
        glue = m[1].isdigit()
        if not glue and is_hangul(m[1]):
            near = [x for j, x in sep_x.items() if j != i and abs(j - i) <= 3]
            glue = bool(near) and abs(r["mx"] - statistics.median(near)) < BADGE_ZONE
        if glue:
            r["meaning"] = m[0] + " " + m[1:]

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
        # rows: (ref_x, ref_y, anchor_x, id, id_was_read); ref = word-column point
        rows = [(a.x + 0.045, a.cy + b, a.x, no, True) for a, no in cl]
        for l in jl_all:  # rows whose id was not read, found through the reading column
            if is_reading(l, ax0):
                pred = lambda r: r[1] + sl * (l.x - r[0])
                if all(abs(l.cy - pred(r)) > 0.5 * gap for r in rows):
                    rows.append((l.x, l.cy, ax0, None, False))
        rows.sort(key=lambda r: r[1])
        if on("row_ids"):
            rows = [(*r[:3], no, r[4]) for r, no in zip(rows, interpolate_ids([r[3] for r in rows]))]
        for i, r in enumerate(rows):  # infer missing ids from neighbours
            if r[3] is None:
                prev = next((rows[j][3] for j in range(i - 1, -1, -1) if rows[j][3]), None)
                nxt = next((rows[j][3] for j in range(i + 1, len(rows)) if rows[j][3]), None)
                k = (int(prev) + 1) if prev else (int(nxt) - 1 if nxt else None)
                rows[i] = (r[0], r[1], r[2], f"{k:04d}" if k is not None else None, r[4])
        # assign every line to its nearest row along the slope
        buckets = {i: ([], []) for i in range(len(rows))}
        for side, ls in ((0, jl_all), (1, kl_all)):
            for l in ls:
                d = [(abs(l.cy - (r[1] + sl * (l.x - r[0]))), i) for i, r in enumerate(rows)]
                dist, i = min(d)
                if dist < 0.55 * gap: buckets[i][side].append(l)
        rowdata = []
        for i, (rx, ry, ax, no, id_read) in enumerate(rows):
            jl, kl = buckets[i]
            head_parts = [l for l in jl if l.x < ax + 0.17 and l.x + l.w > ax + 0.02]
            head = "".join(clean_head(l.t, over_checkbox=l.x < ax + 0.03) for l in sorted(head_parts, key=lambda l: l.x))
            important = any("★" in l.t for l in jl if l.x < ax + 0.23)
            rd = [l for l in jl if is_reading(l, ax)]
            mparts = sorted([l for l in kl if ax + 0.34 <= l.x <= ax + 0.56], key=lambda l: l.x)
            rowdata.append({"no": no, "head": head, "important": important, "rd": rd,
                            "meaning": clean_meaning(" ".join(l.t for l in mparts)),
                            "mx": mparts[0].x if mparts else None, "anchored": id_read})
        if on("pos_glued"):
            unglue_badges(rowdata)
        for r in rowdata:
            readings = parse_readings(min(r["rd"], key=lambda l: l.x).t) if r["rd"] else []
            pos, meaning = split_pos(r["meaning"])
            if not r["rd"]:
                # cut-off neighbour rows: no reading column visible
                # [mlkit:keep_anchored] ML Kit sometimes skips a reading (そら) or the dash of a kana word
                if not (on("keep_anchored") and r["anchored"] and (r["head"] or meaning)):
                    continue
            entries.append(correct({"no": r["no"], "headword": r["head"], "readings": readings, "pos": pos,
                                    "meaning": meaning, "important": r["important"], "example": None, "issues": []}))
    return entries

# ---------------------------------------------------------------- template B: entry block with example

def is_head_line(l, ax):
    return (ax - 0.03 <= l.x <= ax + 0.05 and l.h >= 0.017 and l.w <= 0.16 and len(l.t.strip()) <= 8
            and not id_re().match(l.t) and ratio(l.t, is_hangul) == 0 and ratio(l.t, is_jp) >= 0.6)

def on_sentence(l, ja):
    """Furigana sit right on top of a long sentence line; the word's reading has a gap below it."""
    return any(s is not l and s.w >= 0.2 and not kana_only(s.t) and 0 <= s.cy - l.cy <= 0.025 for s in ja)

def reading_text(l):
    t = nfkc(l.t).strip()
    if on("bar_noise"):
        t = re.sub(r"^[|｜]\s*", "", t)
    return bool(t.split()) and (kana_only(t.split()[0]) or t in {"-", "–", "—", "−", "一"})

def fallback_anchors(ja, anc):
    """[mlkit:entry_fallback] ML Kit misses small id lines ("1211 ロロロ"). Find word rows from the headword line
    (big text at the id x) or the reading line, and add an anchor above each row that has no id."""
    ax = statistics.median([a[0].x for a in anc])
    heads = [l for l in ja if is_head_line(l, ax)]
    reads = [l for l in ja if ax + 0.15 <= l.x <= ax + 0.22 and l.h >= 0.012 and reading_text(l)
             and not on_sentence(l, ja)]
    rows = []
    for l in sorted(heads + reads, key=lambda l: l.cy):
        if rows and l.cy - rows[-1][-1].cy < 0.035: rows[-1].append(l)
        else: rows.append([l])
    out = list(anc)
    for row in rows:
        top = min(l.cy for l in row) - 0.018
        if any(top - 0.03 <= a[0].cy <= top + 0.03 for a in anc):
            continue
        out.append((Line({"t": "", "c": 0.0, "x": ax, "y": top - 0.003, "w": 0.02, "h": 0.006}), None))
    out.sort(key=lambda a: a[0].cy)
    return fill_ids_runs(out)

def long_in_col(l, ax):
    """In the example column, or a long line whose box a stray glyph glued in front pulled left."""
    return l.x >= ax + 0.15 or (l.w >= 0.3 and l.x >= ax and l.x + l.w >= ax + 0.35)

def parse_entry(ja, ko):
    anc = anchors(ja)
    if on("entry_fallback") and anc:
        anc = fallback_anchors(ja, anc)
    if not anc:
        return []
    left = min(a[0].x for a in anc) - 0.03
    blocks = []
    for i, (al, no) in enumerate(anc):
        ax, top = al.x, al.cy
        bottom = anc[i + 1][0].cy - 0.004 if i + 1 < len(anc) else 0.93
        inblk = lambda ls, lo, hi: [l for l in ls if lo <= l.cy < hi and l.x >= left]
        row = inblk(ja, top + 0.002, top + 0.05)
        heads = [l for l in row if ax - 0.02 <= l.x < ax + 0.15 and not id_re().match(l.t)]
        rds = [l for l in row if ax + 0.15 <= l.x <= ax + 0.32 and l.h >= 0.012]
        if on("entry_reading"):
            rds = [l for l in rds if reading_text(l) and not on_sentence(l, ja)]
        blocks.append((al, no, ax, top, bottom, inblk, row, heads, min(rds, key=lambda l: l.cy) if rds else None))
    # [mlkit:sentence_geom] a reading glued to the headword is as tall as the headword: cap it by the page median
    page_ref_h = statistics.median([b[8].h for b in blocks if b[8]] or [0.016])
    entries = []
    for al, no, ax, top, bottom, inblk, row, heads, rd in blocks:
        head = "".join(clean_head(l.t) for l in sorted(heads, key=lambda l: l.x))
        important = any("★" in l.t for l in row if l.x < ax + 0.2)
        readings = parse_readings(rd.t) if rd else []
        mrow = [l for l in inblk(ko, top - 0.012, top + 0.05) if l.x >= ax + 0.36 and ratio(l.t, is_hangul) > 0.3
                and not (on("entry_fallback") and LEGEND_RE.search(l.t))]  # an anchor made at the top reaches the legend
        meaning = clean_meaning(" ".join(l.t for l in sorted(mrow, key=lambda l: (round(l.cy, 2), l.x))))
        pos, meaning = split_pos(meaning)
        # example: big Japanese lines below the word row (furigana are much shorter)
        ref_h = rd.h if rd else 0.016
        if on("sentence_geom"):
            ref_h = min(ref_h, page_ref_h)
        ex_top = (rd.cy if rd else top + 0.02) + 0.012
        cuts = [l.cy for l in inblk(ko, ex_top, bottom) if "관련어" in l.t or "문형" in l.t]
        ex_bottom = min(cuts) - 0.004 if cuts else bottom
        in_col = lambda l: l.x >= ax + 0.15
        if on("sentence_geom"):  # a stray glyph glued in front ("送次の駅で…") pulls a long line's box left
            in_col = lambda l: long_in_col(l, ax) and not kana_only(l.t)
        sent = [l for l in inblk(ja, ex_top, ex_bottom) if in_col(l) and l.h >= 0.75 * ref_h
                and ratio(l.t, is_jp) >= 0.85 and ratio(l.t, is_hangul) == 0 and not re.match(r"^[\[【]", l.t)
                and (not on("sentence_conf") or l.c >= SENTENCE_CONF)]
        sent.sort(key=lambda l: l.cy)
        ex_ja = "".join(l.t.strip() for l in sent)
        trans = []
        if sent:
            for l in sorted(inblk(ko, sent[0].cy - 0.005, bottom), key=lambda l: (round(l.cy, 2), l.x)):
                in_trans_col = long_in_col(l, ax) if on("sentence_geom") else l.x >= ax + 0.15
                if not in_trans_col or "문형" in l.t or "관련어" in l.t: continue
                toks = l.t.split()
                while toks and sum(is_hangul(c) for c in toks[0]) < 2: toks.pop(0)  # glued Japanese tail
                txt = " ".join(toks)
                if txt and ratio(txt, is_hangul) > 0.5: trans.append(txt)
        ex_ko = " ".join(trans)
        example = {"ja": ex_ja, "ko": ex_ko} if ex_ja else None
        e = {"no": no, "headword": head, "readings": readings, "pos": pos, "meaning": meaning,
             "important": important, "example": example, "issues": []}
        if example is None: e["issues"].append("example:missing")
        entries.append(correct(e))
    return entries

# ---------------------------------------------------------------- template selection

def detect(ja):
    anc = anchors(ja)
    if on("entry_fallback") and len(anc) == 1:
        anc = fallback_anchors(ja, anc)  # one id read: the word rows give the row spacing
    if len(anc) < 2: return "list"
    gap = statistics.median([b[0].cy - a[0].cy for a, b in zip(anc, anc[1:])])
    return "entry" if gap > 0.08 else "list"

# ---------------------------------------------------------------- scoring

def norm_m(s): return re.sub(r"\s+", "", nfkc(s or "")).replace("，", ",")
def sim(a, b): return difflib.SequenceMatcher(None, nfkc(a or ""), nfkc(b or "")).ratio()

def evaluate(verbose=False):
    if not GROUND_TRUTH.is_file():
        sys.exit(f"ground truth not found: {GROUND_TRUTH} (pass --gt)")
    gt = json.loads(GROUND_TRUTH.read_text(encoding="utf-8"))
    fields = ["headword", "readings", "pos", "meaning", "important"]
    tot = {f: [0, 0] for f in fields + ["ex_ja", "ex_ko", "row", "found"]}
    silent = flagged_wrong = flagged_ok = strict = 0
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
                if verbose: print(f'  MISS {pg["page"]} {g["no"]} {g["headword"]}')
                continue
            found += 1; tot["found"][0] += 1
            ok = {"headword": e["headword"] == g["headword"], "readings": e["readings"] == g["readings"],
                  "pos": e["pos"] == g["pos"], "meaning": norm_m(e["meaning"]) == norm_m(g["meaning"]),
                  "important": e["important"] == g["important"]}
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
            field_flag = {"headword": "headword:", "readings": "readings:", "meaning": "meaning:"}
            strict += any(not ok[f] and not any(i.startswith(field_flag[f]) for i in e["issues"]) for f in field_flag)
            if verbose and (not row_ok or e["issues"]):
                bad = [f for f in fields if not ok[f]]
                print(f'  {pg["page"]} {g["no"]} bad={bad} issues={e["issues"]} got={e["headword"]}|{"/".join(e["readings"])}|{e["pos"]}|{e["meaning"]}|{"★" if e["important"] else ""}')
        n = len(pg["entries"])
        report.append((pg["page"], tpl, n, found, per, rows_ok, ex_ja_ok, ex_ko_ok,
                       (day, title, page) == (pg["day"], pg["title"], pg["page"]), (day, title, page)))
    return tot, silent, flagged_wrong, flagged_ok, report, strict

def print_report(tot, silent, flagged_wrong, flagged_ok, report, strict):
    print("page tpl  n found head read pos  mean star row  exJA exKO meta")
    for p, tpl, n, found, per, rows_ok, exj, exk, meta_ok, meta in report:
        exs = f"{exj:>4} {exk:>4}" if tpl == "entry" else "   -    -"
        print(f"{p:>4} {tpl:<5}{n:>2} {found:>5} {per['headword']:>4} {per['readings']:>4} {per['pos']:>4} "
              f"{per['meaning']:>4} {per['important']:>4} {rows_ok:>4} {exs} {'ok' if meta_ok else meta}")
    print("\nTOTAL  " + "  ".join(f"{k}={v[0]}/{v[1]}" for k, v in tot.items()))
    print(f"core fields wrong but NOT flagged (silent errors): {silent}")
    print(f"core fields wrong and flagged for review: {flagged_wrong};  flagged but actually correct: {flagged_ok}")
    if "--strict" in sys.argv:
        print(f"strict silent (wrong core field with no issue on that field): {strict}")

def summary(result):
    tot, silent, flagged_wrong, _, report, strict = result
    meta = sum(r[8] for r in report)
    keys = ("found", "row", "headword", "readings", "pos", "meaning", "important", "ex_ja", "ex_ko")
    return ("  ".join(f"{k}={tot[k][0]:>2}" for k in keys)
            + f"  meta={meta}  silent={silent}  strict={strict}  flagged_wrong={flagged_wrong}")

def ablation():
    global RULES
    base = set(RULES)
    print(f"{'setting':<26}{summary(evaluate())}")
    RULES = set()
    print(f"{'(all rules off)':<26}{summary(evaluate())}")
    print("-- each rule removed from the full set")
    for r in RULES_ALL:
        RULES = base - {r}
        print(f"{'- ' + r:<26}{summary(evaluate())}")
    print("-- rules added one by one (in listed order)")
    RULES = set()
    for r in RULES_ALL:
        RULES = RULES | {r}
        print(f"{'+ ' + r:<26}{summary(evaluate())}")
    RULES = base

def main():
    if "--ablation" in sys.argv:
        ablation()
    else:
        print_report(*evaluate(VERBOSE))

if __name__ == "__main__":
    main()
