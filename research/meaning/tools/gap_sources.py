"""Japanese → Korean meanings from Wiktionary extracts, for words the Korean
glossary has no sense for (research only; nothing here ships in the app).

Sources (kaikki.org wiktextract JSONL, read as given on the command line):

- ``kowikt``     ko.wiktionary, Japanese entries: the Korean glosses.
- ``kowikt_tr``  ko.wiktionary, Korean entries: their Japanese translations.
- ``jawikt_tr``  ja.wiktionary, Japanese entries: their Korean translations
                 (an entry that only says "X の漢字表記" / "X 参照" takes X's
                 when X has one entry or lists it as its kanji spelling).
- ``jawikt_rev`` ja.wiktionary, Korean entries: the Japanese words of their
                 glosses (저녁: 「夕方。」 → 夕方 → 저녁).
- ``enwikt_tr``  en.wiktionary, English senses whose translation table has
                 both Japanese and Korean: each Japanese term → that sense's
                 Korean terms (a pivot through the English sense).

Each source is an index ``{key: [Sense]}``; a sense is a tuple of Korean
words with the readings the source gives (empty when it gives none).
"""
from __future__ import annotations

import gzip
import json
import re
import sqlite3
import sys
import tempfile
from pathlib import Path
from typing import Iterable, Iterator, NamedTuple

_HERE = Path(__file__).resolve()
sys.path.insert(0, str(_HERE.parents[3] / "tools" / "dict"))
from build_ko_glossary import has_kanji, keys_and_ending, to_hiragana  # noqa: E402
# The app's fallback glossary builder reads glosses the same way.
from build_wikt_glossary import (  # noqa: E402,F401
    korean_words,
    readings_of as _ruby_readings,
    ruby_reading,
    translation_words,
)


class Sense(NamedTuple):
    words: tuple[str, ...]
    readings: frozenset[str]


SOURCES = ("kowikt", "kowikt_tr", "jawikt_tr", "jawikt_rev", "enwikt_tr")

# ------------------------------------------------------------------ text

_HANGUL = re.compile("[가-힣]")
_JA_CHAR = re.compile("[ぁ-ゟ゠-ヿ一-鿿㐀-䶿々〆ー]")
_PARENS = re.compile(r"\s*[（(\[［][^）)\]］]*[）)\]］]\s*")
_JA_GLOSS_SPLIT = re.compile(r"[、。,，;；・/\s]+")
_REDIRECT = re.compile(
    r"^[「『]?(?P<target>[ぁ-ゟ゠-ヿー、・\s]+)[」』]?"
    r"(?:の(?:漢字)?表記|の旧字体表記|の異表記|\s*参照|を参照)"
)
_KANA_ONLY = re.compile(r"^[ぁ-ゟ゠-ヿー]+$")


def japanese_terms(gloss: str) -> list[str]:
    """The Japanese words of a Japanese gloss (``夕方。晩。`` → 夕方·晩).
    A piece with anything but kana or kanji (a sentence, a note) is dropped."""
    text = _PARENS.sub("、", gloss)
    out = []
    for piece in _JA_GLOSS_SPLIT.split(text):
        if piece and all(_JA_CHAR.match(c) for c in piece) and piece not in out:
            out.append(piece)
    return out


def redirect_targets(gloss: str) -> list[str]:
    """The kana entries a "spelling of" gloss points to
    (``しらべるの漢字表記。`` → しらべる; ``ゆうがた、ゆうかた　参照`` → both)."""
    m = _REDIRECT.match(gloss.strip())
    if not m:
        return []
    return [t for t in re.split(r"[、・\s]+", m.group("target")) if t]


def key_of(word: str, reading: str = "") -> tuple[str, str]:
    """The glossary's index keys (same rule as the app's Korean glossary)."""
    key, reading_key, _ = keys_and_ending(word, reading)
    return key, reading_key


# ------------------------------------------------------------------ index


class Index:
    """Senses by headword key, with the readings each sense was given."""

    def __init__(self) -> None:
        self._by_key: dict[str, list[Sense]] = {}

    def add(self, word: str, readings: Iterable[str], ko_words: Iterable[str]) -> None:
        words = tuple(dict.fromkeys(w for w in ko_words if w))
        if not word or not words:
            return
        key, _ = key_of(word)
        reads = frozenset(key_of(word, r)[1] for r in readings if r)
        senses = self._by_key.setdefault(key, [])
        if any(s.words == words and s.readings == reads for s in senses):
            return
        senses.append(Sense(words, reads))

    def lookup(self, headword: str, readings: Iterable[str] = ()) -> list[Sense]:
        """Senses of [headword]. A sense with readings that share none with
        [readings] is left out (食堂/しょくどう never takes 食道's sense);
        a sense the source gave no reading keeps its place."""
        key, _ = key_of(headword)
        want = {key_of(headword, r)[1] for r in readings if r}
        senses = self._by_key.get(key, [])
        if not want:
            return list(senses)
        return [s for s in senses if not s.readings or s.readings & want]

    def __len__(self) -> int:
        return len(self._by_key)

    def rows(self) -> Iterator[tuple[str, str, str]]:
        """(key, readings joined by ・, Korean words joined by ・) per sense."""
        for key, senses in self._by_key.items():
            for s in senses:
                yield key, "・".join(sorted(s.readings)), "・".join(s.words)


def asset_size(index: Index) -> tuple[int, int]:
    """Bytes of a lean SQLite holding [index] (one row per sense, keyed and
    indexed like the app's glossary), and of that file gzipped."""
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "aux.sqlite"
        db = sqlite3.connect(path)
        db.execute("CREATE TABLE sense (key TEXT NOT NULL, reading TEXT NOT NULL, words TEXT NOT NULL)")
        db.executemany("INSERT INTO sense VALUES (?, ?, ?)", index.rows())
        db.execute("CREATE INDEX sense_key ON sense (key)")
        db.commit()
        db.execute("VACUUM")
        db.close()
        raw = path.read_bytes()
        return len(raw), len(gzip.compress(raw, 9))


def _lines(path: Path) -> Iterator[dict]:
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8") as f:
        for line in f:
            yield json.loads(line)


def _translations(entry: dict) -> list[dict]:
    out = list(entry.get("translations") or [])
    for s in entry.get("senses") or []:
        out += s.get("translations") or []
    return out


def _kanji_forms(entry: dict) -> frozenset[str]:
    """Spellings a kana entry lists as its kanji forms."""
    return frozenset(f.get("form", "") for f in entry.get("forms") or []
                     if "kanji" in (f.get("tags") or []))


def build_kowikt(entries: Iterable[dict]) -> tuple[Index, Index]:
    """(kowikt, kowikt_tr) from ko.wiktionary entries."""
    glossed, translated = Index(), Index()
    for e in entries:
        lang = e.get("lang_code")
        if lang == "ja":
            reads = _ruby_readings(e)
            for s in e.get("senses") or []:
                for g in s.get("glosses") or []:
                    glossed.add(e["word"], reads, korean_words(g))
        elif lang == "ko":
            for t in _translations(e):
                if t.get("lang_code") == "ja" and t.get("word") and _HANGUL.search(e["word"]):
                    translated.add(t["word"], [], [e["word"]])
    return glossed, translated


def build_jawikt(entries: Iterable[dict]) -> tuple[Index, Index]:
    """(jawikt_tr, jawikt_rev) from ja.wiktionary entries."""
    translated, reverse = Index(), Index()
    # kana entry → (its Korean senses, the kanji spellings it lists)
    ko_of: dict[str, list[tuple[tuple[str, ...], frozenset[str]]]] = {}
    pending: list[tuple[str, list[str], list[str]]] = []
    kana_entries: dict[str, int] = {}
    for e in entries:
        lang = e.get("lang_code")
        word = e.get("word", "")
        if lang == "ja" and _KANA_ONLY.match(word):
            kana_entries[to_hiragana(word)] = kana_entries.get(to_hiragana(word), 0) + 1
        if lang == "ja":
            groups: dict[str, list[str]] = {}
            for t in _translations(e):
                if t.get("lang_code") == "ko" and t.get("word"):
                    groups.setdefault(t.get("sense") or "", []).extend(translation_words(t["word"]))
            reads = _ruby_readings(e)
            for words in groups.values():
                ko = tuple(words)
                translated.add(word, reads, ko)
                if _KANA_ONLY.match(word):
                    ko_of.setdefault(to_hiragana(word), []).append((ko, _kanji_forms(e)))
            if not groups and has_kanji(word):
                for s in e.get("senses") or []:
                    for g in s.get("glosses") or []:
                        targets = redirect_targets(g)
                        if targets:
                            pending.append((word, targets, reads))
        elif lang == "ko" and _HANGUL.search(word):
            for s in e.get("senses") or []:
                for g in s.get("glosses") or []:
                    for term in japanese_terms(g):
                        reverse.add(term, [], [word])
    for word, targets, reads in pending:
        for target in targets:
            kana = to_hiragana(target)
            for ko, spellings in ko_of.get(kana, []):
                # はる (春) has 봄; 貼る → はる must not take it: follow only to
                # a kana word with one entry, or one that lists this spelling.
                if word in spellings or kana_entries.get(kana) == 1:
                    translated.add(word, reads or [target], ko)
    return translated, reverse


def build_enwikt(rows: Iterable[dict]) -> Index:
    """enwikt_tr from (English sense, ja terms, ko terms) rows."""
    index = Index()
    for row in rows:
        ko = [w for k in row.get("ko") or [] for w in translation_words(k.get("word", ""))]
        for j in row.get("ja") or []:
            alt = j.get("alt") or ""
            reads = [alt] if _KANA_ONLY.match(alt) else []
            index.add(j.get("word", ""), reads, ko)
    return index


def load_all(kowikt: Path | None, jawikt: Path | None, en_pivot: Path | None) -> dict[str, Index]:
    out: dict[str, Index] = {}
    if kowikt:
        out["kowikt"], out["kowikt_tr"] = build_kowikt(_lines(kowikt))
    if jawikt:
        out["jawikt_tr"], out["jawikt_rev"] = build_jawikt(_lines(jawikt))
    if en_pivot:
        out["enwikt_tr"] = build_enwikt(_lines(en_pivot))
    return out
