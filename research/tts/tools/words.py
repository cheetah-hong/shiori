"""Readers for the word list and the accent data files (pure text parsing)."""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from accent import count_morae

WORDS_HEADER = ("표기", "읽기", "기대", "분류", "메모")
_TAG = re.compile(r"\([^)]*\)")


@dataclass(frozen=True)
class Word:
    surface: str
    reading: str
    expected: tuple[int, ...]
    group: str
    note: str

    @property
    def morae(self) -> int:
        return count_morae(self.reading)


def _accent_list(text: str, where: str) -> tuple[int, ...]:
    values: list[int] = []
    for part in text.split(","):
        part = part.strip()
        if not part.isdigit():
            raise ValueError(f"{where}: accent {text!r} is not a list of numbers")
        if int(part) not in values:
            values.append(int(part))
    return tuple(values)


def parse_words_tsv(text: str) -> list[Word]:
    lines = [ln for ln in text.splitlines() if ln.strip()]
    if not lines or tuple(lines[0].split("\t")) != WORDS_HEADER:
        raise ValueError(f"words.tsv header must be {WORDS_HEADER}")
    rows = []
    for n, line in enumerate(lines[1:], start=2):
        cols = line.split("\t")
        if len(cols) != len(WORDS_HEADER):
            raise ValueError(f"line {n}: expected {len(WORDS_HEADER)} columns")
        surface, reading, exp, group, note = (c.strip() for c in cols)
        expected = _accent_list(exp.replace("/", ","), f"line {n}")
        morae = count_morae(reading)
        if any(a > morae for a in expected):
            raise ValueError(f"line {n}: accent {exp} exceeds {morae} morae")
        rows.append(Word(surface, reading, expected, group, note))
    return rows


def load_words(path: Path) -> list[Word]:
    return parse_words_tsv(path.read_text(encoding="utf-8"))


def parse_kanjium_line(line: str) -> tuple[str, str, tuple[int, ...]]:
    """`word<TAB>reading<TAB>accents`; accents look like "2,0" or "(副)1,(名)0"."""
    cols = line.rstrip("\n").split("\t")
    if len(cols) != 3:
        raise ValueError(f"kanjium line needs 3 columns: {line!r}")
    word, reading, accents = cols
    return word, reading, _accent_list(_TAG.sub("", accents), word)


def parse_atype(value: str) -> tuple[int, ...]:
    """UniDic aType: "1", "2,0" or "*" (none)."""
    value = value.strip()
    if value in ("", "*"):
        return ()
    return _accent_list(value, "aType")
