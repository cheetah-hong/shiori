#!/usr/bin/env python3
"""Synthetic textbook pages for tests and the app's sample pages.

Writes made-up words, meanings and example sentences laid out like the two textbook layouts, as the
two OCR passes a device would return (`<page>.ja.json`, `<page>.ko.json`: lines {t,c,x,y,w,h},
normalized boxes, top-left origin), plus `ground_truth.json` with the answers.

    python3 tools/synthetic/make_pages.py           # write packages/core/test/fixtures/synthetic/ and app/assets/dev_samples/
    python3 tools/synthetic/make_pages.py --check   # exit 1 when the committed files are out of date

The core copy also gets ground_truth.json and reference_output.json (the frozen reference parser's output,
which the Dart parity test compares cell by cell).

A second set, packages/core/test/fixtures/synthetic_mlkit/, holds two of the same pages as the Android
ML Kit channel returns them (engine "mlkit", lines cut into pieces at column gaps, continuous confidences),
with the slips that engine makes: a ★ not returned, glued to the reading or read as *, the 동 badge read
as 8, a badge glued to the meaning or not returned, 0 read as O / D in the numbers, the checkbox edge read
as |, a reading glued to the next column, ri read as katakana, a comma read as a period, a meaning cut
after its comma, one language's pass reading the other's lines (low-confidence garbage), entry number
lines not returned, long furigana lines, a stray glyph glued in front of a sentence, and a headword
kanji misread as a look-alike kanji (a silent error).

Every word, meaning, sentence and translation here is invented for the tests. The OCR side carries the
mistakes the parsing and correction rules exist for, so the tests exercise them without real pages:
  checkbox glyphs, a word number that was not read, numbers that lost a digit or read I/l/| for 1,
  a ★ that was not read, ★ on its own or glued to the headword, a skewed page (row slope, drifting
  number column), the neighbouring page's number column, a dash for "no reading" (-, –, 一),
  headwords OCR skipped, look-alike katakana for kanji (ロ, タ, カ, ル), a headword split in two lines,
  misread POS badges (통, 몀, `명:`), a badge on its own line, a misread meaning (a silent error),
  a missing meaning, furigana over examples, two-line examples, the 관련어 and 문형 boxes,
  garbage glued in front of a translation, an example OCR did not read, DAY misread in the footer,
  and a page with no footer (DAY header and page line instead).
"""
from __future__ import annotations

import json
import random
from collections.abc import Callable, Sequence
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT_DIRS = [REPO / "packages" / "core" / "test" / "fixtures" / "synthetic", REPO / "app" / "assets" / "dev_samples"]
MLKIT_DIR = REPO / "packages" / "core" / "test" / "fixtures" / "synthetic_mlkit"
REFERENCE_DUMP = REPO / "tools" / "reference" / "dump_reference.py"
NOTE = ("Synthetic pages made by tools/synthetic/make_pages.py. Every word, meaning, example and "
        "translation is invented; no textbook content.")

JA_LANGS = ["ja-JP", "ko-KR"]
KO_LANGS = ["ko-KR", "ja-JP"]

# Per-character widths (page-width fractions) for the type sizes on the pages.
W_HEAD, W_READ, W_KO, W_SENT, W_FURI = 0.022, 0.0185, 0.0105, 0.0172, 0.0105


def box(t: str, x: float, y: float, w: float, h: float, c: float = 1.0) -> dict:
    return {"t": t, "c": c, "x": round(x, 4), "y": round(y, 4), "w": round(w, 4), "h": round(h, 4)}


def text_width(t: str, per_char: float) -> float:
    return max(1, len(t)) * per_char


class Page:
    """Both OCR passes of one page plus its answer sheet."""

    def __init__(self, fixture: str, page: int, template: str, day: int, title: str, seed: int,
                 engine: str = "synthetic"):
        self.fixture, self.page, self.template, self.day, self.title = fixture, page, template, day, title
        self.engine = engine
        self.ja: list[dict] = []
        self.ko: list[dict] = []
        self.entries: list[dict] = []
        self.rng = random.Random(seed)

    def jitter(self, amount: float = 0.0008) -> float:
        return self.rng.uniform(-amount, amount)

    def both(self, t_ja: str | None, t_ko: str | None, x: float, y: float, w: float, h: float,
             c_ja: float = 1.0, c_ko: float = 1.0) -> None:
        """The same box read by both passes (each pass reads it its own way; None = not read)."""
        if t_ja is not None:
            self.ja.append(box(t_ja, x, y, w, h, c_ja))
        if t_ko is not None:
            self.ko.append(box(t_ko, x, y, w, h, c_ko))

    def truth(self, no: str, headword: str, readings: list[str], pos: str, meaning: str,
              important: bool = False, example: tuple[str, str] | None = None) -> None:
        e = {"no": no, "headword": headword, "readings": readings, "pos": pos, "meaning": meaning,
             "important": important}
        if example:
            e["example"] = {"ja": example[0], "ko": example[1]}
        self.entries.append(e)

    def files(self) -> dict[str, dict]:
        ms_ja, ms_ko = 480 + self.rng.randrange(120), 460 + self.rng.randrange(120)
        mlkit = self.engine == "mlkit"
        return {
            f"{self.fixture}.ja.json": {"engine": self.engine, "langs": ["ja", "en"] if mlkit else JA_LANGS,
                                        "ms": ms_ja, "lines": sorted(self.ja, key=_reading_order)},
            f"{self.fixture}.ko.json": {"engine": self.engine, "langs": ["ko", "en"] if mlkit else KO_LANGS,
                                        "ms": ms_ko, "lines": sorted(self.ko, key=_reading_order)},
        }

    def answer(self) -> dict:
        return {"page": self.page, "fixture": self.fixture, "template": self.template, "day": self.day,
                "title": self.title, "entries": self.entries}


def _reading_order(line: dict) -> tuple:
    # Vision returns lines roughly top to bottom; the parsers must not rely on the order.
    return (round(line["y"], 2), line["x"])


# ---------------------------------------------------------------- layout A: one row per word

def row_geometry(p: Page, i: int, *, ax0: float, ay0: float, gap: float, drift: float,
                 slope: float) -> tuple[float, float, Callable[[float], float]]:
    """Number x, number y and the row's height at x for row i of a list page."""
    ax = ax0 - drift * i + p.jitter(0.0004)
    ay = ay0 + gap * i + p.jitter(0.001)
    ref_x = ax + 0.045

    def y_at(x: float) -> float:  # the page is skewed: a row climbs or falls along x
        return ay + slope * (x - ref_x)

    return ax, ay, y_at


def list_row(p: Page, i: int, r: dict, *, ax0: float, ay0: float, gap: float, drift: float,
             slope: float, reading_x: float) -> None:
    """One word row. r: truth fields plus OCR overrides (see the page builders)."""
    ax, ay, y_at = row_geometry(p, i, ax0=ax0, ay0=ay0, gap=gap, drift=drift, slope=slope)

    no = r["no"]
    id_text = r.get("id", no)
    if id_text is not None:
        p.both(id_text, id_text, ax, ay, 0.0213, 0.0074)
    if r.get("box", "ロロロ") is not None:
        p.both(r.get("box", "ロロロ"), r.get("box_ko", "DDD"), ax + 0.0005, ay + 0.0102, 0.0349, 0.0088, 0.3, 0.5)

    head_parts = r.get("head_ocr", [(r["headword"], 0.045)])
    ko_head = r.get("ko_head", "")
    for t, dx in head_parts:
        x = ax + dx
        p.both(t, ko_head or None, x, y_at(x) - 0.0004, text_width(t, W_HEAD) + (0.03 if dx < 0.01 else 0), 0.0192,
               r.get("c_head", 0.5), 0.3)
    if r.get("star_ocr", r.get("important", False)):
        x = ax + 0.187
        p.both("★", "*", x, y_at(x) + 0.0042, 0.0145, 0.0108, 1.0, 0.5)

    reading = r.get("reading_ocr", "/".join(r["readings"]))
    x = reading_x + p.jitter(0.0006)
    h = 0.0074 if reading == "一" else 0.0150
    p.both(reading, r.get("ko_reading"), x, y_at(x) + 0.001, text_width(reading, W_READ), h, 0.5, 0.3)

    meaning_parts = r.get("meaning_ocr", [(f"{r['pos']} {r['meaning']}", 0.0)])
    for t, dx in meaning_parts:
        x = ax + 0.39 + 0.0012 * i + dx
        p.both(r.get("ja_meaning", "問" + "，" * (i % 2) + "大"), t, x, y_at(x) + 0.004, text_width(t, W_KO), 0.0133,
               0.3, 0.5)
        r = {**r, "ja_meaning": None}  # the Japanese pass reads one garbage line per meaning

    p.truth(no, r["headword"], r["readings"], r["pos"], r["meaning"], r.get("important", False))


def page_s010() -> Page:
    """DAY 01, first page: DAY header instead of a footer, the next page's numbers on the right."""
    p = Page("s010", 10, "list", 1, "자연, 몸", seed=10)
    # header and page edge
    p.both("DAY", "DAY", 0.2461, 0.1148, 0.0640, 0.0248)
    p.both("01", "01", 0.2422, 0.1453, 0.0736, 0.0494)
    p.both(None, "자연, 몸", 0.3720, 0.1291, 0.1508, 0.0412, c_ko=0.5)
    p.both("mp3は豆三", "mp3 듣기", 0.7694, 0.1991, 0.0698, 0.0117, 0.3, 0.5)
    for t, x, y in (("7", 0.0019, 0.2456), ("F7", 0.0484, 0.1904), ("U", 0.0368, 0.2951), ("N", 0.0, 0.4201)):
        p.both(t, t, x, y, 0.0136, 0.0145, 0.5, 0.5)
    rows = [
        # 0001: number not read; the headword is read together with a checkbox glyph
        dict(no="0001", headword="雨", readings=["あめ"], pos="명", meaning="비", important=True,
             id=None, box=None, head_ocr=[("問 雨", -0.002)], ko_head="000 초"),
        # 0002, 0003: OCR skipped a simple one-kanji headword
        dict(no="0002", headword="日", readings=["ひ"], pos="명", meaning="해, 날", head_ocr=[], box="■口口"),
        dict(no="0003", headword="空", readings=["そら"], pos="명", meaning="하늘", head_ocr=[], ko_reading="3<"),
        dict(no="0004", headword="風", readings=["かぜ"], pos="명", meaning="바람", important=True, box="LDD"),
        # 0005: the Korean pass misread the meaning (wrong and not flagged: a silent error)
        dict(no="0005", headword="雲", readings=["くも"], pos="명", meaning="구름",
             meaning_ocr=[("명 구룸", 0.0)], box="コロロ"),
        dict(no="0006", headword="晴れ", readings=["はれ"], pos="명", meaning="맑음", important=True),
        dict(no="0007", headword="雪", readings=["ゆき"], pos="명", meaning="눈", box="■口口"),
        # 0008: 口 read as katakana ロ
        dict(no="0008", headword="口", readings=["くち"], pos="명", meaning="입", head_ocr=[("ロ", 0.05)]),
        # 0009: two readings
        dict(no="0009", headword="明日", readings=["あした", "あす"], pos="명", meaning="내일", box="■ロロ"),
        # 0010: one headword read as two lines
        dict(no="0010", headword="天気予報", readings=["てんきよほう"], pos="명", meaning="일기 예보",
             head_ocr=[("天気", 0.040), ("予報", 0.086)]),
        dict(no="0011", headword="暑い", readings=["あつい"], pos="い형", meaning="덥다", important=True),
        # 0012: kana word, its "no reading" dash read as 一
        dict(no="0012", headword="ちょっと", readings=[], pos="부", meaning="조금, 잠깐", reading_ocr="一",
             box="ロロレ"),
    ]
    for i, r in enumerate(rows):
        list_row(p, i, r, ax0=0.2093, ay0=0.2659, gap=0.0452, drift=0.0021, slope=0.012, reading_x=0.4302)
    # the next page's number column (cut off: no reading column, so no words); it starts below the
    # DAY header, whose number is found among the lines next to the DAY label
    for k in range(12):
        x, y = 0.9205 + 0.0011 * k, 0.1830 + 0.0476 * k
        p.both(f"{13 + k:04d}", f"{13 + k:04d}", x, y, 0.0213, 0.0073)
        p.both("ロロロ" if k % 3 else "■口口", "..." if k % 2 else None, x, y + 0.0102, 0.0368, 0.0088, 0.3, 0.5)
        if k in (0, 2, 5):
            p.both("海山川"[k % 3], "R", 0.9709, y + 0.03, 0.0252, 0.0189, 0.3, 0.5)
    p.both("10早計合列", "10 단어장 예시 페이지", 0.1658, 0.9309, 0.2477, 0.0225, 0.5, 1.0)
    return p


def page_s011() -> Page:
    """DAY 01, second page: legend, footer with DAY misread as 이, stronger skew."""
    p = Page("s011", 11, "list", 1, "자연, 몸", seed=11)
    p.both("★三人=試験上大ON卓", "★ 표시 = 시험에 자주 나온 단어", 0.5465, 0.1265, 0.2461, 0.0132, 0.3, 0.5)
    p.both("DAY", "DAY", 0.8430, 0.2064, 0.0174, 0.0233)
    p.both("mp3は豆", "mp3 듣기", 0.0338, 0.2003, 0.0782, 0.0186, 0.3, 1.0)
    rows = [
        # 0013: the ★ was not read
        dict(no="0013", headword="海", readings=["うみ"], pos="명", meaning="바다", important=True, star_ocr=False),
        # 0014: badge 명 misread as 몀
        dict(no="0014", headword="山", readings=["やま"], pos="명", meaning="산", meaning_ocr=[("몀. 산", 0.0)]),
        # 0015: badge on its own line, left of the meaning
        dict(no="0015", headword="川", readings=["かわ"], pos="명", meaning="강, 개천", important=True,
             meaning_ocr=[("명", 0.0), ("강, 개천", 0.0213)], box="■口口"),
        # 0016: katakana タ inside a kanji word
        dict(no="0016", headword="夕日", readings=["ゆうひ"], pos="명", meaning="석양, 저녁 해",
             head_ocr=[("タ日", 0.045)]),
        # 0017: hiragana okurigana read as katakana
        dict(no="0017", headword="光る", readings=["ひかる"], pos="동", meaning="빛나다", head_ocr=[("光ル", 0.045)]),
        # 0018: a one-kanji word read as katakana カ
        dict(no="0018", headword="力", readings=["ちから"], pos="명", meaning="힘", head_ocr=[("カ", 0.05)],
             box="LDD"),
        dict(no="0019", headword="星", readings=["ほし"], pos="명", meaning="별", important=True),
        dict(no="0020", headword="痛い", readings=["いたい"], pos="い형", meaning="아프다", important=True,
             box="コロロ"),
        # 0021: a 1 in the number read as l
        dict(no="0021", headword="指", readings=["ゆび"], pos="명", meaning="손가락", id="002l"),
        # 0022: the meaning was not read, only its badge
        dict(no="0022", headword="鼻", readings=["はな"], pos="명", meaning="코", meaning_ocr=[("명", 0.0)]),
        # 0023: badge 동 misread as 통
        dict(no="0023", headword="吹く", readings=["ふく"], pos="동", meaning="불다", meaning_ocr=[("통 불다", 0.0)],
             box="■ロロ"),
        # 0024: kana word with an en dash for "no reading"
        dict(no="0024", headword="のんびり", readings=[], pos="부", meaning="느긋하게, 한가로이", reading_ocr="–"),
    ]
    for i, r in enumerate(rows):
        list_row(p, i, r, ax0=0.2112, ay0=0.1830, gap=0.0458, drift=0.0012, slope=0.035, reading_x=0.4302)
    p.both("PART 1N5，N4 E101 ｜ DAY 01全｜人 11", "PART 1 기초 단어 | DAY 이 자연, 몸 11",
           0.6124, 0.9070, 0.2171, 0.0117, 0.5, 0.5)
    return p


# ---------------------------------------------------------------- layout B: entry block with example

def entry_block(p: Page, e: dict, *, ax: float, ty: float) -> None:
    """One entry: number row, word row, furigana, example lines, translation, boxes."""
    p.both(e.get("id", f"{e['no']} ロロロ"), e.get("id_ko", f"{e['no']} DDD"), ax, ty,
           0.0578, 0.0183, 0.5, 1.0)
    head = e.get("head_ocr", e["headword"])
    p.both(head, e.get("ko_head", "#스]"), ax + 0.0115, ty + 0.0208, text_width(head, W_HEAD), 0.0219, 1.0, 0.3)
    if e.get("star_line"):
        p.both("★", "*", ax + 0.146, ty + 0.0275, 0.0155, 0.0131, 1.0, 0.5)
    reading = e.get("reading_ocr", "/".join(e["readings"]) or "–")
    p.both(reading, e.get("ko_reading", "L85yk5"), ax + 0.182, ty + 0.0163, text_width(reading, W_READ), 0.0162,
           1.0, 0.5)
    x = ax + 0.407
    for t, dx in e.get("meaning_ocr", [(f"{e['pos']} {e['meaning']}", 0.0)]):
        p.both("g、" if dx == 0 else "g弖", t, x + dx, ty + 0.0208, text_width(t, W_KO), 0.0132, 0.3, 0.5)

    y = ty + 0.0454
    for t, dx in e.get("furigana", []):
        p.both(t, None, ax + 0.18 + dx, y, text_width(t, W_FURI), 0.0090, 0.5)
    y = ty + 0.0554
    sentence = e.get("sentence_ocr", e["example"][0:1])
    for k, t in enumerate(sentence):
        h = 0.0208 if k == 0 else 0.0161
        p.both(t, e.get("ko_sentence", ["tO", "<tt60"])[k % 2], ax + 0.1798, y, text_width(t, W_SENT), h, 1.0, 0.5)
        y += 0.0256
    for t in e.get("translation_ocr", [e["example"][-1]]):
        p.both(e.get("ja_translation", "0乙OmT 01 9人kO"), t, ax + 0.1802, y - 0.0025, text_width(t, 0.0098),
               0.0131, 0.3, 1.0)
        y += 0.0170
    for ja_t, ko_t in e.get("boxes", []):
        y += 0.0050
        p.both(ja_t, ko_t, ax + 0.21, y, text_width(ko_t, 0.0098), 0.0199, 0.3, 0.5)
        y += 0.0200
    ex = e["example"]
    p.truth(e["no"], e["headword"], e["readings"], e["pos"], e["meaning"], e.get("important", False),
            (ex[0] if len(ex) == 2 else "".join(ex[:-1]), ex[-1]))


def neighbour_page_edge(p: Page, lines: list[tuple[str | None, str | None, float]]) -> None:
    """The previous page's right margin shows at x ≈ 0 (left of every word number)."""
    for t_ja, t_ko, y in lines:
        p.both(t_ja, t_ko, -0.0041 + p.jitter(0.004), y, 0.1550, 0.0450, 0.5, 0.5)


def page_s140() -> Page:
    """DAY 20 (entry layout): footer, legend, furigana, 관련어 and 문형 boxes."""
    p = Page("s140", 140, "entry", 20, "여행·교통", seed=140)
    p.both("★三人=試験上大ON卓", "★ 표시 = 시험에 자주 나온 단어", 0.5637, 0.0703, 0.2370, 0.0167, 0.3, 0.5)
    p.both("DAY", "DAY", 0.8547, 0.2442, 0.0174, 0.0233)
    neighbour_page_edge(p, [("駅前で会いましょう。", "역 앞에서 만나요.", 0.1201),
                            ("地図を見ながら", "지도를 보면서", 0.4215), (None, "길을 물었습니다.", 0.4690),
                            ("ホテルの予約は", "호텔 예약은", 0.7300)])
    entries = [
        # ★ glued to the headword; badge 동 misread as 통
        dict(no="1211", headword="乗り換える", readings=["のりかえる"], pos="동", meaning="갈아타다, 환승하다",
             important=True, head_ocr="乗り換える★", meaning_ocr=[("통 갈아타다, 환승하다", 0.0)],
             furigana=[("つぎ", 0.0), ("えき", 0.032), ("きゅうこう", 0.066), ("の か", 0.12)],
             example=("次の駅で急行に乗り換えてください。", "다음 역에서 급행으로 갈아타 주세요.")),
        # badge read as its own `명:` line; Japanese garbage glued in front of the translation
        dict(no="1212", headword="切符", readings=["きっぷ"], pos="명", meaning="표, 승차권",
             meaning_ocr=[("명:", 0.0), ("표, 승차권", 0.0213)],
             furigana=[("まどぐち", 0.0), ("おおさか", 0.05), ("きっぷ", 0.12), ("にまいか", 0.16)],
             translation_ocr=["5b• 창구에서 오사카까지 가는 표를 두 장 샀습니다."],
             example=("窓口で大阪までの切符を二枚買いました。", "창구에서 오사카까지 가는 표를 두 장 샀습니다.")),
        # I read for 1 in the number; two-line example; the 관련어 box ends the example
        dict(no="1213", headword="到着", readings=["とうちゃく"], pos="명", meaning="도착", id="12I3 ロロロ",
             furigana=[("ひこうき", 0.0), ("よてい", 0.06), ("さんじゅっぷんはや", 0.12)],
             sentence_ocr=["飛行機は予定より三十分早く空港に", "到着しました。"],
             boxes=[("到着時刻 とうちゃくじこく", "관련어 到着時刻 とうちゃくじこく 명 도착 시각")],
             example=("飛行機は予定より三十分早く空港に", "到着しました。", "비행기는 예정보다 30분 일찍 공항에 도착했습니다.")),
        # the number lost a digit (121 → 1214)
        dict(no="1214", headword="渋滞", readings=["じゅうたい"], pos="명", meaning="(교통) 정체", id="121 ロロロ",
             id_ko="121 0.0", furigana=[("あさ", 0.0), ("こうそくどうろ", 0.035), ("じゅうたい", 0.17)],
             example=("朝の高速道路はいつも渋滞しています。", "아침 고속도로는 늘 차가 막혀 있습니다.")),
        # ★ on its own line; the 문형 box ends the example
        dict(no="1215", headword="揺れる", readings=["ゆれる"], pos="동", meaning="흔들리다", important=True,
             star_line=True, furigana=[("ゆ", 0.09), ("た", 0.17)],
             boxes=[("【文型】動詞て形+いられない", "[문형] 동사 て형 + いられない ~(하)고 있을 수 없다")],
             example=("バスがひどく揺れたので、立っていられなかった。", "버스가 심하게 흔들려서 서 있을 수 없었다.")),
        dict(no="1216", headword="降りる", readings=["おりる"], pos="동", meaning="내리다",
             furigana=[("わす もの", 0.0), ("き", 0.15), ("お", 0.2)],
             example=("忘れ物をしないように気をつけて降りてください。", "잊은 물건이 없도록 조심해서 내려 주세요.")),
    ]
    tops = [0.1275, 0.2485, 0.3595, 0.5113, 0.6373, 0.7914]
    for k, (e, ty) in enumerate(zip(entries, tops)):
        entry_block(p, e, ax=0.1901 + 0.0045 * k, ty=ty)
    p.both("PART2 当面 E0 ｜ DAY 20旅行・宮 140", "PART 2 장면별 단어 | DAY 20 여행 • 교통 140",
           0.6047, 0.9273, 0.2590, 0.0146, 0.5, 1.0)
    return p


def page_s147() -> Page:
    """DAY 21 (entry layout): footer DAY unreadable (the Japanese pass has it), an example not read."""
    p = Page("s147", 147, "entry", 21, "쇼핑", seed=147)
    p.both("★三人=試験上大ON卓", "★ 표시 = 시험에 자주 나온 단어", 0.5282, 0.0850, 0.2440, 0.0245, 0.3, 0.5)
    p.both("DAY", "DAY", 0.8798, 0.5887, 0.0233, 0.0247)
    neighbour_page_edge(p, [("いらっしゃいませ。", "어서 오세요.", 0.2880), ("袋はご利用ですか。", "봉투 필요하세요?", 0.6292)])
    entries = [
        dict(no="1271", headword="値段", readings=["ねだん"], pos="명", meaning="가격, 값",
             furigana=[("みせ", 0.05), ("やさい", 0.1), ("ねだん", 0.17), ("やす しんせん", 0.24)],
             example=("この店の野菜は値段が安くて新鮮です。", "이 가게의 채소는 가격이 싸고 신선합니다.")),
        dict(no="1272", headword="売り場", readings=["うりば"], pos="명", meaning="매장", important=True,
             head_ocr="売り場 ★", furigana=[("くつ", 0.0), ("う ば", 0.03), ("さんがい", 0.1)],
             example=("靴の売り場は三階にございます。", "신발 매장은 3층에 있습니다.")),
        # the example sentence was not read (only its furigana and the translation)
        dict(no="1273", headword="試着", readings=["しちゃく"], pos="명", meaning="(옷을) 입어 봄",
             furigana=[("しちゃく", 0.1)], sentence_ocr=[],
             example=("このシャツを試着してもいいですか。", "이 셔츠를 입어 봐도 될까요?")),
        # | read for 1 in the number; badge 동 misread as 통; garbage glued in front of the translation
        dict(no="1274", headword="包む", readings=["つつむ"], pos="동", meaning="싸다, 포장하다", id="|274 ロロロ",
             meaning_ocr=[("통 싸다, 포장하다", 0.0)], furigana=[("つつ", 0.2)],
             translation_ocr=["1증? 선물이라서 예쁘게 포장해 주실 수 있나요?"],
             example=("プレゼントなので、きれいに包んでいただけますか。", "선물이라서 예쁘게 포장해 주실 수 있나요?")),
        # katakana word: the reading column shows a dash
        dict(no="1275", headword="レシート", readings=[], pos="명", meaning="영수증", reading_ocr="-",
             furigana=[("へんぴん", 0.0), ("ひつよう", 0.2)],
             example=("返品するときはレシートが必要です。", "반품할 때는 영수증이 필요합니다.")),
    ]
    tops = [0.1076, 0.2470, 0.3803, 0.5203, 0.6613]
    for k, (e, ty) in enumerate(zip(entries, tops)):
        entry_block(p, e, ax=0.1434 + 0.0034 * k, ty=ty)
    p.both("PART 2 当面 E0 / DAY 21 公三 147", "PART 2 장면별 단어 | DAY 그l 쇼핑 147",
           0.5684, 0.9131, 0.2489, 0.0349, 0.5, 1.0)
    return p


PageBuilder = Callable[[], Page]
PAGES: tuple[PageBuilder, ...] = (page_s010, page_s011, page_s140, page_s147)


# ---------------------------------------------------------------- the same pages as ML Kit reads them

# ML Kit boxes fit the glyphs more tightly than Vision's (height x0.85, width x0.89).
MK_H, MK_W = 0.85, 0.89


def mk_conf(p: Page, lo: float = 0.45, hi: float = 0.95) -> float:
    return round(p.rng.uniform(lo, hi), 4)


def mk_list_row(p: Page, i: int, r: dict, *, ax0: float, ay0: float, gap: float, drift: float,
                slope: float, reading_x: float) -> None:
    """One word row, cut into pieces at the column gaps as the ML Kit channel returns it.
    No checkbox glyphs (ML Kit's Japanese pass rarely returns them)."""
    ax, ay, y_at = row_geometry(p, i, ax0=ax0, ay0=ay0, gap=gap, drift=drift, slope=slope)

    id_text = r.get("id", r["no"])
    if id_text is not None:
        p.ja.append(box(id_text, ax, ay, 0.0190, 0.0063, mk_conf(p)))
    for t, dx in r.get("head_ocr", [(r["headword"], 0.045)]):
        x = ax + dx
        p.ja.append(box(t, x, y_at(x) + 0.001, text_width(t, W_HEAD) * MK_W, 0.0192 * MK_H, mk_conf(p)))
    star = r.get("star_ocr", r.get("important", False))  # True | "*" | "glued" | False
    reading = r.get("reading_ocr", "/".join(r["readings"]) or "–")
    rx = reading_x + p.jitter(0.0006)
    sx = ax + 0.187
    if star is True or star == "*":
        p.ja.append(box("★" if star is True else "*", sx, y_at(sx) + 0.0045, 0.0129, 0.0092, mk_conf(p, 0.25, 0.6)))
    if reading is not None:
        rw = text_width(reading, W_READ) * MK_W
        if star == "glued":  # the ★ and the reading came back as one piece
            p.ja.append(box("★" + reading, sx, y_at(sx) + 0.0015, rx + rw - sx, 0.0150 * MK_H, mk_conf(p)))
        else:
            p.ja.append(box(reading, rx, y_at(rx) + 0.0015, rw, 0.0150 * MK_H, mk_conf(p)))
    for t, dx in r.get("meaning_ocr", [(f"{r['pos']} {r['meaning']}", 0.0)]):
        x = ax + 0.39 + 0.0012 * i + dx
        p.ko.append(box(t, x, y_at(x) + 0.0045, text_width(t, W_KO) * MK_W, 0.0133 * MK_H, mk_conf(p, 0.55, 0.95)))
    if "ko_junk" in r:  # the Korean pass reads the ★ as a Hangul glyph, with very low confidence
        t, dx = r["ko_junk"]
        x = ax + dx
        p.ko.append(box(t, x, y_at(x) + 0.0045, 0.008, 0.0133 * MK_H, 0.12))
    p.truth(r["no"], r["headword"], r["readings"], r["pos"], r["meaning"], r.get("important", False))


def page_m011() -> Page:
    """s011's words as ML Kit reads them."""
    p = Page("m011", 11, "list", 1, "자연, 몸", seed=1011, engine="mlkit")
    p.ja.append(box("★三人=試験上大", 0.5465, 0.1265, 0.2190, 0.0112, 0.31))
    p.ko.append(box("★ 표시 = 시험에 자주 나온 단어", 0.5465, 0.1265, 0.2190, 0.0112, 0.83))
    p.ko.append(box("DAY", 0.8430, 0.2064, 0.0155, 0.0198, 0.9))
    rows = [
        # the ★ was not returned at all
        dict(no="0013", headword="海", readings=["うみ"], pos="명", meaning="바다", important=True, star_ocr=False),
        # 0 of the number read as O
        dict(no="0014", headword="山", readings=["やま"], pos="명", meaning="산", id="OO14"),
        # the ★ and the reading came back as one piece
        dict(no="0015", headword="川", readings=["かわ"], pos="명", meaning="강, 개천", important=True,
             star_ocr="glued"),
        # look-alike katakana in the headword; a comma between Korean words read as a period
        dict(no="0016", headword="夕日", readings=["ゆうひ"], pos="명", meaning="석양, 저녁 해",
             head_ocr=[("タ日", 0.045)], meaning_ocr=[("명 석양. 저녁 해", 0.0)]),
        # a glyph of the next column glued after the reading; the badge was not returned
        dict(no="0017", headword="光る", readings=["ひかる"], pos="동", meaning="빛나다", reading_ocr="ひかる で",
             meaning_ocr=[("빛나다", 0.0213)]),
        # the first checkbox read as O right after the number
        dict(no="0018", headword="力", readings=["ちから"], pos="명", meaning="힘", id="0018O",
             head_ocr=[("カ", 0.05)]),
        # ★ read as *; the badge glued to the meaning
        dict(no="0019", headword="星", readings=["ほし"], pos="명", meaning="별", important=True, star_ocr="*",
             meaning_ocr=[("명별", 0.0)]),
        dict(no="0020", headword="痛い", readings=["いたい"], pos="い형", meaning="아프다", important=True),
        # 0 read as D and 1 as l in the number; the checkbox edge read as | before the headword
        dict(no="0021", headword="指", readings=["ゆび"], pos="명", meaning="손가락", id="D02l",
             head_ocr=[("|指", 0.043)]),
        # low-confidence Hangul garbage in front of the meaning
        dict(no="0022", headword="鼻", readings=["はな"], pos="명", meaning="코", ko_junk=("ㅎ", 0.345)),
        # badge 동 read as 8
        dict(no="0023", headword="吹く", readings=["ふく"], pos="동", meaning="불다", meaning_ocr=[("8 불다", 0.0)]),
        # the dash of a kana word not returned; the meaning lost its last word after the comma
        dict(no="0024", headword="のんびり", readings=[], pos="부", meaning="느긋하게, 한가로이", reading_ocr=None,
             meaning_ocr=[("부 느긋하게,", 0.0)]),
    ]
    for i, r in enumerate(rows):
        mk_list_row(p, i, r, ax0=0.2112, ay0=0.1830, gap=0.0458, drift=0.0012, slope=0.035, reading_x=0.4302)
    p.ja.append(box("PART 1N5", 0.6124, 0.9070, 0.0700, 0.0100, 0.42))
    p.ko.append(box("PART 1 기초 단어 | DAY 01 자연, 몸 11", 0.6124, 0.9070, 0.1932, 0.0100, 0.78))
    return p


def mk_entry_block(p: Page, e: dict, *, ax: float, ty: float) -> None:
    """One entry block as the ML Kit channel returns it."""
    if not e.get("id_missing"):
        p.ja.append(box(e.get("id", e["no"]), ax, ty, 0.0300, 0.0100, mk_conf(p)))
    head = e.get("head_ocr", e["headword"])
    p.ja.append(box(head, ax + 0.0115, ty + 0.0208, text_width(head, W_HEAD) * MK_W, 0.0219 * MK_H, mk_conf(p)))
    # The Korean pass reads the headword as the same garbage glyph every time.
    p.ko.append(box("슴", ax + 0.0115, ty + 0.0208, 0.02, 0.0186, 0.11))
    if e.get("important") and e.get("star_ocr", True):
        p.ja.append(box("★", ax + 0.146, ty + 0.0275, 0.0138, 0.0111, mk_conf(p, 0.25, 0.6)))
    reading = e.get("reading_ocr", "/".join(e["readings"]) or "–")
    p.ja.append(box(reading, ax + 0.182, ty + 0.0163, text_width(reading, W_READ) * MK_W, 0.0162 * MK_H,
                    mk_conf(p)))
    for t, dx in e.get("meaning_ocr", [(f"{e['pos']} {e['meaning']}", 0.0)]):
        p.ko.append(box(t, ax + 0.407 + dx, ty + 0.0208, text_width(t, W_KO) * MK_W, 0.0132 * MK_H,
                        mk_conf(p, 0.6, 0.95)))
    y = ty + 0.0454
    if e.get("furigana"):  # ML Kit joins the furigana of a line into one long kana line
        t = " ".join(f for f, _ in e["furigana"])
        p.ja.append(box(t, ax + 0.18, y, 0.21, 0.0090 * MK_H, mk_conf(p)))
    y = ty + 0.0554
    for k, t in enumerate(e.get("sentence_ocr", e["example"][0:1])):
        h = (0.0208 if k == 0 else 0.0161) * MK_H
        x, w = ax + 0.1798, text_width(t, W_SENT) * MK_W
        if k == 0 and e.get("stray"):  # a glyph of another column glued in front pulls the box left
            t, x, w = e["stray"] + t, ax + 0.06, w + 0.1198
        p.ja.append(box(t, x, y, w, h, mk_conf(p, 0.6, 0.95)))
        p.ko.append(box("다음 엑 굽행", ax + 0.1798, y, 0.1, h, 0.1))  # Korean pass on the sentence: garbage
        y += 0.0256
    for t in e.get("translation_ocr", [e["example"][-1]]):
        x, w = ax + 0.1802, text_width(t, 0.0098) * MK_W
        if e.get("trans_left"):  # the translation box starts left of the example column
            x, w = ax + 0.06, w + 0.1202
        p.ko.append(box(t, x, y - 0.0025, w, 0.0131 * MK_H, mk_conf(p, 0.6, 0.95)))
        # the Japanese pass reads the translation as Japanese garbage, confidence above the
        # low-confidence cut but below what a real sentence gets
        p.ja.append(box("己乙人日本口目", ax + 0.1802, y - 0.0025, 0.12, 0.0131 * MK_H, 0.31))
        y += 0.0170
    for _ja_t, ko_t in e.get("boxes", []):
        y += 0.0050
        p.ko.append(box(ko_t, ax + 0.21, y, text_width(ko_t, 0.0098) * MK_W, 0.0199 * MK_H, mk_conf(p)))
        y += 0.0200
    ex = e["example"]
    p.truth(e["no"], e["headword"], e["readings"], e["pos"], e["meaning"], e.get("important", False),
            (ex[0] if len(ex) == 2 else "".join(ex[:-1]), ex[-1]))


def page_m140() -> Page:
    """s140's words as ML Kit reads them."""
    p = Page("m140", 140, "entry", 20, "여행·교통", seed=1140, engine="mlkit")
    p.ko.append(box("★ 표시 = 시험에 자주 나온 단어", 0.5637, 0.0703, 0.2109, 0.0142, 0.8))
    entries = [
        # ri of the reading read as katakana リ
        dict(no="1211", headword="乗り換える", readings=["のりかえる"], pos="동", meaning="갈아타다, 환승하다",
             important=True, reading_ocr="のリかえる",
             furigana=[("つぎ", 0.0), ("えき", 0.032), ("きゅうこう", 0.066)],
             example=("次の駅で急行に乗り換えてください。", "다음 역에서 급행으로 갈아타 주세요.")),
        # the small number line was not returned; a comma read as a period
        dict(no="1212", headword="切符", readings=["きっぷ"], pos="명", meaning="표, 승차권", id_missing=True,
             meaning_ocr=[("명 표. 승차권", 0.0)],
             example=("窓口で大阪までの切符を二枚買いました。", "창구에서 오사카까지 가는 표를 두 장 샀습니다.")),
        # the badge was not returned; a long furigana line; the 관련어 box ends the example
        dict(no="1213", headword="到着", readings=["とうちゃく"], pos="명", meaning="도착",
             meaning_ocr=[("도착", 0.0213)], furigana=[("ひこうき", 0.0), ("よてい", 0.06), ("さんじゅっぷん", 0.12)],
             sentence_ocr=["飛行機は予定より三十分早く空港に", "到着しました。"],
             boxes=[("", "관련어 到着時刻 とうちゃくじこく 명 도착 시각")],
             example=("飛行機は予定より三十分早く空港に", "到着しました。", "비행기는 예정보다 30분 일찍 공항에 도착했습니다.")),
        # number line not returned; a stray glyph glued in front of the sentence
        dict(no="1214", headword="渋滞", readings=["じゅうたい"], pos="명", meaning="(교통) 정체", id_missing=True,
             stray="送", example=("朝の高速道路はいつも渋滞しています。", "아침 고속도로는 늘 차가 막혀 있습니다.")),
        # the ★ not returned; | in front of the headword; badge 동 read as 8
        dict(no="1215", headword="揺れる", readings=["ゆれる"], pos="동", meaning="흔들리다", important=True,
             star_ocr=False, head_ocr="|揺れる", meaning_ocr=[("8 흔들리다", 0.0)],
             example=("バスがひどく揺れたので、立っていられなかった。", "버스가 심하게 흔들려서 서 있을 수 없었다.")),
        # number line not returned; a headword kanji read as a look-alike kanji (wrong, not flagged);
        # the translation box starts left of the column
        dict(no="1216", headword="降りる", readings=["おりる"], pos="동", meaning="내리다", id_missing=True,
             head_ocr="陸りる", trans_left=True,
             example=("忘れ物をしないように気をつけて降りてください。", "잊은 물건이 없도록 조심해서 내려 주세요.")),
    ]
    tops = [0.1275, 0.2485, 0.3595, 0.5113, 0.6373, 0.7914]
    for k, (e, ty) in enumerate(zip(entries, tops)):
        mk_entry_block(p, e, ax=0.1901 + 0.0045 * k, ty=ty)
    p.ko.append(box("PART 2 장면별 단어 | DAY 20 여행 • 교통 140", 0.6047, 0.9273, 0.2305, 0.0124, 0.81))
    return p


MLKIT_PAGES: tuple[PageBuilder, ...] = (page_m011, page_m140)


# ---------------------------------------------------------------- output

def render(pages: Sequence[PageBuilder] = PAGES) -> dict[str, str]:
    files: dict[str, str] = {}
    answers = []
    for make in pages:
        p = make()
        for name, data in p.files().items():
            files[name] = json.dumps(data, ensure_ascii=False, indent=0) + "\n"
        answers.append(p.answer())
    files["ground_truth.json"] = json.dumps({"_note": NOTE, "pages": answers}, ensure_ascii=False, indent=1) + "\n"
    return files


def reference_output(files: dict[str, str]) -> str:
    """The frozen reference parser's output for these pages (tools/reference/dump_reference.py)."""
    with tempfile.TemporaryDirectory() as tmp:
        for name, text in files.items():
            (Path(tmp) / name).write_text(text, encoding="utf-8")
        subprocess.run([sys.executable, str(REFERENCE_DUMP), "--data", tmp], check=True, stdout=subprocess.DEVNULL)
        return (Path(tmp) / "reference_output.json").read_text(encoding="utf-8")


def main(argv: list[str]) -> int:
    check = "--check" in argv
    files = render()
    core_only = {"ground_truth.json": files["ground_truth.json"], "reference_output.json": reference_output(files)}
    stale = []
    targets = [(out, {**files, **core_only} if out == OUT_DIRS[0]
                else {k: v for k, v in files.items() if k not in core_only})  # the app only replays the OCR passes
               for out in OUT_DIRS]
    targets.append((MLKIT_DIR, render(MLKIT_PAGES)))  # Dart-only set: no reference output
    for out, wanted in targets:
        for name, text in wanted.items():
            f = out / name
            if check:
                if not f.is_file() or f.read_text(encoding="utf-8") != text:
                    stale.append(str(f.relative_to(REPO)))
            else:
                out.mkdir(parents=True, exist_ok=True)
                f.write_text(text, encoding="utf-8")
    if check:
        for s in stale:
            print(f"out of date: {s} (run python3 tools/synthetic/make_pages.py)", file=sys.stderr)
        return 1 if stale else 0
    print("wrote " + ", ".join(str(d.relative_to(REPO)) for d in [*OUT_DIRS, MLKIT_DIR])
          + " (ground truth for the core and ML Kit sets, reference output for the core set)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
