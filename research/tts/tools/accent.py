"""Tokyo pitch-accent patterns and mora counting (pure, no engine needed).

Accent type follows the usual dictionary notation:
  0 = flat (heiban): the pitch rises after the first mora and does not fall,
      not even on a following particle.
  n = the pitch falls right after the n-th mora (1 = falls after the first mora).

Pattern strings use one letter per mora: "H" high, "L" low, "?" not judged.
"""
from __future__ import annotations

SMALL_KANA = set("ゃゅょぁぃぅぇぉゎャュョァィゥェォヮ")
SPECIAL_MORAE = set("んンっッー")
_KANA_RANGES = ((0x3041, 0x3096), (0x30A1, 0x30FA))


def _is_kana(ch: str) -> bool:
    return ch == "ー" or any(lo <= ord(ch) <= hi for lo, hi in _KANA_RANGES)


def split_morae(kana: str) -> list[str]:
    """Split kana into morae. Small ゃゅょ (and small vowels) join the previous mora;
    ん, っ and ー are morae of their own."""
    if not kana:
        raise ValueError("empty reading")
    morae: list[str] = []
    for ch in kana:
        if not _is_kana(ch):
            raise ValueError(f"not kana: {ch!r} in {kana!r}")
        if ch in SMALL_KANA:
            if not morae:
                raise ValueError(f"reading starts with a small kana: {kana!r}")
            morae[-1] += ch
        else:
            morae.append(ch)
    return morae


def count_morae(kana: str) -> int:
    return len(split_morae(kana))


def phrase_pattern(nucleus: int, morae: int) -> str:
    """H/L pattern of one accent phrase whose fall comes after mora `nucleus`
    (0 = no fall inside the phrase)."""
    if morae < 1:
        raise ValueError(f"phrase needs at least one mora, got {morae}")
    if not 0 <= nucleus <= morae:
        raise ValueError(f"nucleus {nucleus} outside 0..{morae}")
    if nucleus == 1:
        return "H" + "L" * (morae - 1)
    if morae == 1:
        return "L"
    high_end = morae if nucleus == 0 else nucleus
    return "L" + "H" * (high_end - 1) + "L" * (morae - high_end)


def pattern_for(accent_type: int, morae: int, with_particle: bool = True) -> str:
    """Pattern of a word with `morae` morae, plus one particle mora by default.

    The particle is what separates flat (0) from a fall after the last mora:
    あめ(0)+が = LHH, はし(2)+が = LHL."""
    if not 0 <= accent_type <= morae:
        raise ValueError(f"accent {accent_type} outside 0..{morae}")
    total = morae + 1 if with_particle else morae
    return phrase_pattern(accent_type, total)


def has_heavy_start(kana: str) -> bool:
    """True when the first syllable is heavy, i.e. mora 2 is ん, っ or ー.

    Rule used for judging: in Tokyo speech the first mora of such words is often not
    lowered (the initial rise is weak or absent; this is the standard note in Japanese
    accent dictionaries and textbooks on 「初頭の低さ」). The canonical pattern still
    starts with "L", but the first position is not judged. A long vowel written with
    a plain vowel kana (きょう) is not detected here; callers that know the phonemes
    (e.g. a VOICEVOX mora with no consonant and the same vowel) pass the flag
    themselves."""
    morae = split_morae(kana)
    return len(morae) >= 2 and morae[1][0] in SPECIAL_MORAE


def patterns_match(expected: str, observed: str, heavy_start: bool = False) -> bool:
    """Compare two patterns of the same length. "?" matches anything; with
    `heavy_start` the first mora is not judged."""
    if len(expected) != len(observed):
        return False
    for i, (e, o) in enumerate(zip(expected, observed)):
        if heavy_start and i == 0:
            continue
        if "?" in (e, o):
            continue
        if e != o:
            return False
    return True
