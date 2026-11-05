"""Read an H/L pattern from per-mora pitch values (pure, no engine needed).

Input is the shape of a VOICEVOX audio query: phrases of morae whose `pitch` is the
natural log of F0 in Hz, and 0.0 for an unvoiced (devoiced) mora.

Rule, applied per accent phrase:
  1. Unvoiced morae inside the phrase get the linear interpolation of their voiced
     neighbours. Unvoiced morae at either edge cannot be judged and become "?".
  2. The nucleus is the first mora i whose pitch is at least `threshold` above
     mora i+1 (the first clear fall). No such fall -> flat (0).
     Tokyo phrases fall at most once, so the first clear fall is the accent fall.
  3. The pattern is the canonical pattern of that nucleus (accent.phrase_pattern).

Default threshold 0.05 in log-F0 = a 5 % drop, about 0.9 semitone. Differences of
about 0.5-1 semitone are the usual just-noticeable range for F0 changes in speech,
and the steps inside a high stretch of VOICEVOX output are mostly below this
(declination), while accent falls are 0.1 or more. The threshold is a choice, not a
measured optimum; README reports the effect of the rule.
"""
from __future__ import annotations

from typing import Any, Mapping, Sequence

from accent import phrase_pattern

DEFAULT_FALL_THRESHOLD = 0.05


def interpolate_unvoiced(pitches: Sequence[float]) -> list[float]:
    """Fill interior zeros linearly; copy the nearest voiced value into edge zeros."""
    voiced = [i for i, p in enumerate(pitches) if p > 0]
    if not voiced:
        raise ValueError("no voiced mora in phrase")
    out = list(pitches)
    for i, p in enumerate(pitches):
        if p > 0:
            continue
        left = max((j for j in voiced if j < i), default=None)
        right = min((j for j in voiced if j > i), default=None)
        if left is None:
            out[i] = pitches[right]
        elif right is None:
            out[i] = pitches[left]
        else:
            w = (i - left) / (right - left)
            out[i] = round(pitches[left] * (1 - w) + pitches[right] * w, 10)
    return out


def decode_nucleus(pitches: Sequence[float],
                   threshold: float = DEFAULT_FALL_THRESHOLD) -> int:
    """1-based mora after which the first clear fall happens; 0 if none."""
    filled = interpolate_unvoiced(pitches)
    for i in range(len(filled) - 1):
        if filled[i] - filled[i + 1] >= threshold:
            return i + 1
    return 0


def edge_unknown(pattern: str, pitches: Sequence[float]) -> str:
    """Replace positions of leading/trailing unvoiced morae with "?"."""
    chars = list(pattern)
    for order in (range(len(pitches)), reversed(range(len(pitches)))):
        for i in order:
            if pitches[i] > 0:
                break
            chars[i] = "?"
    return "".join(chars)


def pitch_pattern(pitches: Sequence[float],
                  threshold: float = DEFAULT_FALL_THRESHOLD) -> str:
    nucleus = decode_nucleus(pitches, threshold)
    return edge_unknown(phrase_pattern(nucleus, len(pitches)), pitches)


def query_patterns(query: Mapping[str, Any],
                   threshold: float = DEFAULT_FALL_THRESHOLD) -> list[str]:
    """One pattern per accent phrase, from mora pitch only (the `accent` field is
    ignored on purpose: this checks what the sound is told to do)."""
    phrases = query.get("accent_phrases")
    if not isinstance(phrases, list):
        raise ValueError("query has no accent_phrases list")
    out = []
    for phrase in phrases:
        pitches = [float(m["pitch"]) for m in phrase["moras"]]
        out.append(pitch_pattern(pitches, threshold))
    return out


def phrase_nucleus(engine_accent: int, morae: int) -> int:
    """VOICEVOX `accent` field -> nucleus. A flat phrase is stored as
    accent == number of morae, which sounds the same as no fall."""
    if not 1 <= engine_accent <= morae:
        raise ValueError(f"engine accent {engine_accent} outside 1..{morae}")
    return 0 if engine_accent == morae else engine_accent
