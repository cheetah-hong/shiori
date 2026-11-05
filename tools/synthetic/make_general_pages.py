#!/usr/bin/env python3
"""Synthetic pages for a layout-agnostic word extractor.

Every word, meaning, sentence and translation here is invented for the tests; no textbook content.

The extractor collects every Japanese word, sentence, kana and Korean line on a photo, pairs each
headword with its reading (kana) and Korean meaning by content (dictionary match, Sino-Korean
reading check) and position, and turns Japanese sentences into dictionary-form words. These pages
give it layouts to work on, written as the two OCR passes a device would return (`<page>.ja.json`,
`<page>.ko.json`, the same records as tools/synthetic/make_pages.py):

  g01 box        a short dialogue, then a word box: `□ 漢字(かな)` on the left, the meaning at x ≈ 0.50
  g02 sentence   a numbered pattern box, a Korean paragraph with Japanese words in it, sentences
                 with their translations on the right (one translation drops to the next line)
  g03 noreading  headwords and meanings only; no reading printed
  g04 warped     the list layout of make_pages.py on a curled page (row slope changing row by row)
                 with the next page's number column on the right
  g05 sidebar    a narrow side column of `漢字[かな] 뜻` lines beside sentences and translations
  g06 paragraph  g02's kind of page with a four-line Korean explanation paragraph: the Korean pass
                 reads its first two lines as one tall box and misses the other two, which the
                 Japanese pass reads as dictionary words at 0.5 and 0.3; a word printed inside it
                 (`学校[がっこう]`) is read by both passes; a small word box has a headword whose 口
                 the Japanese pass read as katakana ロ
  g10 vocablist  a word list with no number column: checkbox, headword, reading cell, a POS badge and the
                 meaning. The badges as OCR reads them (`니형`, `⅓형`, `몀.`, `동사`); a badge line the
                 Japanese pass reads as `8` + odd kanji at full confidence; a blank reading cell printed as
                 a flat dash (`一`, `ー`, `–`) beside kana headwords and a real `一` headword; a headword the
                 Japanese pass misread at 0.3 (a dictionary word with another reading) beside its kana and
                 meaning; a kana headword whose meaning has one kanji spelling in the glossary; `(お)` as an
                 optional prefix; a headword the Korean pass reads as one syllable over a 0.3 kanji; a
                 reading the Korean pass reads as `(다`; katakana ニ for 二; a headword read with a space
                 inside; box glyphs read as 問 and コロロ; a legend line and a footer with `|`; a row whose
                 meaning the Korean pass missed
  g11 examples   entries with an example box under each: furigana over the sentence's kanji, the sentence,
                 its translation on the line below; a meaning on two lines (a bracketed note, then the
                 meaning) beside the first furigana; a `[문형]` box heading

OCR noise: each pass reads the other language's lines as low-confidence garbage, checkbox glyphs
read as ロ 口 ■ □ (glued or spaced), marks over the print (a stray ✓ or ' by a meaning, a space
inside a reading), and the neighbouring page's text cut at the photo edge (x <= 0).

Trap pages for the pairing confidence (answers in ground_truth_traps.json, not in the score tables):
  g21 two words read alike (橋, 箸) on tight rows with furigana, g22 the same far apart,
  g23 two neighbours with the same printed Korean meaning (橋, 脚: 다리).

    python3 tools/synthetic/make_general_pages.py           # write packages/core/test/fixtures/synthetic_general/
    python3 tools/synthetic/make_general_pages.py --check   # exit 1 when the committed files are out of date

Files: the OCR passes, ground_truth.json (format "general-1": vocab printed as word pairs, content
words of the sentences in dictionary form, words not to be penalized), ground_truth_legacy.json
(g04 in make_pages.py's answer format, for the list parser), lexicon.json (dictionary facts for
every Japanese word used, values taken from JMdict) and korean_glosses.json (a small stand-in for a
Japanese-Korean gloss table, holding about half of the native-Korean-meaning words).
"""
from __future__ import annotations

import json
import re
import sys
from collections.abc import Callable
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_pages as mp  # noqa: E402

REPO = mp.REPO
OUT_DIR = REPO / "packages" / "core" / "test" / "fixtures" / "synthetic_general"
NOTE = ("Synthetic pages made by tools/synthetic/make_general_pages.py. Every word, meaning, sentence and "
        "translation is invented; no textbook content.")
GT_NOTE = (NOTE + " vocab: word pairs printed on the page (headword, printed or dictionary readings, printed "
           "meaning; readings [] for kana-only words, meaning null when none is printed; な-adjective "
           "headwords keep the printed だ). sentence_words: dictionary forms of the content words of the "
           "Japanese sentences (nouns, verbs, adjectives, adverbs; a する verb is given as its noun). "
           "ignore: things that may come out without penalty (headers, speaker names, the neighbouring "
           "page's cut text, function verbs).")
LEXICON_NOTE = ("Dictionary facts for every Japanese word on the pages of tools/synthetic/make_general_pages.py, "
                "taken from JMdict (EDRDG, CC BY-SA 4.0): id = ent_seq, pos = codes of all senses, pri = "
                "priority bitmask (news1 news2 ichi1 ichi2 spec1 spec2 gai1 gai2) and nf = nfXX band of the "
                "form used, uk = some sense is usually written in kana.")
GLOSS_NOTE = ("A small stand-in for a Japanese-Korean gloss table, made by tools/synthetic/make_general_pages.py: "
              "about half of the words whose Korean meaning does not follow the Sino-Korean reading, and the "
              "g10/g11 words a backward lookup (Korean meaning to kanji spelling) needs.")

TRAP_NOTE = (NOTE + " Pages that try to fool the pairing confidence (two words read alike on neighbouring "
             "rows, the same pair far apart, two neighbours with the same Korean meaning); answers as in "
             "ground_truth.json.")

W_SIDE = 0.0105  # per-character width of the side column's small type

LATIN = "ABCDEFGHJKLMNOPRSTUVWXYZabcdeghiklmnorstuxyz0123456789"
JUNK_KANJI = "己乙卜弖丫冂彐叉弓勹匚"
HANGUL = "가나다라마바사아자차카타파하오우이"


class GPage(mp.Page):
    """Both OCR passes of one page plus its general answer sheet."""

    def __init__(self, fixture: str, kind: str, seed: int):
        super().__init__(fixture, 0, kind, 0, "", seed)
        self.kind = kind
        self.vocab: list[dict] = []
        self.sentence_words: list[str] = []
        self.ignore: list[str] = []

    # -- confidences and garbage
    def sure(self) -> float:
        """Confidence of a line read by the right pass."""
        return self.rng.choice((1.0, 1.0, 0.5))

    def junk_latin(self) -> str:
        return "".join(self.rng.choice(LATIN) for _ in range(self.rng.randint(2, 6)))

    def ko_junk(self) -> tuple[str, float]:
        """The Korean pass on a Japanese line: Latin and digits, now and then a Hangul syllable or two."""
        if self.rng.random() < 0.2:
            t = "".join(self.rng.choice(HANGUL) for _ in range(self.rng.randint(1, 2)))
        else:
            t = self.junk_latin()
        return t, self.rng.choice((0.3, 0.5))

    def ja_junk(self) -> str:
        """The Japanese pass on a Korean line: a few odd kanji, or Latin and digits."""
        if self.rng.random() < 0.5:
            return "".join(self.rng.choice(JUNK_KANJI) for _ in range(self.rng.randint(1, 3)))
        return self.junk_latin()

    # -- lines
    def ja_line(self, t: str, x: float, y: float, *, per: float = mp.W_SENT, h: float = 0.0190,
                c: float | None = None, ko: str | None = None) -> None:
        """A Japanese line: the Japanese pass reads t, the Korean pass reads garbage (or `ko`)."""
        ko_t, ko_c = (ko, 0.3) if ko is not None else self.ko_junk()
        self.both(t, ko_t, x, y, mp.text_width(t, per), h, self.sure() if c is None else c, ko_c)

    def ko_line(self, t: str, x: float, y: float, *, per: float = mp.W_KO, h: float = 0.0135,
                c: float | None = None, ja: str | None = None, ja_rate: float = 0.7) -> None:
        """A Korean line: the Korean pass reads t, the Japanese pass mostly reads garbage (or `ja`)."""
        if ja is None and self.rng.random() < ja_rate:
            ja = self.ja_junk()
        self.both(ja, t, x, y, mp.text_width(t, per), h, 0.3, self.sure() if c is None else c)

    def edge(self, lines: list[tuple[str, float]]) -> None:
        """The neighbouring page's text, cut at the photo edge (x <= 0)."""
        for t, y in lines:
            self.ja_line(t, -0.0045 + self.jitter(0.003), y, c=0.5)

    # -- answers
    def word(self, headword: str, readings: list[str], meaning: str | None) -> None:
        self.vocab.append({"headword": headword, "readings": readings, "meaning": meaning})

    def sentence(self, words: list[str]) -> None:
        self.sentence_words += [w for w in words if w not in self.sentence_words]

    def general_answer(self) -> dict:
        return {"page": self.fixture, "fixture": self.fixture, "kind": self.kind, "vocab": self.vocab,
                "sentence_words": self.sentence_words, "ignore": self.ignore}


# ---------------------------------------------------------------- g01: dialogue and a word box

G01_ROWS = [
    # glyph: how the Japanese pass reads the checkbox ("ロ" glued, "口 " spaced, "■" its own box,
    # None not read); head_ocr / ko_ocr: misreadings of the word or the meaning line
    dict(head="料理（りょうり）", glyph="ロ", meaning=["요리"], truth=("料理", ["りょうり"])),
    # a mark over the print: a space inside the reading
    dict(head="旅行(りょこう)", glyph="口 ", head_ocr="旅行(りょ こう)", meaning=["여행"], truth=("旅行", ["りょこう"])),
    # a check mark next to the meaning
    dict(head="地図（ちず）", glyph="■", meaning=["지도"], ko_ocr="지도 ✓", truth=("地図", ["ちず"])),
    dict(head="両親(りょうしん)", glyph="□ ", meaning=["양친, 부모"], truth=("両親", ["りょうしん"])),
    # an accent stroke read as an apostrophe in front of the meaning
    dict(head="利用（りよう）", glyph=None, meaning=["이용"], ko_ocr="'이용", truth=("利用", ["りよう"])),
    # a note in brackets in front of the meaning; the Japanese pass picks out the する inside it
    dict(head="予約(よやく)", glyph="ロ", meaning=["(뒤에 する가 붙어) 예약하다"], ja_meaning="（己 する乙",
         truth=("予約", ["よやく"])),
    dict(head="走る（はしる）", glyph="口 ", meaning=["달리다"], truth=("走る", ["はしる"])),
    # the meaning runs on to a second line (same x, no headword on its left)
    dict(head="選ぶ(えらぶ)", glyph="ロ", meaning=["고르다, 여럿 가운데서", "가려 뽑다"], truth=("選ぶ", ["えらぶ"])),
    dict(head="景色（けしき）", glyph="■", meaning=["경치, 눈에 보이는 산과", "들의 모습"], truth=("景色", ["けしき"])),
    # a `*katakana word: meaning` note after the meaning
    dict(head="入場券(にゅうじょうけん)", glyph="□ ", meaning=["입장권 *チケット: 티켓"], supplement="*チケット:",
         truth=("入場券", ["にゅうじょうけん"]), truth_meaning="입장권"),
    dict(head="ゆっくり", glyph="ロ", meaning=["천천히"], truth=("ゆっくり", [])),
    dict(head="すっかり", glyph="口 ", meaning=["완전히, 남김없이"], truth=("すっかり", [])),
    dict(head="カメラ", glyph=None, meaning=["카메라"], truth=("カメラ", [])),
    dict(head="ノート", glyph="ロ", meaning=["노트, 공책"], truth=("ノート", [])),
]


def g01_row(p: GPage, r: dict, y: float) -> float:
    """One word of the box; returns the y of the next row."""
    x = 0.18 + p.jitter(0.002)
    head = r.get("head_ocr", r["head"])
    glyph = r["glyph"]
    if glyph == "■":
        p.both("■", None, x, y + 0.002, 0.0150, 0.0150, 0.3)
        p.ja_line(head, x + 0.025, y, per=mp.W_READ)
    elif glyph is None:
        p.ja_line(head, x + 0.025, y, per=mp.W_READ)
    else:
        p.ja_line(glyph + head, x, y, per=mp.W_READ, c=0.5)
    for k, t in enumerate(r["meaning"]):
        mx, my = 0.50 + p.jitter(0.002), y + 0.003 + 0.026 * k
        p.ko_line(r.get("ko_ocr", t) if k == 0 else t, mx, my, ja=r.get("ja_meaning") if k == 0 else None)
        if k == 0 and "supplement" in r:
            sx = mx + mp.text_width("입장권 ", mp.W_KO)
            p.both(r["supplement"], None, sx, my, mp.text_width(r["supplement"], mp.W_READ), 0.0135, 1.0)
    headword, readings = r["truth"]
    p.word(headword, readings, r.get("truth_meaning", " ".join(r["meaning"])))
    return y + 0.040 + 0.026 * (len(r["meaning"]) - 1)


def page_g01() -> GPage:
    """A short dialogue, then a box of words with their meanings on the right."""
    p = GPage("g01", "box", seed=101)
    p.ja_line("第7課 週末の予定", 0.16, 0.045, per=mp.W_HEAD, h=0.024)
    p.edge([("紙を出しました。", 0.118), ("は早く休みました", 0.640)])
    p.ja_line("ユナ：日曜日に公園を散歩しましょう。", 0.16, 0.100)
    p.sentence(["日曜日", "公園", "散歩"])
    p.ja_line("ケン", 0.16, 0.140, per=mp.W_SENT)
    p.ja_line("朝、弁当を作ります。", 0.23, 0.140)
    p.sentence(["朝", "弁当", "作る"])
    p.ja_line("ユナ：駅の前で待っています。", 0.16, 0.180)
    p.sentence(["駅", "前", "待つ"])
    p.ko_line("단어", 0.16, 0.235, h=0.018, c=1.0)
    y = 0.285
    for r in G01_ROWS:
        y = g01_row(p, r, y)
    p.both("38", "38", 0.88, 0.955, 0.025, 0.012, 1.0, 1.0)
    p.ignore = ["第7課", "第", "課", "週末", "予定", "ユナ", "ケン", "단어", "ロ", "口", "■", "□", "38",
                "する", "散歩する", "いる", "チケット", "티켓", "紙", "手紙", "出す", "早い", "休む"]
    return p


# ---------------------------------------------------------------- g02: a pattern and sentences

G02_SENTENCES = [
    # (Japanese, Korean, content words, translation on the next line)
    ("妹は毎晩ピアノを練習します。", "여동생은 매일 밤 피아노를 연습합니다.", ["妹", "毎晩", "ピアノ", "練習"], False),
    ("昨日、デパートで新しい靴を買った。", "어제 백화점에서 새 구두를 샀다.",
     ["昨日", "デパート", "新しい", "靴", "買う"], True),
    ("起きてから、顔を洗いました。", "일어나고 나서 얼굴을 씻었습니다.", ["起きる", "顔", "洗う"], False),
    ("このスープは辛くないです。", "이 수프는 맵지 않습니다.", ["スープ", "辛い"], False),
    ("弟は牛乳を飲まない。", "남동생은 우유를 마시지 않는다.", ["弟", "牛乳", "飲む"], False),
    ("これは有名な絵です。", "이것은 유명한 그림입니다.", ["有名", "絵"], False),
]


def page_g02() -> GPage:
    """A numbered pattern box, a Korean paragraph, sentences with translations on the right."""
    p = GPage("g02", "sentence", seed=102)
    p.ko_line("문장 연습", 0.16, 0.050, h=0.020)
    p.both("1", "1", 0.16, 0.100, 0.012, 0.018, 1.0, 1.0)
    p.ja_line("〜は〜です。", 0.20, 0.100, per=mp.W_HEAD, h=0.022)
    p.ko_line("~은(는) ~입니다.", 0.56, 0.104, h=0.016)
    # the Japanese pass skips the paragraph; the Korean pass reads its Japanese words as Latin
    p.both(None, "명사 뒤에 Lt를 붙이고 문장 끝에 C9를 쓰면 정중하게 설명하는 말이 됩니다.",
           0.16, 0.160, 0.43, 0.0135, c_ko=1.0)
    p.both(None, "예를 들어 「htcLlt」, 「E省C9」처럼 이름이나 직업을 말할 때 씁니다.",
           0.16, 0.190, 0.40, 0.0135, c_ko=0.5)
    p.edge([("ちの猫は寝ています", 0.330), ("で帰りました。", 0.710)])
    y = 0.250
    for k, (ja, ko, words, drops) in enumerate(G02_SENTENCES):
        p.both(str(k + 1), str(k + 1), 0.135, y + 0.003, 0.010, 0.014, 1.0, 1.0)
        p.ja_line(ja, 0.16, y)
        ty = y + 0.034 if drops else y + 0.004
        p.ko_line(ko, 0.56, ty)
        p.sentence(words)
        y += 0.090 if drops else 0.065
    p.both("52", "52", 0.88, 0.955, 0.025, 0.012, 1.0, 1.0)
    p.ignore = ["〜", "문장 연습", "52", "わたし", "医者", "する", "練習する", "この", "これ",
                "猫", "寝る", "いる", "帰る"]
    return p


# ---------------------------------------------------------------- g03: words without readings

G03_ROWS = [
    # (headword, dictionary reading or None for kana words, meaning)
    ("季節", "きせつ", "계절"),
    ("台風", "たいふう", "태풍"),
    ("冷蔵庫", "れいぞうこ", "냉장고"),
    ("洗濯", "せんたく", "세탁, 빨래"),
    ("忘れる", "わすれる", "잊다, 잊어버리다"),
    ("届く", "とどく", "닿다, 도착하다"),
    ("暖かい", "あたたかい", "따뜻하다"),
    ("きれい", None, "예쁘다, 깨끗하다"),
    ("タオル", None, "수건, 타월"),
    ("歴史", "れきし", "역사"),
]


def page_g03() -> GPage:
    """Numbered headwords and their meanings; no reading is printed."""
    p = GPage("g03", "noreading", seed=103)
    p.ko_line("확인 단어", 0.16, 0.060, h=0.020)
    p.edge([("話をかけて", 0.400), ("ました。", 0.800)])
    for i, (head, reading, meaning) in enumerate(G03_ROWS):
        y = 0.140 + 0.062 * i + p.jitter(0.002)
        no = str(i + 1)
        if i == 2:  # the Japanese pass glues the number to the headword
            p.ja_line(f"{no} {head}", 0.16, y, per=mp.W_HEAD, h=0.022)
            p.both(None, no, 0.16, y + 0.003, 0.012, 0.016, c_ko=1.0)
        else:
            p.both(no, no, 0.16, y + 0.003, 0.012 * len(no), 0.016, 1.0, 1.0)
            p.ja_line(head, 0.22, y, per=mp.W_HEAD, h=0.022)
        p.ko_line(meaning, 0.50 + p.jitter(0.002), y + 0.004)
        p.word(head, [reading] if reading else [], meaning)
    p.both("73", "73", 0.88, 0.955, 0.025, 0.012, 1.0, 1.0)
    p.ignore = ["확인 단어", "73", "電話", "話", "かける"]
    return p


# ---------------------------------------------------------------- g04: a curled list page

G04_ROWS = [
    dict(no="0141", headword="店", readings=["みせ"], pos="명", meaning="가게"),
    dict(no="0142", headword="財布", readings=["さいふ"], pos="명", meaning="지갑", box="■口口"),
    dict(no="0143", headword="品物", readings=["しなもの"], pos="명", meaning="물건, 상품"),
    dict(no="0144", headword="売店", readings=["ばいてん"], pos="명", meaning="매점"),
    dict(no="0145", headword="傘", readings=["かさ"], pos="명", meaning="우산", box="ロロレ"),
    dict(no="0146", headword="帽子", readings=["ぼうし"], pos="명", meaning="모자"),
    dict(no="0147", headword="お釣り", readings=["おつり"], pos="명", meaning="거스름돈"),
    dict(no="0148", headword="袋", readings=["ふくろ"], pos="명", meaning="봉투, 자루"),
    dict(no="0149", headword="並ぶ", readings=["ならぶ"], pos="동", meaning="줄을 서다, 늘어서다"),
    dict(no="0150", headword="払う", readings=["はらう"], pos="동", meaning="지불하다, 치르다", box="■ロロ"),
    # badge い형 read as 니형
    dict(no="0151", headword="安い", readings=["やすい"], pos="い형", meaning="싸다", meaning_ocr=[("니형 싸다", 0.0)]),
    # badge on its own line
    dict(no="0152", headword="丈夫だ", readings=["じょうぶだ"], pos="な형", meaning="튼튼하다",
         meaning_ocr=[("な형", 0.0), ("튼튼하다", 0.0213)]),
    dict(no="0153", headword="便利だ", readings=["べんりだ"], pos="な형", meaning="편리하다"),
    # kana word: the reading column shows a dash
    dict(no="0154", headword="レジ", readings=[], pos="명", meaning="계산대", reading_ocr="–"),
    dict(no="0155", headword="混む", readings=["こむ"], pos="동", meaning="붐비다, 혼잡하다"),
]
# row slope on the first and last row (the page curls), then the list layout's geometry
CURL_TOP, CURL_BOTTOM = -0.066, 0.114
CURL_GEOMETRY = dict(ax0=0.2112, ay0=0.2459, gap=0.0458, drift=0.0012, reading_x=0.4302)


def page_g04() -> GPage:
    """DAY 05 list page held by hand: the row slope changes row by row; the next page's numbers."""
    p = GPage("g04", "warped", seed=104)
    p.page, p.template, p.day, p.title = 4, "list", 5, "가게, 물건"
    p.both("DAY", "DAY", 0.2461, 0.1148, 0.0640, 0.0248)
    p.both("05", "05", 0.2422, 0.1453, 0.0736, 0.0494)
    p.both(None, "가게, 물건", 0.3720, 0.1291, 0.1508, 0.0412, c_ko=0.5)
    p.edge([("の橋を渡り", 0.520)])
    n = len(G04_ROWS)
    for i, r in enumerate(G04_ROWS):
        slope = CURL_TOP + (CURL_BOTTOM - CURL_TOP) * i / (n - 1)
        junk = {}
        if i % 2 == 0:
            junk["ko_head"] = p.ko_junk()[0]
        if i % 3 == 1:
            junk["ko_reading"] = p.ko_junk()[0]
        mp.list_row(p, i, {**r, **junk}, slope=slope, **CURL_GEOMETRY)
        p.word(r["headword"], r["readings"], r["meaning"])
    for k in range(10):
        x, y = 0.9605 - 0.0011 * k, 0.2077 + 0.0560 * k
        p.both(f"{156 + k:04d}", f"{156 + k:04d}", x, y, 0.0213, 0.0073)
        p.both("ロロロ", None, x, y + 0.0102, 0.0368, 0.0088, 0.3, 0.5)
    p.ignore = ["DAY", "05", "가게, 물건", "ロロロ", "橋", "渡る"]
    return p


# ---------------------------------------------------------------- g05: a side column of words

G05_SIDE = [
    # (Japanese part, Korean part or None when the meaning drops to the next line, headword, reading)
    ("祖父[そふ]", "할아버지", "祖父", "そふ"),
    ("畑［はたけ］", "밭", "畑", "はたけ"),
    ("野菜【やさい】", "채소, 야채", "野菜", "やさい"),
    ("育てる[そだてる]", "기르다, 키우다", "育てる", "そだてる"),
    ("叔父［おじ］", None, "叔父", "おじ"),
    ("収穫【しゅうかく】", "수확", "収穫", "しゅうかく"),
    ("手伝う[てつだう]", "돕다", "手伝う", "てつだう"),
]
G05_DROPPED = "삼촌(부모의 남자 형제)"
G05_SENTENCES = [
    ("祖父は畑で野菜を育てています。", "할아버지는 밭에서 채소를 기르고 있습니다.", ["祖父", "畑", "野菜", "育てる"]),
    ("秋になると、叔父が収穫を手伝ってくれます。", "가을이 되면 삼촌이 수확을 도와줍니다.", ["秋", "叔父", "収穫", "手伝う"]),
    ("畑のトマトは甘くて、おいしかった。", "밭의 토마토는 달고 맛있었다.", ["畑", "トマト", "甘い", "おいしい"]),
]


def page_g05() -> GPage:
    """Words with inline readings in a narrow left column; sentences and translations on the right."""
    p = GPage("g05", "sidebar", seed=105)
    p.ko_line("단어", 0.07, 0.160, h=0.014, c=1.0)
    y = 0.200
    for ja, ko, head, reading in G05_SIDE:
        sy = y + p.jitter(0.0015)
        if ko is None:  # the meaning drops to the next line
            p.ja_line(ja, 0.07, sy, per=W_SIDE, h=0.0125)
            y += 0.045
            p.ko_line(G05_DROPPED, 0.07, y, per=W_SIDE, h=0.0125)
            meaning = G05_DROPPED
        else:  # one box: each pass reads its own language and garbles the other
            t = f"{ja} {ko}"
            p.both(f"{ja} {p.ja_junk()}", f"{p.junk_latin()} {ko}", 0.07, sy, mp.text_width(t, W_SIDE), 0.0125,
                   0.5, 0.5)
            meaning = ko
        p.word(head, [reading], meaning)
        y += 0.045
    p.edge([("スに乗って", 0.620), ("て、昼寝をし", 0.700)])
    p.ko_line("읽어 봅시다", 0.30, 0.080, h=0.020)
    y = 0.200
    for ja, ko, words in G05_SENTENCES:
        p.ja_line(ja, 0.30, y)
        p.ko_line(ko, 0.30, y + 0.034)
        p.sentence(words)
        y += 0.100
    p.both("17", "17", 0.88, 0.955, 0.025, 0.012, 1.0, 1.0)
    p.ignore = ["단어", "읽어 봅시다", "17", "いる", "なる", "くれる", "乗る", "昼寝", "する"]
    return p


# ---------------------------------------------------------------- g06: a Korean paragraph read as Japanese

G06_SENTENCES = [
    ("兄は夜に紅茶を飲みます。", "형은 밤에 홍차를 마십니다.", ["兄", "夜", "紅茶", "飲む"]),
    ("この部屋は静かです。", "이 방은 조용합니다.", ["部屋", "静か"]),
]


def page_g06() -> GPage:
    """A pattern, a Korean paragraph the Japanese pass reads as words, a word box, sentences."""
    p = GPage("g06", "paragraph", seed=106)
    p.ko_line("문형 정리", 0.16, 0.050, h=0.020)
    p.both("1", "1", 0.16, 0.100, 0.012, 0.018, 1.0, 1.0)
    # a pattern, not a sentence: its words are placeholders
    p.ja_line("〜が好きです。", 0.20, 0.100, per=mp.W_HEAD, h=0.022, c=0.5)
    p.ko_line("~을(를) 좋아합니다.", 0.56, 0.104, h=0.016)
    # the paragraph: the Korean pass reads its first two lines as one tall box
    para = ("좋아하는 것을 말할 때는 예를 들어 学校[がっこう]처럼 조사 が를 씁니다. "
            "이때 が 앞에는 좋아하는 대상이 옵니다.")
    p.both(None, para, 0.16, 0.150, 0.43, 0.0135 * 2 + 0.006, c_ko=1.0)
    # the word printed inside the first line: the Japanese pass reads it at full confidence
    p.both("学校[がっこう]", None, 0.16 + 19 * mp.W_KO, 0.150, 9 * mp.W_KO, 0.0135, c_ja=1.0)
    # the third line, missed by the Korean pass, read as dictionary words at the middle confidence
    p.both("上手な木に気", None, 0.18, 0.1875, 6 * mp.W_KO, 0.0135, c_ja=0.5)
    # the fourth line at the engine's lowest confidence
    p.both("木気の上手", None, 0.22, 0.2125, 5 * mp.W_KO, 0.0135, c_ja=0.3)
    p.word("学校", ["がっこう"], None)
    # a word box: the headword's 口 read as katakana ロ
    p.ko_line("단어", 0.16, 0.260, h=0.018)
    p.ja_line("人ロ", 0.16, 0.300, per=mp.W_HEAD, h=0.022, c=1.0)
    p.ko_line("인구", 0.50, 0.304, c=1.0)
    p.word("人口", ["じんこう"], "인구")
    p.ja_line("図書館", 0.16, 0.345, per=mp.W_HEAD, h=0.022, c=1.0)
    p.ko_line("도서관", 0.50, 0.349, c=1.0)
    p.word("図書館", ["としょかん"], "도서관")
    y = 0.420
    for k, (ja, ko, words) in enumerate(G06_SENTENCES):
        p.both(str(k + 1), str(k + 1), 0.135, y + 0.003, 0.010, 0.014, 1.0, 1.0)
        p.ja_line(ja, 0.16, y, c=1.0)
        p.ko_line(ko, 0.56, y + 0.004, c=1.0)
        p.sentence(words)
        y += 0.065
    p.both("61", "61", 0.88, 0.955, 0.025, 0.012, 1.0, 1.0)
    p.ignore = ["〜", "문형 정리", "단어", "61", "この"]
    return p


# ---------------------------------------------------------------- g10: a word list without numbers

# Columns of g10: checkbox, headword, reading cell, badge and meaning.
G10_BOX_X, G10_HEAD_X, G10_READ_X, G10_MEAN_X = 0.150, 0.200, 0.420, 0.600
G10_ROW_H, G10_FLAT_H = 0.0190, 0.0060

G10_ROWS = [
    # head: what the Japanese pass reads in the headword cell (ko_head: the Korean pass there);
    # read: the reading cell (None: a blank cell, flat: its dash as read); meaning: the Korean pass's
    # line (ja_meaning: the Japanese pass on it); truth: (headword, readings, meaning)
    # a headword misread at the lowest confidence as another dictionary word (竹 is たけ, not はこ)
    dict(head="竹", head_c=0.3, box="ロロロ", read="はこ", meaning="명 상자", truth=("箱", ["はこ"], "상자")),
    # kana headwords, blank reading cells printed as a flat dash; 많이 has one kanji spelling (沢山)
    dict(head="たくさん", box="■口口", flat=("ー", 0.3, "-"), meaning="부 많이", truth=("たくさん", [], "많이")),
    dict(head="やっと", box="ロロロ", flat=("一", 0.5, None), meaning="부 겨우, 간신히", truth=("やっと", [], "겨우, 간신히")),
    dict(head="きっと", box="■口口", flat=("–", 0.5, "–"), meaning="부 꼭, 분명히", truth=("きっと", [], "꼭, 분명히")),
    # a real 一, as tall as the other headwords
    dict(head="一", box="ロロロ", read="いち", meaning="명 하나, 일", truth=("一", ["いち"], "하나, 일")),
    # an optional honorific prefix in brackets, with a blank reading cell
    dict(head="（お）みやげ", box="■口口", flat=("ー", 0.5, None), meaning="명 선물, 기념품",
         truth=("(お)みやげ", [], "선물, 기념품")),
    # badges as OCR reads them
    dict(head="細い", box="ロロロ", read="ほそい", meaning="니형 가늘다", truth=("細い", ["ほそい"], "가늘다")),
    dict(head="親切だ", box="■口口", read="しんせつだ", meaning="⅓형 친절하다", truth=("親切だ", ["しんせつだ"], "친절하다")),
    dict(head="開ける", box="ロロロ", read="あける", meaning="동사 열다", truth=("開ける", ["あける"], "열다")),
    dict(head="机", box="■口口", read="つくえ", meaning="몀. 책상", truth=("机", ["つくえ"], "책상")),
    # the Japanese pass reads the badge line as 8 and odd kanji, at full confidence
    dict(head="窓", box="ロロロ", read="まど", meaning="명 창문", ja_meaning=("8叉", 1.0), truth=("窓", ["まど"], "창문")),
    # the Korean pass reads one syllable over the headword, which the Japanese pass read at 0.3
    dict(head="庭", head_c=0.3, ko_head=("트", 0.5), box="■口口", read="にわ", meaning="명 마당, 뜰",
         truth=("庭", ["にわ"], "마당, 뜰")),
    # the Korean pass reads the reading cell as `(다`, over the Japanese pass's 0.3
    dict(head="鏡", box="ロロロ", read="かがみ", read_c=0.3, ko_read=("(다", 0.5), meaning="명 거울",
         truth=("鏡", ["かがみ"], "거울")),
    # katakana ニ read for the kanji 二
    dict(head="ニつ", box="■口口", read="ふたつ", meaning="명 두 개, 둘", truth=("二つ", ["ふたつ"], "두 개, 둘")),
    # a headword read with a space inside
    dict(head="交通 事故", box="ロロロ", read="こうつうじこ", meaning="명 교통사고", truth=("交通事故", ["こうつうじこ"], "교통사고")),
    # the checkbox read as 問, glued to the headword with a space
    dict(head="問 傘", head_x=G10_BOX_X, box=None, read="かさ", meaning="명 우산", truth=("傘", ["かさ"], "우산")),
    # the checkbox read as コロロ on its own
    dict(head="閉める", box="コロロ", read="しめる", meaning="동 닫다", truth=("閉める", ["しめる"], "닫다")),
    # the Korean pass missed the meaning line; the footer is below
    dict(head="整理", box="■口口", read="せいり", meaning=None, truth=("整理", ["せいり"], None)),
]


def g10_row(p: GPage, r: dict, y: float) -> None:
    """One row of the word list."""
    if r["box"] is not None:
        p.both(r["box"], None, G10_BOX_X, y + 0.010, 0.036, 0.009, 0.3)
    head = r["head"]
    ko_head = r.get("ko_head")
    p.both(head, ko_head[0] if ko_head else p.junk_latin(), r.get("head_x", G10_HEAD_X), y,
           mp.text_width(head, mp.W_HEAD), G10_ROW_H, r.get("head_c", 0.5),
           ko_head[1] if ko_head else 0.3)
    if "flat" in r:
        ja_dash, c, ko_dash = r["flat"]
        p.both(ja_dash, ko_dash, G10_READ_X, y + 0.008, 0.014, G10_FLAT_H, c, 0.5)
    else:
        ko_read = r.get("ko_read")
        p.both(r["read"], ko_read[0] if ko_read else p.junk_latin(), G10_READ_X, y,
               mp.text_width(r["read"], mp.W_READ), 0.0160, r.get("read_c", 0.5),
               ko_read[1] if ko_read else 0.3)
    if r["meaning"] is not None:
        ja_meaning = r.get("ja_meaning")
        p.both(ja_meaning[0] if ja_meaning else None, r["meaning"], G10_MEAN_X, y + 0.002,
               mp.text_width(r["meaning"], mp.W_KO), 0.0135, ja_meaning[1] if ja_meaning else 0.3, 0.5)
    headword, readings, meaning = r["truth"]
    p.word(headword, readings, meaning)


def page_g10() -> GPage:
    """A word list with no number column: checkbox, headword, reading cell, badge and meaning."""
    p = GPage("g10", "vocablist", seed=110)
    p.ko_line("* 표시 = 시험에 자주 나오는 단어", 0.55, 0.060, h=0.012, c=0.5)
    p.ko_line("생활 용품", 0.20, 0.060, h=0.022, c=1.0)
    for i, r in enumerate(G10_ROWS):
        g10_row(p, r, 0.100 + 0.046 * i + p.jitter(0.001))
    p.ko_line("단어 | 3과 생활 용품", 0.62, 0.940, h=0.012, c=1.0)
    p.ignore = ["생활 용품", "ロロロ", "■", "口口", "コロロ", "問", "竹", "交通", "事故"]
    return p


# ---------------------------------------------------------------- g11: entries with example boxes

G11_ENTRIES = [
    # (headword, reading, meaning lines as the Korean pass reads them, furigana (text, characters before it),
    #  sentence, translation, truth meaning, words of the sentence)
    ("届ける", "とどける", ["동 보내다, 배달하다"], [("にもつ", 0), ("ともだち", 3)],
     "荷物を友達の家に届けました。", "짐을 친구 집에 보냈습니다.", "보내다, 배달하다", ["荷物", "友達", "家", "届ける"]),
    ("片付ける", "かたづける", ["동 (물건을 제자리에)", "정리하다, 치우다"], [("へや", 0)],
     "部屋を片付けてから出かけます。", "방을 정리하고 나서 외출합니다.", "(물건을 제자리에) 정리하다, 치우다",
     ["部屋", "片付ける", "出かける"]),
    ("準備", "じゅんび", ["명 준비"], [("りょこう", 0), ("じゅんび", 3)],
     "旅行の準備をしました。", "여행 준비를 했습니다.", "준비", ["旅行", "準備"]),
]


def g11_entry(p: GPage, e: tuple, y: float) -> float:
    """One entry and its example box; returns the y of the next entry."""
    head, reading, meanings, furigana, ja, ko, truth_meaning, words = e
    p.ja_line(head, 0.16, y, per=mp.W_HEAD, h=0.022, c=1.0)
    p.ja_line(reading, 0.36, y + 0.003, per=mp.W_READ, h=0.016, c=0.5)
    for k, t in enumerate(meanings):
        p.ko_line(t, 0.58, y + 0.004 + 0.026 * k, c=0.5)
    sy = y + 0.060
    for text, before in furigana:
        p.both(text, None, 0.18 + before * mp.W_SENT, sy - 0.012, mp.text_width(text, mp.W_FURI) * 0.9, 0.0100,
               c_ja=0.5)
    p.ja_line(ja, 0.18, sy, c=1.0)
    p.ko_line(ko, 0.18, sy + 0.030, c=1.0)
    p.word(head, [reading], truth_meaning)
    p.sentence(words)
    return sy + 0.090


def page_g11() -> GPage:
    """Entries, each with an example box: furigana, the sentence, its translation below."""
    p = GPage("g11", "examples", seed=111)
    p.ko_line("주제별 단어 | 생활", 0.55, 0.040, h=0.012, c=1.0)
    y = 0.090
    for k, e in enumerate(G11_ENTRIES):
        y = g11_entry(p, e, y)
        if k == 0:
            # a box heading under the first example, read by the Korean pass
            p.ko_line("[문형] 동사 て형 + から ~하고 나서", 0.18, y - 0.040, c=0.5, ja_rate=0.0)
    p.both("88", "88", 0.88, 0.955, 0.025, 0.012, 1.0, 1.0)
    p.ignore = ["主題", "88", "する", "て", "から", "準備する", "ある"]
    return p


PageBuilder = Callable[[], GPage]
PAGES: tuple[PageBuilder, ...] = (page_g01, page_g02, page_g03, page_g04, page_g05, page_g06,
                                   page_g10, page_g11)


# ---------------------------------------------------------------- g21-g23: traps for the pairing confidence
# Pages built to fool a confidence rule, not to be read well: their answers go to ground_truth_traps.json
# (kept out of ground_truth.json so the score tables above stay as they are). Their dictionary facts
# (橋 is in LEXICON; 箸, 脚 are not) live in the core tests' support data, taken from JMdict.


def trap_row(p: GPage, head: str, reading: str, meaning: str, y: float, *, furigana: bool) -> None:
    """A headword, its reading (furigana above it, or to its right on the row), its meaning further right."""
    x = 0.20
    if furigana:
        p.ja_line(reading, x + 0.002, y - 0.0145, per=mp.W_FURI, h=0.0120, c=1.0)
    else:
        p.ja_line(reading, x + 0.07, y + 0.002, per=mp.W_READ, h=0.0185, c=1.0)
    p.ja_line(head, x, y, per=mp.W_HEAD, h=0.0220, c=1.0)
    p.ko_line(meaning, 0.45, y + 0.004, c=1.0)
    p.word(head, [reading], meaning)


def page_g21() -> GPage:
    """Two words read alike (橋, 箸) on tight rows with furigana: the lower one's furigana sits right
    below the upper headword, so each reading would fit both headwords."""
    p = GPage("g21", "trap-homophones-near", seed=121)
    p.ko_line("단어", 0.20, 0.120, h=0.018, c=1.0)
    trap_row(p, "橋", "はし", "다리", 0.200, furigana=True)
    trap_row(p, "箸", "はし", "젓가락", 0.240, furigana=True)
    return p


def page_g22() -> GPage:
    """The same two words far apart: each reading fits only its own headword's place."""
    p = GPage("g22", "trap-homophones-far", seed=122)
    p.ko_line("단어", 0.20, 0.120, h=0.018, c=1.0)
    trap_row(p, "橋", "はし", "다리", 0.200, furigana=True)
    trap_row(p, "箸", "はし", "젓가락", 0.600, furigana=True)
    return p


def page_g23() -> GPage:
    """Two neighbouring words with the same printed Korean meaning (橋, 脚: 다리)."""
    p = GPage("g23", "trap-same-meaning", seed=123)
    p.ko_line("단어", 0.20, 0.120, h=0.018, c=1.0)
    trap_row(p, "橋", "はし", "다리", 0.200, furigana=False)
    trap_row(p, "脚", "あし", "다리", 0.235, furigana=False)
    return p


TRAP_PAGES: tuple[PageBuilder, ...] = (page_g21, page_g22, page_g23)


# ---------------------------------------------------------------- dictionary facts (JMdict)

# (ent_seq, kanji forms used, readings, pos codes, pri, nf, uk); pri and nf are those of the first
# kanji form, or of the first reading for a word written in kana.
LEXICON: tuple[tuple[int, list[str], list[str], str, int, int | None, bool], ...] = (
    # particles and the copula
    (2029010, [], ["を"], "prt", 16, None, False),
    (2028990, [], ["に"], "prt conj", 16, None, False),
    (2028930, [], ["が"], "prt conj", 16, None, False),
    (2028920, [], ["は"], "prt", 16, None, False),
    (2028980, [], ["で"], "prt conj", 16, None, False),
    (1008490, [], ["と"], "prt conj", 16, None, False),
    (2028940, [], ["も"], "prt adv", 16, None, False),
    (1469800, [], ["の"], "prt", 16, None, False),
    (2029000, [], ["へ"], "prt", 16, None, False),
    (1002980, [], ["から"], "prt conj", 16, None, False),
    (1525680, [], ["まで"], "prt", 18, 46, True),
    (1628500, [], ["です"], "cop aux-v", 16, None, False),
    (2089020, [], ["だ"], "aux-v cop", 16, None, False),
    # function verbs
    (1577980, ["居る"], ["いる"], "v1 vi aux-v", 4, None, True),
    (1157170, ["為る"], ["する"], "vs-i vi vt suf aux-v", 4, None, True),
    (1375610, ["成る"], ["なる"], "v5r vi aux-v", 6, 34, True),
    (1269130, ["呉れる"], ["くれる"], "v1-s vt aux-v", 4, None, True),
    # g01
    (1554310, ["料理"], ["りょうり"], "n vs vt", 5, 2, False),
    (1553170, ["旅行"], ["りょこう"], "n vs vi", 5, 2, False),
    (1421290, ["地図"], ["ちず"], "n", 5, 5, False),
    (1602710, ["両親"], ["りょうしん"], "n", 5, 3, False),
    (1549660, ["利用"], ["りよう"], "n vs vt", 5, 2, False),
    (1543750, ["予約"], ["よやく"], "n vs vt", 5, 6, False),
    (1402540, ["走る"], ["はしる"], "v5r vi", 5, 10, False),
    (1588730, ["選ぶ"], ["えらぶ"], "v5b vt", 5, 2, False),
    (1250870, ["景色"], ["けしき"], "n", 5, 14, False),
    (1466380, ["入場券"], ["にゅうじょうけん"], "n", 5, 13, False),
    (1013050, [], ["ゆっくり"], "adv adv-to vs", 4, None, False),
    (1006110, [], ["すっかり"], "adv adv-to", 4, None, False),
    (1038350, [], ["カメラ"], "n", 68, None, False),
    (1093450, [], ["ノート"], "n vs vt", 68, None, False),
    (1464900, ["日曜日"], ["にちようび"], "n adv", 4, None, False),
    (1273270, ["公園"], ["こうえん"], "n", 5, 2, False),
    (1303620, ["散歩"], ["さんぽ"], "n vs vi", 5, 10, False),
    (1428280, ["朝"], ["あさ"], "n adv", 5, 9, False),
    (1513060, ["弁当"], ["べんとう"], "n", 5, 7, False),
    (1597890, ["作る"], ["つくる"], "v5r vt", 5, 4, False),
    (1175140, ["駅"], ["えき"], "n ctr", 5, 5, False),
    (1392580, ["前"], ["まえ"], "n adj-no adv suf", 4, None, False),
    (1410590, ["待つ"], ["まつ"], "v5t vt vi", 5, 18, False),
    (1333520, ["週末"], ["しゅうまつ"], "adv n", 5, 6, False),
    (1543240, ["予定"], ["よてい"], "n vs vt", 5, 1, False),
    (1415260, ["第"], ["だい"], "pref", 16, None, False),
    (1195710, ["課"], ["か"], "n n-suf ctr", 5, 8, False),
    (1311530, ["紙"], ["かみ"], "n", 5, 3, False),
    (1338180, ["出す"], ["だす"], "v5s vt suf", 5, 3, False),
    (1404975, ["早い"], ["はやい"], "adj-i", 5, 16, False),
    (1227560, ["休む"], ["やすむ"], "v5m vi", 5, 20, False),
    # g02
    (1524590, ["妹"], ["いもうと"], "n", 5, 6, False),
    (1524730, ["毎晩"], ["まいばん"], "n adv", 5, 18, False),
    (1106400, [], ["ピアノ"], "n", 68, None, False),
    (1559160, ["練習"], ["れんしゅう"], "n vs vt", 5, 2, False),
    (1579260, ["昨日"], ["きのう"], "n adv", 5, 10, False),
    (1083590, [], ["デパート"], "n", 68, None, False),
    (1361490, ["新しい"], ["あたらしい"], "adj-i", 5, 8, False),
    (1246700, ["靴"], ["くつ"], "n", 5, 6, False),
    (1473740, ["買う"], ["かう"], "v5u vt", 5, 10, False),
    (1223640, ["起きる"], ["おきる"], "v1 vi", 6, 31, False),
    (1217730, ["顔"], ["かお"], "n", 5, 1, False),
    (1390930, ["洗う"], ["あらう"], "v5u vt", 5, 23, False),
    (1067040, [], ["スープ"], "n", 68, None, False),
    (1365850, ["辛い"], ["からい"], "adj-i", 5, 24, False),
    (1581930, ["弟"], ["おとうと"], "n", 5, 4, False),
    (1231590, ["牛乳"], ["ぎゅうにゅう"], "n", 5, 8, False),
    (1169870, ["飲む"], ["のむ"], "v5m vt", 6, 35, False),
    (1541620, ["有名"], ["ゆうめい"], "adj-na", 5, 3, False),
    (1202270, ["絵"], ["え"], "n", 1, 2, False),
    (1467640, ["猫"], ["ねこ"], "n", 5, 7, True),
    (1360010, ["寝る"], ["ねる"], "v1 vi", 5, 15, False),
    (1221270, ["帰る"], ["かえる"], "v5r vi", 6, 37, False),
    # g03
    (1222840, ["季節"], ["きせつ"], "n adj-no", 5, 4, False),
    (1596780, ["台風"], ["たいふう"], "n", 5, 4, False),
    (1557110, ["冷蔵庫"], ["れいぞうこ"], "n", 5, 8, False),
    (1390980, ["洗濯"], ["せんたく"], "n vs vt", 5, 9, False),
    (1519210, ["忘れる"], ["わすれる"], "v1 vt", 4, None, False),
    (1457200, ["届く"], ["とどく"], "v5k vi", 4, None, False),
    (1586420, ["暖かい"], ["あたたかい"], "adj-i", 4, None, False),
    (1591900, ["綺麗"], ["きれい"], "adj-na", 4, None, True),
    (1076170, [], ["タオル"], "n", 68, None, False),
    (1558050, ["歴史"], ["れきし"], "n", 5, 1, False),
    (1443840, ["電話"], ["でんわ"], "n vs vt vi", 5, 1, False),
    (1600900, ["話"], ["はなし"], "n", 5, 1, False),
    (1207610, ["掛ける"], ["かける"], "v1 vt suf", 5, 20, True),
    # g04
    (1582120, ["店"], ["みせ"], "n", 4, None, False),
    (1296970, ["財布"], ["さいふ"], "n", 5, 10, False),
    (1490670, ["品物"], ["しなもの"], "n", 5, 14, False),
    (1474040, ["売店"], ["ばいてん"], "n", 5, 16, False),
    (1301940, ["傘"], ["かさ"], "n", 5, 11, False),
    (1519170, ["帽子"], ["ぼうし"], "n vs vi", 5, 9, True),
    (1270550, ["お釣り"], ["おつり"], "n", 4, None, False),
    (1411070, ["袋"], ["ふくろ"], "n", 5, 8, False),
    (1508380, ["並ぶ"], ["ならぶ"], "v5b vi", 6, 29, False),
    (1501620, ["払う"], ["はらう"], "v5u vt", 5, 21, False),
    (1153670, ["安い"], ["やすい"], "adj-i", 6, 47, False),
    (1580480, ["丈夫"], ["じょうぶ"], "adj-na", 5, 15, False),
    (1512610, ["便利"], ["べんり"], "adj-na", 5, 6, False),
    (1145130, [], ["レジ"], "n", 64, None, False),
    (2849867, ["混む"], ["こむ"], "v5m vi", 4, None, False),
    (1237410, ["橋"], ["はし"], "n", 5, 5, False),
    (1444680, ["渡る"], ["わたる"], "v5r vi", 6, 41, True),
    # g05
    (1396840, ["祖父"], ["そふ"], "n", 5, 9, False),
    (1476520, ["畑"], ["はたけ"], "n n-suf", 5, 4, False),
    (1537370, ["野菜"], ["やさい"], "n", 5, 3, False),
    (1160570, ["育てる"], ["そだてる"], "v1 vt", 4, None, False),
    (1330510, ["収穫"], ["しゅうかく"], "n vs vt", 5, 7, False),
    (1607070, ["叔父"], ["おじ"], "n", 5, 16, False),
    (1328190, ["手伝う"], ["てつだう"], "v5u vt", 6, 46, False),
    (1332650, ["秋"], ["あき"], "n adv", 5, 1, False),
    (1085420, [], ["トマト"], "n", 68, None, False),
    (1213400, ["甘い"], ["あまい"], "adj-i", 5, 19, False),
    (1486650, ["美味しい"], ["おいしい"], "adj-i", 4, None, True),
    (1355120, ["乗る"], ["のる"], "v5r vi", 5, 21, False),
    (1426370, ["昼寝"], ["ひるね"], "n vs vi", 5, 22, False),
    # g06
    (1277450, ["好き"], ["すき"], "adj-na n", 4, None, False),
    (1353320, ["上手"], ["じょうず"], "adj-na n", 5, 12, False),
    (1534520, ["木"], ["き"], "n", 5, 1, False),
    (1221520, ["気"], ["き"], "n", 5, 1, False),
    (1206730, ["学校"], ["がっこう"], "n", 5, 1, False),
    (1367300, ["人口"], ["じんこう"], "n", 5, 1, False),
    (1370420, ["図書館"], ["としょかん"], "n", 5, 5, False),
    (1249900, ["兄"], ["あに"], "n", 5, 5, False),
    (1536350, ["夜"], ["よる", "よ"], "n adv", 5, 2, False),
    (1280770, ["紅茶"], ["こうちゃ"], "n", 5, 13, False),
    (1499320, ["部屋"], ["へや"], "n", 5, 2, False),
    (1381820, ["静か"], ["しずか"], "adj-na", 5, 5, False),
    # g10
    (1585650, ["箱"], ["はこ"], "n suf ctr", 5, 9, False),
    (1422230, ["竹"], ["たけ"], "n", 5, 4, False),
    (1415870, ["沢山"], ["たくさん"], "adj-no adj-na n adv n-suf", 6, 43, True),
    (1012800, [], ["やっと"], "adv", 4, None, True),
    (1003430, [], ["きっと"], "adv", 4, None, True),
    (1160790, ["一"], ["いち"], "num pref adj-no suf n n-pref", 6, 33, False),
    (1445360, ["土産"], ["みやげ"], "n", 5, 11, False),
    (1002500, ["お土産"], ["おみやげ"], "n", 4, None, False),
    (1295510, ["細い"], ["ほそい"], "adj-i", 5, 16, False),
    (1365250, ["親切"], ["しんせつ"], "adj-na n", 5, 15, False),
    (1202450, ["開ける"], ["あける"], "v1 vt vi", 4, None, False),
    (1508590, ["閉める"], ["しめる"], "v1 vt", 6, 25, False),
    (1220210, ["机"], ["つくえ"], "n", 5, 7, False),
    (1401400, ["窓"], ["まど"], "n", 5, 4, False),
    (1436130, ["庭"], ["にわ"], "n", 5, 6, False),
    (1238550, ["鏡"], ["かがみ"], "n", 5, 6, False),
    (1461160, ["二つ"], ["ふたつ"], "num", 5, 2, False),
    (1272350, ["交通事故"], ["こうつうじこ"], "n", 5, 7, False),
    (1272280, ["交通"], ["こうつう"], "n vs", 5, 2, False),
    (1313850, ["事故"], ["じこ"], "n", 5, 1, False),
    (1376250, ["整理"], ["せいり"], "n vs vt", 5, 5, False),
    (1634040, ["問"], ["もん"], "suf ctr", 1, 9, False),
    # g11
    (1457210, ["届ける"], ["とどける"], "v1 vt", 4, None, False),
    (1195430, ["荷物"], ["にもつ"], "n", 5, 9, False),
    (1540170, ["友達"], ["ともだち"], "n", 5, 5, False),
    (1191730, ["家"], ["いえ"], "n", 4, None, False),
    (1511790, ["片付ける"], ["かたづける"], "v1 vt", 6, 37, False),
    (1598550, ["出かける"], ["でかける"], "v1 vi", 16, None, False),
    (1341670, ["準備"], ["じゅんび"], "n vs vt", 5, 2, False),
)

# Words whose Korean meaning does not follow the Sino-Korean reading (about half of them).
KOREAN_GLOSSES: dict[str, list[str]] = {
    "走る": ["달리다", "뛰다"],
    "景色": ["경치", "풍경"],
    "忘れる": ["잊다"],
    "暖かい": ["따뜻하다"],
    "財布": ["지갑"],
    "袋": ["봉지", "자루"],
    "払う": ["지불하다", "치르다"],
    "丈夫": ["튼튼하다", "건강하다"],
    "混む": ["붐비다", "혼잡하다"],
    "畑": ["밭"],
    "叔父": ["삼촌", "숙부"],
    # g10: kanji words for the backward lookup (상자 → 箱, 많이 → 沢山) and kana words
    "箱": ["상자"],
    "沢山": ["많이"],
    "やっと": ["겨우", "간신히"],
    "みやげ": ["선물", "기념품"],
    "細い": ["가늘다"],
    "開ける": ["열다"],
    "閉める": ["닫다"],
    "庭": ["마당", "뜰"],
    "鏡": ["거울"],
    # g11
    "届ける": ["보내다", "배달하다"],
    "片付ける": ["정리하다", "치우다"],
}


def lexicon() -> dict:
    return {"_note": LEXICON_NOTE, "entries": [
        {"id": i, "kanji": k, "readings": r, "pos": pos.split(), "pri": pri, "nf": nf, "uk": uk}
        for i, k, r, pos, pri, nf, uk in LEXICON]}


def check_lexicon(pages: list[GPage]) -> None:
    """Every word of the answers must be in the lexicon (a な-adjective headword without its だ)."""
    forms = {f for _, k, r, *_ in LEXICON for f in (*k, *r)}
    wanted = {w for p in pages for w in (*(v["headword"] for v in p.vocab), *p.sentence_words)}
    # `(お)みやげ`: an optional prefix in brackets; the dictionary has the word without it
    bare = {w: re.sub(r"[(（][^)）]*[)）]", "", w) for w in wanted}
    missing = sorted(w for w in wanted if bare[w] not in forms and bare[w].removesuffix("だ") not in forms)
    if missing:
        raise SystemExit(f"words missing from LEXICON: {missing}")


# ---------------------------------------------------------------- output

def dump(data: dict, indent: int) -> str:
    return json.dumps(data, ensure_ascii=False, indent=indent) + "\n"


def render() -> dict[str, str]:
    pages = [make() for make in PAGES]
    check_lexicon(pages)
    files: dict[str, str] = {}
    for p in pages:
        for name, data in p.files().items():
            files[name] = dump(data, 0)
    files["ground_truth.json"] = dump({"_note": GT_NOTE, "format": "general-1",
                                       "pages": [p.general_answer() for p in pages]}, 1)
    legacy = [p.answer() for p in pages if p.kind == "warped"]
    files["ground_truth_legacy.json"] = dump({"_note": NOTE + " The warped page in the answer format of "
                                              "tools/synthetic/make_pages.py.", "pages": legacy}, 1)
    files["lexicon.json"] = dump(lexicon(), 1)
    files["korean_glosses.json"] = dump({"_note": GLOSS_NOTE, "glosses": KOREAN_GLOSSES}, 1)
    traps = [make() for make in TRAP_PAGES]
    for p in traps:
        for name, data in p.files().items():
            files[name] = dump(data, 0)
    files["ground_truth_traps.json"] = dump({"_note": TRAP_NOTE, "format": "general-1",
                                             "pages": [p.general_answer() for p in traps]}, 1)
    return files


def main(argv: list[str]) -> int:
    check = "--check" in argv
    stale = []
    for name, text in render().items():
        f = OUT_DIR / name
        if check:
            if not f.is_file() or f.read_text(encoding="utf-8") != text:
                stale.append(str(f.relative_to(REPO)))
        else:
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            f.write_text(text, encoding="utf-8")
    if check:
        for s in stale:
            print(f"out of date: {s} (run python3 tools/synthetic/make_general_pages.py)", file=sys.stderr)
        return 1 if stale else 0
    print(f"wrote {OUT_DIR.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
