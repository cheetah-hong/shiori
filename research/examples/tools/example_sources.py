"""Example-sentence sources for words without a printed example.

Pure parsing and ranking; ``measure_examples.py`` does the file I/O.

Sources (one ``Example`` per sentence and dictionary entry it illustrates):
- ``tatoeba``: Tatoeba Japanese sentences through the word indices
  (``jpn_indices.csv``, the Tanaka Corpus "B lines"), which name each word in
  its dictionary form, so conjugated uses are found without deconjugating;
- ``jmdict``: the ``<example>`` elements of ``JMdict_e_examp`` (a picked
  Tatoeba sentence per sense);
- ``kowikt`` / ``jawikt`` / ``enwikt``: the examples of Japanese entries in
  the Korean, Japanese and English Wiktionary (kaikki extracts).
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

SOURCES = ("tatoeba", "jmdict", "kowikt", "jawikt", "enwikt")

# --- text classes ----------------------------------------------------------

_KANA = r"ぁ-ゖァ-ヺー"
_KANJI = r"㐀-䶿一-鿿豈-﫿々"
_HANGUL = re.compile(r"[가-힣ㄱ-ㆎ]")
_LATIN = re.compile(r"[A-Za-z]")
_KANA_RE = re.compile(f"[{_KANA}]")
_KANJI_RE = re.compile(f"[{_KANJI}]")
_KANA_ONLY = re.compile(f"^[{_KANA}]+$")
_END = "。！？!?」』…"

# A sentence shown on a card: long enough to be a sentence, short enough to
# read at a glance (printed examples on the local pages: median 11 chars,
# nine in ten at most 27).
MIN_LEN = 6
MAX_LEN = 30


def is_kana_only(text: str) -> bool:
    return bool(_KANA_ONLY.match(text))


def kanji_of(text: str) -> set[str]:
    return set(_KANJI_RE.findall(text))


def is_card_sentence(text: str) -> bool:
    """Japanese only (no Hangul, no Latin letters), a whole sentence or a
    phrase with kana, and of card length."""
    t = text.strip()
    if not (MIN_LEN <= len(t) <= MAX_LEN):
        return False
    if _HANGUL.search(t) or _LATIN.search(t):
        return False
    if not _KANA_RE.search(t):
        return False
    return not any(c in t for c in "/／＝=;；^:：")


def ends_as_sentence(text: str) -> bool:
    return text.strip()[-1:] in _END


# Words a learner's card should not show by default. Short on purpose: it
# finds candidates to drop, the sample judged by eye says how well.
SENSITIVE = (
    "殺", "死ね", "自殺", "死体", "セックス", "性交", "レイプ", "強姦", "売春",
    "麻薬", "覚醒剤", "爆弾", "テロ", "拳銃", "ヌード", "裸", "エロ", "ポルノ",
    "売女", "ばか野郎", "くそ", "クソ", "畜生", "ちくしょう", "黒人", "ユダヤ",
    "ナチ", "ヒトラー", "レズ", "ホモ", "おっぱい", "ちんちん", "ちんこ", "まんこ",
)


def is_sensitive(text: str) -> bool:
    return any(w in text for w in SENSITIVE)


# Tatoeba tags that mark a sentence as unfit for a beginner's card.
BAD_TAGS = frozenset({
    "@needs native check", "not a sentence", "@possible copyright infringement",
    "Classical Japanese (Bungo)", "old kana", "@change", "@check translation",
    "@wrong transliteration", "extra-long sentence", "dialectal", "Kansai dialect",
    "vulgar", "@check", "@delete", "@neologism", "old-fashioned", "poetry",
    "not for WWWJDIC", "@needs native check (jpn)",
})


# --- the example record ----------------------------------------------------

@dataclass(frozen=True)
class Example:
    source: str
    key: str                       # the form the source files it under
    ja: str
    ko: str | None = None
    en: str | None = None
    ref: str | None = None         # sentence id / entry title, for attribution
    author: str | None = None
    checked: bool = False          # Tatoeba "~": a good and checked example
    ko_direct: bool = False        # the Korean translates this sentence (not via English)
    reading: str | None = None     # how the word is read in the sentence, when known
    words: tuple[str, ...] = ()    # dictionary forms in the sentence (Tatoeba)
    tags: frozenset[str] = field(default_factory=frozenset)


# --- Tatoeba word indices ("B lines") --------------------------------------

@dataclass(frozen=True)
class IndexWord:
    headword: str
    reading: str | None
    surface: str | None
    checked: bool


# headword(reading)[sense]{surface}~ ; every part after the headword optional.
_BWORD = re.compile(
    r"^(?P<h>[^(\[{~]+)(?:\((?P<r>[^)]*)\))?(?:\[(?P<s>\d+)\])?"
    r"(?:\{(?P<f>[^}]*)\})?(?P<c>~)?$")


def parse_bline(line: str) -> list[IndexWord]:
    """``は 二十歳(はたち){２０歳} になる[01]{になりました}`` → words.
    Malformed tokens are skipped, not guessed."""
    out = []
    for tok in line.split():
        m = _BWORD.match(tok)
        if not m:
            continue
        out.append(IndexWord(m["h"], m["r"] or None, m["f"] or None, bool(m["c"])))
    return out


def parse_indices_row(row: str) -> tuple[str, list[IndexWord]] | None:
    """``jpn_indices.csv`` row: sentence id, English id, B line (tabs)."""
    cells = row.rstrip("\n").split("\t")
    if len(cells) != 3 or not cells[0].isdigit():
        return None
    return cells[0], parse_bline(cells[2])


def parse_sentence_row(row: str) -> tuple[str, str, str, str | None] | None:
    """``*_sentences_detailed.tsv`` row → (id, lang, text, username)."""
    cells = row.rstrip("\n").split("\t")
    if len(cells) < 3 or not cells[0].isdigit():
        return None
    user = cells[3] if len(cells) > 3 and cells[3] not in ("", r"\N") else None
    return cells[0], cells[1], cells[2], user


# --- Wiktionary (kaikki) ---------------------------------------------------

_INLINE_RUBY = re.compile(f"(?<=[{_KANJI}])[(（][{_KANA}]+[)）]")


def strip_inline_ruby(text: str) -> str:
    """``生徒(せいと)です`` → ``生徒です`` (readings typed after the kanji)."""
    return _INLINE_RUBY.sub("", text)


def wikt_examples(source: str, entry: dict) -> list[Example]:
    """Examples of one kaikki entry of a Japanese word.

    ``text`` is the Japanese; ``translation`` is Korean in the Korean
    edition and English in the English edition. The Japanese edition puts
    the sentence in ``translation`` when ``text`` is empty and has no
    translation, so only ``text`` is taken there.
    """
    if entry.get("lang_code") != "ja":
        return []
    word = entry.get("word") or ""
    out = []
    for sense in entry.get("senses") or ():
        for ex in sense.get("examples") or ():
            if ex.get("type") == "quotation" or ex.get("ref"):
                continue
            ja = strip_inline_ruby((ex.get("text") or "").strip())
            if not ja:
                continue
            tr = (ex.get("translation") or ex.get("english") or "").strip() or None
            ko = clean_korean(tr) if source == "kowikt" and tr and _HANGUL.search(tr) else None
            en = tr if source == "enwikt" and tr else None
            out.append(Example(source, word, ja, ko=ko, ko_direct=ko is not None, en=en, ref=word))
    return out


# --- word universe: JMdict entries -----------------------------------------

@dataclass(frozen=True)
class Entry:
    seq: str
    kanji: tuple[str, ...]
    readings: tuple[str, ...]
    usually_kana: bool = False       # a sense marked ``uk``
    common_readings: tuple[str, ...] = ()  # readings with a priority tag


def parse_jmdict(stream):
    """Yield ``(Entry, [Example...])`` from a JMdict XML stream; the
    examples are the ``<example>`` elements (only in ``JMdict_e_examp``)."""
    import xml.etree.ElementTree as ET

    for _, el in ET.iterparse(stream, events=("end",)):
        if el.tag != "entry":
            continue
        seq = el.findtext("ent_seq") or ""
        kanji = tuple(k.findtext("keb") or "" for k in el.findall("k_ele"))
        readings = tuple(r.findtext("reb") or "" for r in el.findall("r_ele"))
        common = tuple(r.findtext("reb") or "" for r in el.findall("r_ele") if r.find("re_pri") is not None)
        uk = any("kana alone" in (m.text or "") for m in el.iter("misc"))
        entry = Entry(seq, kanji, readings, uk, common)
        examples = []
        for ex in el.iter("example"):
            sents = {s.get("{http://www.w3.org/XML/1998/namespace}lang"): (s.text or "").strip()
                     for s in ex.findall("ex_sent")}
            ja = sents.get("jpn")
            if not ja:
                continue
            examples.append(Example("jmdict", ex.findtext("ex_text") or "", ja,
                                    en=sents.get("eng") or None,
                                    ref=ex.findtext("ex_srce"), checked=True))
        yield entry, examples
        el.clear()


class EntryIndex:
    """Forms → JMdict entries, to join a word to a source on the entry."""

    def __init__(self, entries: list[Entry]):
        self._kanji: dict[str, list[Entry]] = {}
        self._reading: dict[str, list[Entry]] = {}
        self._seq = {e.seq: e for e in entries}
        for e in entries:
            for k in e.kanji:
                self._kanji.setdefault(k, []).append(e)
            for r in e.readings:
                self._reading.setdefault(r, []).append(e)

    def lookup(self, form: str, readings: list[str] | tuple[str, ...] = ()) -> list[Entry]:
        """Entries written ``form``; narrowed to ``readings`` when that keeps
        any. A kana form not written as kanji anywhere goes through
        ``_kana_entries``."""
        hits = self._kanji.get(form, [])
        if not hits:
            hits = self._kana_entries(form)
        if readings:
            narrowed = [e for e in hits if set(e.readings) & set(readings)]
            if narrowed:
                return narrowed
        return list(hits)

    def by_seq(self, seq: str) -> list[Entry]:
        return [self._seq[seq]] if seq in self._seq else []

    def _kana_entries(self, form: str) -> list[Entry]:
        """The entries a word written in kana stands for, the first rule that
        keeps any (each first with this reading common): no kanji; usually
        written in kana; then the same without the reading common; then the
        reading common alone
        (``は`` → the particle, ``こう`` → 斯う, not 稿·項·稲子)."""
        read = self._reading.get(form, [])
        common = lambda e: form in e.common_readings  # noqa: E731
        for keep in (lambda e: not e.kanji and common(e),
                     lambda e: e.usually_kana and common(e),
                     lambda e: not e.kanji, lambda e: e.usually_kana, common):
            hits = [e for e in read if keep(e)]
            if hits:
                return hits
        return read

    def forms_of(self, entries: list[Entry]) -> set[str]:
        return {f for e in entries for f in (*e.kanji, *e.readings)}


# --- ranking ---------------------------------------------------------------

def reading_agrees(example_reading: str | None, readings: list[str] | tuple[str, ...]) -> bool:
    """False only when both are known and differ before the last kana (the
    inflected ending): 辛い read つらい is not the からい word."""
    if not example_reading or not readings:
        return True
    if not is_kana_only(example_reading):
        return True
    seen = to_hiragana(example_reading)
    return any(seen[:max(1, len(r) - 1)] == to_hiragana(r)[:max(1, len(r) - 1)] for r in readings)


def to_hiragana(text: str) -> str:
    """``ダメ`` → ``だめ`` (ー stays)."""
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in text)


_DASH = re.compile(r"^[\s\-–—・]+")


def clean_korean(text: str | None) -> str | None:
    """``- 관계를 끊다.`` / ``(전화가 멀어서 …)`` → the sentence alone."""
    if not text:
        return text
    t = _DASH.sub("", text.strip())
    if t.startswith("(") and t.endswith(")"):
        t = t[1:-1].strip()
    return t or None


def unknown_kanji(text: str, known: set[str]) -> int:
    return len(kanji_of(text) - known)


def usable(ex: Example) -> bool:
    return is_card_sentence(ex.ja) and not is_sensitive(ex.ja) and not (ex.tags & BAD_TAGS)


def rank_key(ex: Example, known_kanji: set[str]) -> tuple:
    """Lower is better: a Korean translation of this very sentence, checked,
    any Korean (through English), no kanji beyond the N5-N3 words, a full
    sentence, then nearer 14 chars (short, but a whole sentence)."""
    return (
        not (ex.ko and ex.ko_direct),
        not ex.checked,
        ex.ko is None,
        unknown_kanji(ex.ja, known_kanji),
        not ends_as_sentence(ex.ja),
        abs(len(ex.ja) - 14),
        ex.ja,
    )


def pick(examples: list[Example], known_kanji: set[str], n: int = 2) -> list[Example]:
    """The ``n`` best usable examples, one per distinct sentence."""
    seen: set[str] = set()
    out = []
    for ex in sorted((e for e in examples if usable(e)), key=lambda e: rank_key(e, known_kanji)):
        if ex.ja in seen:
            continue
        seen.add(ex.ja)
        out.append(ex)
        if len(out) == n:
            break
    return out
