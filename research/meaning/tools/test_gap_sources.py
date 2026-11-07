"""Tests of the pure parts of gap_sources and measure_gap (made-up words only).

    python3 -m unittest discover -s research/meaning/tools -p 'test_*.py'
"""
import unittest

from gap_sources import (
    Index,
    asset_size,
    Sense,
    build_enwikt,
    build_jawikt,
    build_kowikt,
    japanese_terms,
    korean_words,
    redirect_targets,
    ruby_reading,
    translation_words,
)
from en_pivot_rows import pivot_rows
from measure_gap import answer_words, merged


class TextTest(unittest.TestCase):
    def test_korean_gloss_splits_on_commas_and_drops_notes_and_stop(self):
        self.assertEqual(korean_words("눈숲, 설삼."), ["눈숲", "설삼"])
        self.assertEqual(korean_words("(옛말) 달빛 마을."), ["달빛 마을"])
        self.assertEqual(korean_words("눈숲; 눈숲."), ["눈숲"])

    def test_korean_gloss_without_hangul_gives_nothing(self):
        self.assertEqual(korean_words("→ abc."), [])

    def test_korean_gloss_drops_explanations_and_japanese(self):
        self.assertEqual(korean_words("눈 덮인 숲, 눈이 많이 쌓인 숲을 이르는 말."), ["눈 덮인 숲"])
        self.assertEqual(korean_words("ゆきもり 눈숲"), [])
        self.assertEqual(korean_words("어간의 하나."), [])
        self.assertEqual(korean_words("다음 단어를 만듦."), [])

    def test_translation_term_drops_leading_note_and_opens_optional_part(self):
        self.assertEqual(translation_words("(입을) 오므리다, 꾹 참다"), ["오므리다", "꾹 참다"])
        self.assertEqual(translation_words("가만히 (서다)"), ["가만히 서다"])
        self.assertEqual(translation_words("멈춰(라)"), ["멈춰라"])
        self.assertEqual(translation_words("설림(雪林)"), ["설림"])

    def test_japanese_terms_keep_only_kana_and_kanji_pieces(self):
        self.assertEqual(japanese_terms("雪森。ゆきもり、雪の森"), ["雪森", "ゆきもり", "雪の森"])
        self.assertEqual(japanese_terms("雪森 (古語)。abc"), ["雪森"])

    def test_redirect_targets_read_spelling_of_glosses(self):
        self.assertEqual(redirect_targets("ゆきもりるの漢字表記。"), ["ゆきもりる"])
        self.assertEqual(redirect_targets("「ゆきもりる」の漢字表記。"), ["ゆきもりる"])
        self.assertEqual(redirect_targets("ゆきもり、ゆきもり　参照"), ["ゆきもり", "ゆきもり"])
        self.assertEqual(redirect_targets("雪の多い森。"), [])


class RubyTest(unittest.TestCase):
    def test_ruby_over_kanji_pieces_gives_the_whole_reading(self):
        self.assertEqual(ruby_reading("雪森る", [["雪", "ゆき"], ["森", "もり"]]), "ゆきもりる")
        self.assertEqual(ruby_reading("森める", [["森", "も"]]), "もめる")
        self.assertEqual(ruby_reading("雪森", [["林", "はやし"]]), "")

    def test_old_kana_forms_are_not_readings(self):
        glossed, _ = build_kowikt([
            {"lang_code": "ja", "word": "森う", "senses": [{"glosses": ["지키다."]}],
             "forms": [{"form": "もりふ", "tags": ["archaic"]},
                       {"form": "森う", "ruby": [["森", "もり"]]}]},
        ])
        self.assertEqual([s.words for s in glossed.lookup("森う", ["もりう"])], [("지키다",)])
        self.assertEqual(glossed.lookup("森う", ["もりふ"]), [])


class IndexTest(unittest.TestCase):
    def test_reading_filters_only_senses_that_have_readings(self):
        ix = Index()
        ix.add("雪森", ["ゆきもり"], ["눈숲"])
        ix.add("雪森", ["せっしん"], ["설삼"])
        ix.add("雪森", [], ["눈 덮인 숲"])
        got = [s.words for s in ix.lookup("雪森", ["ゆきもり"])]
        self.assertEqual(got, [("눈숲",), ("눈 덮인 숲",)])
        self.assertEqual(len(ix.lookup("雪森")), 3)

    def test_keys_drop_the_glossary_endings_and_katakana(self):
        ix = Index()
        ix.add("静森だ", [], ["고요하다"])
        ix.add("ユキモリ", [], ["눈숲"])
        self.assertEqual([s.words for s in ix.lookup("静森")], [("고요하다",)])
        self.assertEqual([s.words for s in ix.lookup("ゆきもり")], [("눈숲",)])

    def test_same_sense_twice_is_kept_once(self):
        ix = Index()
        ix.add("雪森", [], ["눈숲"])
        ix.add("雪森", [], ["눈숲"])
        self.assertEqual(len(ix.lookup("雪森")), 1)


class SizeTest(unittest.TestCase):
    def test_asset_size_grows_with_rows_and_gzip_is_smaller(self):
        small, big = Index(), Index()
        small.add("雪森", ["ゆきもり"], ["눈숲"])
        for i in range(2000):
            big.add(f"雪森{i}", ["ゆきもり"], ["눈숲", "설삼"])
        self.assertEqual([r for r in small.rows()], [("雪森", "ゆきもり", "눈숲")])
        s_raw, s_gz = asset_size(small)
        b_raw, b_gz = asset_size(big)
        self.assertLess(s_raw, b_raw)
        self.assertLess(b_gz, b_raw)


class BuildTest(unittest.TestCase):
    def test_kowikt_glosses_and_korean_entries_translations(self):
        glossed, translated = build_kowikt([
            {"lang_code": "ja", "word": "雪森", "senses": [{"glosses": ["눈숲."]}],
             "forms": [{"form": "雪森", "ruby": [["雪", "ゆき"], ["森", "もり"]]}]},
            {"lang_code": "ko", "word": "눈숲",
             "translations": [{"lang_code": "ja", "word": "雪林"}]},
            {"lang_code": "ko", "word": "雪林",  # hanja spelling, no Hangul
             "translations": [{"lang_code": "ja", "word": "雪林"}]},
        ])
        self.assertEqual(glossed.lookup("雪森", ["ゆきもり"]), [Sense(("눈숲",), frozenset({"ゆきもり"}))])
        self.assertEqual(glossed.lookup("雪森", ["せっしん"]), [])
        self.assertEqual([s.words for s in translated.lookup("雪林")], [("눈숲",)])

    def test_jawikt_follows_spelling_of_entries_and_reverses_korean_glosses(self):
        translated, reverse = build_jawikt([
            {"lang_code": "ja", "word": "雪森る", "senses": [{"glosses": ["ゆきもりるの漢字表記。"]}]},
            {"lang_code": "ja", "word": "ゆきもりる", "senses": [{"glosses": ["雪で森を覆う。"]}],
             "forms": [{"form": "雪森る", "tags": ["kanji"]}],
             "translations": [{"lang_code": "ko", "word": "(숲을) 덮다", "sense": "1"},
                              {"lang_code": "ko", "word": "뒤덮다", "sense": "1"}]},
            {"lang_code": "ja", "word": "ゆきもりる", "senses": [{"glosses": ["森を守る。"]}]},
            # ゆきもりる has two entries: 霜森る (not listed) must not take 덮다
            {"lang_code": "ja", "word": "霜森る", "senses": [{"glosses": ["ゆきもりるの漢字表記。"]}]},
            # one entry only: followed though it lists no kanji
            {"lang_code": "ja", "word": "雪林", "senses": [{"glosses": ["ゆきばやし　参照"]}]},
            {"lang_code": "ja", "word": "ゆきばやし", "senses": [{"glosses": ["雪の林。"]}],
             "translations": [{"lang_code": "ko", "word": "눈숲"}]},
            {"lang_code": "ko", "word": "눈숲", "senses": [{"glosses": ["雪森。"]}]},
            {"lang_code": "ko", "word": "雪林", "senses": [{"glosses": ["雪森。"]}]},
        ])
        self.assertEqual([s.words for s in translated.lookup("雪林")], [("눈숲",)])
        self.assertEqual([s.words for s in translated.lookup("雪森る", ["ゆきもりる"])], [("덮다", "뒤덮다")])
        self.assertEqual(translated.lookup("霜森る"), [])
        self.assertEqual([s.words for s in reverse.lookup("雪森")], [("눈숲",)])

    def test_enwikt_pivot_pairs_each_japanese_term_with_the_sense_korean(self):
        ix = build_enwikt([{"word": "snowwood", "sense": "a wood under snow",
                            "ja": [{"word": "雪森", "alt": "ゆきもり"}, {"word": "雪林"}],
                            "ko": [{"word": "눈숲"}, {"word": "설림(雪林)"}]}])
        self.assertEqual(ix.lookup("雪森", ["ゆきもり"]), [Sense(("눈숲", "설림"), frozenset({"ゆきもり"}))])
        self.assertEqual(ix.lookup("雪森", ["せっしん"]), [])
        self.assertEqual(len(ix.lookup("雪林", ["せつりん"])), 1)  # no reading given: kept


class PivotRowsTest(unittest.TestCase):
    def test_rows_keep_senses_with_both_languages(self):
        entry = {"word": "snowwood", "pos": "noun", "translations": [
            {"lang_code": "ja", "word": "雪森", "sense": "a wood under snow"},
            {"lang_code": "ko", "word": "눈숲", "sense": "a wood under snow"},
            {"lang_code": "ja", "word": "雪林", "sense": "a white forest"},
            {"lang_code": "fr", "word": "neigebois", "sense": "a white forest"},
        ]}
        rows = pivot_rows(entry)
        self.assertEqual(len(rows), 1)
        self.assertEqual([j["word"] for j in rows[0]["ja"]], ["雪森"])
        self.assertEqual([k["word"] for k in rows[0]["ko"]], ["눈숲"])

    def test_sense_translations_count_too(self):
        entry = {"word": "snowwood", "senses": [{"translations": [
            {"code": "ja", "word": "雪森"}, {"code": "ko", "word": "눈숲"}]}]}
        self.assertEqual(len(pivot_rows(entry)), 1)


class MeasureTest(unittest.TestCase):
    def test_answer_words_split_like_the_scorer(self):
        self.assertEqual(answer_words("(옛말) 눈숲, 눈 덮인 숲"), {"눈숲", "눈덮인숲"})

    def test_fill_uses_a_source_only_when_the_glossary_is_empty(self):
        extra = [Sense(("눈숲",), frozenset())]
        self.assertEqual(merged([["설삼"]], extra, "fill"), [("설삼",)])
        self.assertEqual(merged([], extra, "fill"), [("눈숲",)])

    def test_chips_add_new_words_after_the_glossary_up_to_five(self):
        glossary = [["가"], ["나"], ["다"], ["라"]]
        extra = [Sense(("가", "마"), frozenset()), Sense(("바",), frozenset())]
        self.assertEqual(merged(glossary, extra, "chips"), [("가",), ("나",), ("다",), ("라",), ("마",)])


if __name__ == "__main__":
    unittest.main()
