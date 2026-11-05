#!/usr/bin/env python3
"""Unit tests for the pure helpers of the TTS accent experiment.

No engine, model, dictionary or network is needed: every test uses small fixed data.

usage: cd research/tts/tools && python3 -m unittest test_accent -v
"""
import importlib
import socket
import unittest
from unittest import mock

import accent
import compare
import pitch
import words


# ---------------------------------------------------------------- T1
class PatternForTest(unittest.TestCase):
    """Accent type -> H/L pattern of the word plus one following particle."""

    def test_heiban_ame_ga(self):
        self.assertEqual(accent.pattern_for(0, 2), "LHH")

    def test_atamadaka_ame(self):
        self.assertEqual(accent.pattern_for(1, 2), "HLL")

    def test_odaka_hashi_bridge(self):
        self.assertEqual(accent.pattern_for(2, 2), "LHL")

    def test_heiban_hashi_edge(self):
        self.assertEqual(accent.pattern_for(0, 2), "LHH")

    def test_atamadaka_hashi_chopsticks(self):
        self.assertEqual(accent.pattern_for(1, 2), "HLL")

    def test_nakadaka_taberu(self):
        self.assertEqual(accent.pattern_for(2, 3), "LHLL")

    def test_without_particle(self):
        self.assertEqual(accent.pattern_for(2, 3, with_particle=False), "LHL")
        self.assertEqual(accent.pattern_for(0, 3, with_particle=False), "LHH")

    def test_phrase_pattern_uses_nucleus(self):
        self.assertEqual(accent.phrase_pattern(0, 4), "LHHH")
        self.assertEqual(accent.phrase_pattern(1, 4), "HLLL")
        self.assertEqual(accent.phrase_pattern(3, 4), "LHHL")
        self.assertEqual(accent.phrase_pattern(4, 4), "LHHH")

    def test_accent_out_of_range_rejected(self):
        with self.assertRaises(ValueError):
            accent.pattern_for(3, 2)
        with self.assertRaises(ValueError):
            accent.pattern_for(-1, 2)
        with self.assertRaises(ValueError):
            accent.phrase_pattern(1, 0)

    def test_heavy_first_syllable_lets_first_mora_be_high(self):
        # Rule (see accent.py): when mora 2 is a special mora (ん, ー, っ) the first
        # syllable is heavy and the initial rise is often not realised, so the first
        # mora may be heard high. The canonical pattern stays "L..." but the first
        # position is not judged.
        self.assertTrue(accent.has_heavy_start("がっこう"))
        self.assertTrue(accent.has_heavy_start("せんせい"))
        self.assertTrue(accent.has_heavy_start("コーヒー"))
        self.assertFalse(accent.has_heavy_start("はし"))
        self.assertFalse(accent.has_heavy_start("ん"))
        self.assertEqual(accent.pattern_for(0, 4), "LHHHH")
        self.assertTrue(accent.patterns_match("LHHHH", "HHHHH", heavy_start=True))
        self.assertFalse(accent.patterns_match("LHHHH", "HHHHH", heavy_start=False))

    def test_patterns_match_wildcard_and_length(self):
        self.assertTrue(accent.patterns_match("LHHL", "LHH?"))
        self.assertTrue(accent.patterns_match("LH?L", "LHHL"))
        self.assertFalse(accent.patterns_match("LHHL", "LHHH"))
        self.assertFalse(accent.patterns_match("LHH", "LHHH"))


# ---------------------------------------------------------------- T2
class MoraCountTest(unittest.TestCase):

    def test_small_yoon_joins_previous(self):
        self.assertEqual(accent.count_morae("きょう"), 2)

    def test_sokuon_and_long_vowel(self):
        self.assertEqual(accent.count_morae("がっこう"), 4)

    def test_hatsuon(self):
        self.assertEqual(accent.count_morae("でんわばんごう"), 7)

    def test_katakana_choonpu_and_small_vowels(self):
        self.assertEqual(accent.count_morae("コーヒー"), 4)
        self.assertEqual(accent.count_morae("ファイル"), 3)

    def test_split_morae(self):
        self.assertEqual(accent.split_morae("きょうしゅっぱつ"),
                         ["きょ", "う", "しゅ", "っ", "ぱ", "つ"])

    def test_non_kana_rejected(self):
        with self.assertRaises(ValueError):
            accent.count_morae("箸")
        with self.assertRaises(ValueError):
            accent.count_morae("")
        with self.assertRaises(ValueError):
            accent.count_morae("ょう")


# ---------------------------------------------------------------- T3
def fake_query(*phrases):
    return {
        "accent_phrases": [
            {"moras": [{"text": t, "vowel": "a", "vowel_length": 0.1,
                        "consonant": None, "consonant_length": None, "pitch": p}
                       for t, p in phrase],
             "accent": 1, "pause_mora": None, "is_interrogative": False}
            for phrase in phrases
        ],
        "speedScale": 1.0,
    }


class QueryPitchTest(unittest.TestCase):
    """VOICEVOX audio query (JSON shape) -> H/L pattern from mora pitch only."""

    def test_heiban(self):
        q = fake_query([("ア", 5.50), ("メ", 5.80), ("ガ", 5.85)])
        self.assertEqual(pitch.query_patterns(q), ["LHH"])

    def test_atamadaka(self):
        q = fake_query([("ア", 5.90), ("メ", 5.60), ("ガ", 5.50)])
        self.assertEqual(pitch.query_patterns(q), ["HLL"])

    def test_nakadaka(self):
        q = fake_query([("タ", 5.50), ("ベ", 5.80), ("ル", 5.50), ("ガ", 5.40)])
        self.assertEqual(pitch.query_patterns(q), ["LHLL"])

    def test_accent_field_is_ignored(self):
        q = fake_query([("ア", 5.50), ("メ", 5.80), ("ガ", 5.85)])
        q["accent_phrases"][0]["accent"] = 1
        self.assertEqual(pitch.query_patterns(q), ["LHH"])

    def test_two_phrases(self):
        q = fake_query([("ハ", 5.90), ("シ", 5.60), ("デ", 5.50)],
                       [("タ", 5.50), ("ベ", 5.70), ("マ", 5.90), ("ス", 5.60)])
        self.assertEqual(pitch.query_patterns(q), ["HLL", "LHHL"])

    def test_interior_unvoiced_mora_is_interpolated(self):
        # 0.0 between 5.5 and 5.9 becomes 5.7: still rising, so no fall.
        self.assertEqual(pitch.interpolate_unvoiced([5.5, 0.0, 5.9, 5.9, 5.95]),
                         [5.5, 5.7, 5.9, 5.9, 5.95])
        q = fake_query([("ガ", 5.5), ("ク", 0.0), ("セ", 5.9), ("エ", 5.9), ("ガ", 5.95)])
        self.assertEqual(pitch.query_patterns(q), ["LHHHH"])

    def test_edge_unvoiced_mora_is_not_judged(self):
        # A devoiced final mora carries no pitch; it is reported as "?".
        q = fake_query([("タ", 5.5), ("ベ", 5.7), ("マ", 5.9), ("ス", 0.0)])
        self.assertEqual(pitch.query_patterns(q), ["LHH?"])
        q = fake_query([("キ", 0.0), ("ノ", 5.9), ("オ", 5.6)])
        self.assertEqual(pitch.query_patterns(q), ["?HL"])

    def test_small_step_is_not_a_fall(self):
        drop = pitch.DEFAULT_FALL_THRESHOLD / 2
        self.assertEqual(pitch.decode_nucleus([5.5, 5.9, 5.9 - drop]), 0)
        self.assertEqual(pitch.decode_nucleus([5.5, 5.9, 5.9 - 3 * drop]), 2)

    def test_first_fall_decides_nucleus(self):
        self.assertEqual(pitch.decode_nucleus([5.6, 5.9, 5.7, 5.4]), 2)
        self.assertEqual(pitch.decode_nucleus([5.9, 5.6, 5.5]), 1)

    def test_all_unvoiced_rejected(self):
        with self.assertRaises(ValueError):
            pitch.interpolate_unvoiced([0.0, 0.0])

    def test_engine_accent_field_to_nucleus(self):
        # VOICEVOX marks a flat phrase with accent == number of morae.
        self.assertEqual(pitch.phrase_nucleus(3, 3), 0)
        self.assertEqual(pitch.phrase_nucleus(2, 3), 2)
        self.assertEqual(pitch.phrase_nucleus(1, 3), 1)
        with self.assertRaises(ValueError):
            pitch.phrase_nucleus(4, 3)


# ---------------------------------------------------------------- T4
class CompareTest(unittest.TestCase):

    def test_same(self):
        self.assertEqual(compare.judge({2}, [2]), compare.MATCH)

    def test_different(self):
        self.assertEqual(compare.judge({2}, [0]), compare.MISMATCH)

    def test_several_values_one_matches(self):
        self.assertEqual(compare.judge({2}, [0, 2]), compare.MATCH_MULTI)

    def test_several_values_none_matches(self):
        self.assertEqual(compare.judge({2}, [0, 1]), compare.MISMATCH)

    def test_several_expected_values(self):
        self.assertEqual(compare.judge({2, 0}, [0]), compare.MATCH)

    def test_missing(self):
        self.assertEqual(compare.judge({2}, []), compare.MISSING)

    def test_duplicates_are_one_value(self):
        self.assertEqual(compare.judge({1}, [1, 1]), compare.MATCH)

    def test_tally_counts_each_kind(self):
        verdicts = [compare.MATCH, compare.MATCH_MULTI, compare.MISMATCH,
                    compare.MISSING, compare.MATCH]
        counts = compare.tally(verdicts)
        self.assertEqual(counts[compare.MATCH], 2)
        self.assertEqual(counts[compare.MATCH_MULTI], 1)
        self.assertEqual(counts[compare.MISMATCH], 1)
        self.assertEqual(counts[compare.MISSING], 1)
        self.assertEqual(compare.match_rate(counts), (3, 4))
        self.assertEqual(compare.coverage(counts), (4, 5))


# ---------------------------------------------------------------- T5
class OfflineAndDataTest(unittest.TestCase):

    def test_pure_modules_run_without_network(self):
        def refuse(*_args, **_kwargs):
            raise AssertionError("network used")

        with mock.patch.object(socket, "socket", refuse), \
                mock.patch.object(socket, "create_connection", refuse):
            for module in (accent, pitch, compare, words):
                importlib.reload(module)
            self.assertEqual(accent.pattern_for(1, 2), "HLL")
            self.assertEqual(pitch.query_patterns(
                fake_query([("ア", 5.9), ("メ", 5.6), ("ガ", 5.5)])), ["HLL"])
            self.assertEqual(compare.judge({0}, [0]), compare.MATCH)

    def test_parse_words_tsv(self):
        text = ("표기\t읽기\t기대\t분류\t메모\n"
                "箸\tはし\t1\t최소쌍\tchopsticks\n"
                "昨日\tきのう\t2/0\t어려움\t\n")
        rows = words.parse_words_tsv(text)
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0].surface, "箸")
        self.assertEqual(rows[0].reading, "はし")
        self.assertEqual(rows[0].expected, (1,))
        self.assertEqual(rows[1].expected, (2, 0))
        self.assertEqual(rows[1].morae, 3)

    def test_parse_words_tsv_rejects_bad_rows(self):
        with self.assertRaises(ValueError):
            words.parse_words_tsv("표기\t읽기\t기대\t분류\t메모\n箸\tはし\tx\t최소쌍\t\n")
        with self.assertRaises(ValueError):
            words.parse_words_tsv("표기\t읽기\t기대\t분류\t메모\n箸\tはし\t3\t최소쌍\t\n")

    def test_parse_kanjium_line(self):
        self.assertEqual(words.parse_kanjium_line("箸\tはし\t1"), ("箸", "はし", (1,)))
        self.assertEqual(words.parse_kanjium_line("昨日\tきのう\t2,0"), ("昨日", "きのう", (2, 0)))
        self.assertEqual(words.parse_kanjium_line("一寸\tちょっと\t(副)1,(名)0"),
                         ("一寸", "ちょっと", (1, 0)))
        self.assertEqual(words.parse_kanjium_line("何\tなに\t(名)1,(代)1"),
                         ("何", "なに", (1,)))
        with self.assertRaises(ValueError):
            words.parse_kanjium_line("broken line")

    def test_parse_unidic_atype(self):
        self.assertEqual(words.parse_atype("1"), (1,))
        self.assertEqual(words.parse_atype("2,0"), (2, 0))
        self.assertEqual(words.parse_atype("*"), ())
        self.assertEqual(words.parse_atype(""), ())


if __name__ == "__main__":
    unittest.main()
