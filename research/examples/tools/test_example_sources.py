"""Unit tests for the pure parts (made-up words only)."""
from __future__ import annotations

import io
import unittest

from example_sources import (BAD_TAGS, Entry, EntryIndex, Example, clean_korean,
                             is_card_sentence, parse_bline, parse_indices_row, parse_jmdict,
                             parse_sentence_row, pick, reading_agrees, strip_inline_ruby,
                             wikt_examples)


class BLineTest(unittest.TestCase):
    def test_every_part(self):
        words = parse_bline("雪森(ゆきもり)[02]{雪森を}~ を 歩く{歩いた}")
        self.assertEqual([(w.headword, w.reading, w.surface, w.checked) for w in words], [
            ("雪森", "ゆきもり", "雪森を", True),
            ("を", None, None, False),
            ("歩く", None, "歩いた", False),
        ])

    def test_entry_number_in_the_reading_slot(self):
        (w,) = parse_bline("が(#9100001)")
        self.assertEqual((w.headword, w.reading), ("が", "#9100001"))

    def test_malformed_token_is_skipped(self):
        self.assertEqual([w.headword for w in parse_bline("月道 {壊れ 星波")], ["月道", "星波"])

    def test_indices_row(self):
        sid, words = parse_indices_row("12\t34\t雪森 を 見る\n")
        self.assertEqual((sid, [w.headword for w in words]), ("12", ["雪森", "を", "見る"]))
        self.assertIsNone(parse_indices_row("x\t1\t雪森"))
        self.assertIsNone(parse_indices_row("12\t雪森"))


class SentenceRowTest(unittest.TestCase):
    def test_detailed_row(self):
        self.assertEqual(parse_sentence_row("7\tjpn\t雪森へ行く。\tsomeone\t\\N\t2020\n"),
                         ("7", "jpn", "雪森へ行く。", "someone"))

    def test_no_user(self):
        self.assertEqual(parse_sentence_row("7\tjpn\t雪森へ行く。\t\\N\n")[3], None)

    def test_not_a_row(self):
        self.assertIsNone(parse_sentence_row("id\tlang\ttext"))


class TextTest(unittest.TestCase):
    def test_card_sentence(self):
        self.assertTrue(is_card_sentence("雪森へ歩いて行きます。"))
        self.assertFalse(is_card_sentence("雪森"))                      # too short
        self.assertFalse(is_card_sentence("雪森" * 20 + "です。"))       # too long
        self.assertFalse(is_card_sentence("雪森へ行く 설산에 가다"))      # Korean inside
        self.assertFalse(is_card_sentence("雪森へ行く (yukimori)"))      # Latin inside
        self.assertFalse(is_card_sentence("雪森、月道、星波、風路"))      # no kana
        self.assertFalse(is_card_sentence("雪森を見る / 月道を見る"))     # a list
        self.assertFalse(is_card_sentence("雪森^(ゆきもり)の道です"))     # markup

    def test_inline_ruby(self):
        self.assertEqual(strip_inline_ruby("雪森(ゆきもり)へ行(い)く。"), "雪森へ行く。")
        self.assertEqual(strip_inline_ruby("(注)ゆきもり"), "(注)ゆきもり")

    def test_clean_korean(self):
        self.assertEqual(clean_korean("- 눈숲에 가다."), "눈숲에 가다.")
        self.assertEqual(clean_korean("(눈숲에 가다.)"), "눈숲에 가다.")
        self.assertIsNone(clean_korean(None))
        self.assertIsNone(clean_korean(" - "))

    def test_reading_agrees(self):
        self.assertTrue(reading_agrees(None, ["ゆきもり"]))
        self.assertTrue(reading_agrees("ゆきもり", []))
        self.assertTrue(reading_agrees("ぽるいた", ["ぽるく"]))     # inflected ending
        self.assertFalse(reading_agrees("つきもり", ["ゆきもり"]))
        self.assertTrue(reading_agrees("雪森を", ["ゆきもり"]))     # not kana: unknown
        self.assertTrue(reading_agrees("ポルク", ["ぽるく"]))       # katakana spelling
        self.assertFalse(reading_agrees("ツキモリ", ["ゆきもり"]))


class WiktTest(unittest.TestCase):
    def _entry(self, examples, lang="ja"):
        return {"word": "雪森", "lang_code": lang, "senses": [{"examples": examples}]}

    def test_korean_edition_keeps_the_korean(self):
        (ex,) = wikt_examples("kowikt", self._entry([
            {"text": "雪森(ゆきもり)へ行く。", "translation": "- 눈숲에 간다."}]))
        self.assertEqual((ex.ja, ex.ko, ex.en, ex.ko_direct), ("雪森へ行く。", "눈숲에 간다.", None, True))

    def test_english_edition_keeps_the_english(self):
        (ex,) = wikt_examples("enwikt", self._entry([
            {"text": "雪森へ行く。", "english": "I go to Yukimori."}]))
        self.assertEqual((ex.ko, ex.en), (None, "I go to Yukimori."))

    def test_quotations_and_empty_text_are_left_out(self):
        exs = wikt_examples("jawikt", self._entry([
            {"text": "雪森へ行く。", "type": "quotation"},
            {"text": "雪森へ行く。", "ref": "某書"},
            {"translation": "雪森へ行く。"},
            {"text": "雪森を見た。"},
        ]))
        self.assertEqual([e.ja for e in exs], ["雪森を見た。"])
        self.assertIsNone(exs[0].ko)

    def test_other_languages_are_ignored(self):
        self.assertEqual(wikt_examples("kowikt", self._entry([{"text": "雪森へ行く。"}], "ko")), [])


_XML = """<?xml version="1.0"?>
<!DOCTYPE JMdict [<!ENTITY uk "word usually written using kana alone">]>
<JMdict>
<entry><ent_seq>9100001</ent_seq>
<k_ele><keb>雪森</keb></k_ele><r_ele><reb>ゆきもり</reb><re_pri>ichi1</re_pri></r_ele>
<sense><gloss>snow wood</gloss>
<example><ex_srce exsrc_type="tat">42</ex_srce><ex_text>雪森</ex_text>
<ex_sent xml:lang="jpn">雪森へ行く。</ex_sent><ex_sent xml:lang="eng">I go to the snow wood.</ex_sent>
</example></sense></entry>
<entry><ent_seq>9100002</ent_seq>
<k_ele><keb>穂留</keb></k_ele><r_ele><reb>ぽる</reb></r_ele>
<sense><misc>&uk;</misc><gloss>x</gloss></sense></entry>
</JMdict>"""


class JmdictTest(unittest.TestCase):
    def test_entries_and_examples(self):
        rows = list(parse_jmdict(io.BytesIO(_XML.encode())))
        (e1, exs1), (e2, exs2) = rows
        self.assertEqual((e1.seq, e1.kanji, e1.readings, e1.common_readings, e1.usually_kana),
                         ("9100001", ("雪森",), ("ゆきもり",), ("ゆきもり",), False))
        self.assertEqual([(x.ja, x.en, x.ref, x.checked) for x in exs1],
                         [("雪森へ行く。", "I go to the snow wood.", "42", True)])
        self.assertTrue(e2.usually_kana)
        self.assertEqual(exs2, [])


class EntryIndexTest(unittest.TestCase):
    def setUp(self):
        self.idx = EntryIndex([
            Entry("1", ("雪森",), ("ゆきもり",), common_readings=("ゆきもり",)),
            Entry("2", ("雪森",), ("せつしん",)),
            Entry("3", (), ("ぽる",)),                                  # kana only, rare
            Entry("4", ("穂留",), ("ぽる",), usually_kana=True, common_readings=("ぽる",)),
            Entry("5", ("帆流",), ("ぽる",), common_readings=("ぽる",)),
            Entry("6", ("月道",), ("つきみち",)),
            Entry("7", ("槻道",), ("つきみち",)),
        ])

    def seqs(self, form, readings=()):
        return [e.seq for e in self.idx.lookup(form, readings)]

    def test_kanji_form_narrowed_by_reading(self):
        self.assertEqual(self.seqs("雪森"), ["1", "2"])
        self.assertEqual(self.seqs("雪森", ["せつしん"]), ["2"])
        self.assertEqual(self.seqs("雪森", ["どこにもない"]), ["1", "2"])  # nothing kept: all

    def test_kana_form_prefers_the_word_written_in_kana(self):
        # usually-kana with a common reading beats a rare kana-only entry
        self.assertEqual(self.seqs("ぽる"), ["4"])

    def test_kana_form_without_any_preference_keeps_all(self):
        self.assertEqual(self.seqs("つきみち"), ["6", "7"])

    def test_kana_only_common_entry_comes_first(self):
        idx = EntryIndex([Entry("8", (), ("ね",), common_readings=("ね",)),
                          Entry("9", ("音",), ("ね",), usually_kana=True, common_readings=("ね",))])
        self.assertEqual([e.seq for e in idx.lookup("ね")], ["8"])

    def test_by_seq(self):
        self.assertEqual([e.seq for e in self.idx.by_seq("6")], ["6"])
        self.assertEqual(self.idx.by_seq("0"), [])


class PickTest(unittest.TestCase):
    def ex(self, ja, **kw):
        return Example("tatoeba", "雪森", ja, **kw)

    def test_order(self):
        plain = self.ex("雪森へ行きました。")
        checked = self.ex("雪森へ歩いて行く。", checked=True)
        pivot = self.ex("雪森が見えます。", ko="눈숲이 보입니다.")
        direct = self.ex("雪森は遠いです。", ko="눈숲은 멉니다.", ko_direct=True)
        got = pick([plain, pivot, checked, direct], known_kanji={"雪", "森", "行", "歩", "見", "遠"}, n=4)
        self.assertEqual(got, [direct, checked, pivot, plain])

    def test_unknown_kanji_then_length(self):
        hard = self.ex("雪森で鬱蒼と茂る。")
        easy = self.ex("雪森へ行きます。")
        self.assertEqual(pick([hard, easy], known_kanji={"雪", "森", "行"}, n=1), [easy])

    def test_unusable_are_left_out(self):
        tagged = self.ex("雪森へ行きました。", tags=frozenset({next(iter(BAD_TAGS))}))
        sensitive = self.ex("雪森で人を殺した。")
        short = self.ex("雪森")
        self.assertEqual(pick([tagged, sensitive, short], known_kanji=set()), [])

    def test_one_per_sentence(self):
        a = self.ex("雪森へ行きました。")
        b = Example("tatoeba", "行く", "雪森へ行きました。")
        self.assertEqual(len(pick([a, b], known_kanji=set())), 1)


if __name__ == "__main__":
    unittest.main()
