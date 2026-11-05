"""Judge one source's accent values against the expected ones, and count verdicts."""
from __future__ import annotations

from collections import Counter
from typing import Iterable

MATCH = "일치"
MATCH_MULTI = "일치(복수)"
MISMATCH = "불일치"
MISSING = "없음"
VERDICTS = (MATCH, MATCH_MULTI, MISMATCH, MISSING)


def judge(expected: Iterable[int], candidates: Iterable[int]) -> str:
    """MATCH: the source gives one value and it is expected.
    MATCH_MULTI: the source gives several values and at least one is expected.
    MISMATCH: no value is expected. MISSING: the source has no value."""
    want = set(expected)
    got = set(candidates)
    if not got:
        return MISSING
    if not want & got:
        return MISMATCH
    return MATCH if len(got) == 1 else MATCH_MULTI


def tally(verdicts: Iterable[str]) -> Counter:
    counts: Counter = Counter({v: 0 for v in VERDICTS})
    for v in verdicts:
        if v not in VERDICTS:
            raise ValueError(f"unknown verdict {v!r}")
        counts[v] += 1
    return counts


def match_rate(counts: Counter) -> tuple[int, int]:
    """(matched, judged) where judged excludes MISSING."""
    matched = counts[MATCH] + counts[MATCH_MULTI]
    return matched, matched + counts[MISMATCH]


def coverage(counts: Counter) -> tuple[int, int]:
    """(rows with a value, all rows)."""
    total = sum(counts[v] for v in VERDICTS)
    return total - counts[MISSING], total
