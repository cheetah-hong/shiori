"""B1, F1, F3, F4, F6, F7: build_decks.py on a made-up word list and a made-up JMdict (no network).

  python3 -m unittest discover -s tools/decks -p 'test_*.py'
"""
from __future__ import annotations

import contextlib
import gzip
import hashlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import build_decks  # noqa: E402

# The private folder's tables (lookup overrides) are never the real ones here.
_PRIVATE = tempfile.TemporaryDirectory()
os.environ["SHIORI_PRIVATE_DIR"] = _PRIVATE.name

BUILT_ON = "2026-11-13"
COMMIT = "0123456789abcdef0123456789abcdef01234567"

# A JMdict with the entities and header comment the real file has.
JMDICT = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE JMdict [
<!ELEMENT JMdict (entry*)>
<!ENTITY uk "word usually written using kana alone">
<!ENTITY n "noun (common) (futsuumeishi)">
<!ENTITY adv "adverb (fukushi)">
]>
<!-- JMdict created: 2026-11-06 -->
<JMdict>
<entry><ent_seq>9000001</ent_seq>
 <k_ele><keb>雨傘</keb><ke_pri>news1</ke_pri><ke_pri>nf20</ke_pri></k_ele>
 <r_ele><reb>あまがさ</reb><re_pri>news1</re_pri><re_pri>nf20</re_pri></r_ele>
 <sense><pos>&n;</pos><gloss>umbrella</gloss></sense></entry>
<entry><ent_seq>9000002</ent_seq>
 <r_ele><reb>ぽかぽか</reb></r_ele>
 <sense><pos>&adv;</pos><gloss>pleasantly warm</gloss></sense></entry>
<entry><ent_seq>9000003</ent_seq>
 <k_ele><keb>此の</keb></k_ele>
 <r_ele><reb>この</reb><re_pri>ichi1</re_pri><re_pri>nf01</re_pri></r_ele>
 <sense><pos>&n;</pos><misc>&uk;</misc><gloss>this</gloss></sense></entry>
<entry><ent_seq>9000004</ent_seq>
 <k_ele><keb>戸締まり</keb><ke_pri>ichi1</ke_pri></k_ele>
 <k_ele><keb>戸締り</keb></k_ele>
 <r_ele><reb>とじまり</reb><re_pri>ichi1</re_pri></r_ele>
 <sense><pos>&n;</pos><gloss>locking up</gloss></sense></entry>
<entry><ent_seq>9000005</ent_seq>
 <k_ele><keb>戦</keb><ke_pri>news1</ke_pri></k_ele>
 <k_ele><keb>軍</keb></k_ele>
 <r_ele><reb>いくさ</reb><re_pri>news1</re_pri></r_ele>
 <sense><pos>&n;</pos><gloss>war</gloss></sense></entry>
<entry><ent_seq>9000006</ent_seq>
 <k_ele><keb>大変</keb><ke_pri>ichi1</ke_pri><ke_pri>nf02</ke_pri></k_ele>
 <r_ele><reb>たいへん</reb><re_pri>ichi1</re_pri><re_pri>nf02</re_pri></r_ele>
 <sense><pos>&adv;</pos><gloss>very</gloss></sense></entry>
<entry><ent_seq>9000007</ent_seq>
 <k_ele><keb>夕凪</keb></k_ele>
 <r_ele><reb>ゆうなぎ</reb></r_ele>
 <sense><pos>&n;</pos><gloss>evening calm</gloss></sense></entry>
<entry><ent_seq>9000008</ent_seq>
 <r_ele><reb>カメラ</reb><re_pri>gai1</re_pri><re_pri>nf10</re_pri></r_ele>
 <sense><pos>&n;</pos><gloss>camera</gloss></sense></entry>
<entry><ent_seq>9000009</ent_seq>
 <k_ele><keb>小道</keb><ke_pri>news2</ke_pri></k_ele>
 <r_ele><reb>こみち</reb></r_ele>
 <sense><pos>&n;</pos><gloss>path</gloss></sense></entry>
<entry><ent_seq>9000011</ent_seq>
 <k_ele><keb>夕焼け</keb></k_ele>
 <r_ele><reb>ゆうやけ</reb></r_ele>
 <sense><pos>&n;</pos><gloss>sunset</gloss></sense></entry>
<entry><ent_seq>9000010</ent_seq>
 <k_ele><keb>風車</keb></k_ele>
 <r_ele><reb>かざぐるま</reb></r_ele>
 <sense><pos>&n;</pos><gloss>pinwheel</gloss></sense></entry>
<entry><ent_seq>9000012</ent_seq>
 <k_ele><keb>雨雲</keb><ke_pri>ichi1</ke_pri></k_ele>
 <r_ele><reb>あまぐも</reb><re_pri>ichi1</re_pri></r_ele>
 <sense><pos>&n;</pos><gloss>rain cloud</gloss></sense></entry>
<entry><ent_seq>9000013</ent_seq>
 <k_ele><keb>皆</keb><ke_pri>ichi1</ke_pri></k_ele>
 <r_ele><reb>みんな</reb><re_pri>ichi1</re_pri></r_ele>
 <r_ele><reb>みな</reb><re_pri>ichi1</re_pri></r_ele>
 <sense><pos>&n;</pos><gloss>everyone</gloss></sense></entry>
<entry><ent_seq>9000014</ent_seq>
 <k_ele><keb>何時も</keb><ke_pri>ichi1</ke_pri></k_ele>
 <r_ele><reb>いつも</reb><re_pri>ichi1</re_pri></r_ele>
 <sense><pos>&adv;</pos><misc>&uk;</misc><gloss>always</gloss></sense></entry>
<entry><ent_seq>9000015</ent_seq>
 <k_ele><keb>早い</keb><ke_pri>ichi1</ke_pri></k_ele>
 <k_ele><keb>速い</keb><ke_pri>ichi1</ke_pri></k_ele>
 <r_ele><reb>はやい</reb><re_pri>ichi1</re_pri></r_ele>
 <sense><pos>&n;</pos><gloss>fast</gloss></sense></entry>
<entry><ent_seq>9000016</ent_seq>
 <k_ele><keb>分かる</keb><ke_pri>ichi1</ke_pri></k_ele>
 <r_ele><reb>わかる</reb><re_pri>ichi1</re_pri></r_ele>
 <sense><pos>&n;</pos><gloss>to understand</gloss></sense></entry>
<entry><ent_seq>9000017</ent_seq>
 <k_ele><keb>綺麗</keb><ke_pri>ichi1</ke_pri></k_ele>
 <r_ele><reb>きれい</reb><re_pri>ichi1</re_pri></r_ele>
 <sense><pos>&n;</pos><gloss>pretty</gloss></sense></entry>
<entry><ent_seq>9000018</ent_seq>
 <k_ele><keb>宜しい</keb><ke_pri>ichi1</ke_pri></k_ele>
 <k_ele><keb>好しい</keb><ke_pri>ichi1</ke_pri></k_ele>
 <r_ele><reb>よろしい</reb><re_pri>ichi1</re_pri></r_ele>
 <sense><pos>&n;</pos><gloss>good</gloss></sense></entry>
</JMdict>
"""

# Made-up lists in the source's columns: jmdict_seq,kana,kanji,waller_definition.
LISTS = {
    "n5": [
        ("9000009", "こみち", "小道", "path"),          # no nf, not common → last
        ("9000001", "あまがさ", "雨傘", "umbrella"),     # nf20
        ("9000002", "ぽかぽか", "", "warm"),             # printed kana, no nf
        ("9000006", "たいへん", "", "very"),             # printed kana, common kanji 大変, nf02
        ("", "い", "依", "reliance"),                    # no entry: left out
        ("9000001", "あまがさ", "雨傘", "umbrella"),     # twice in a level
    ],
    "n4": [
        ("9000003", "この", "此の", "this"),             # rare kanji, usually kana → この
        ("9000004", "とじまり", "戸締り", "locking"),    # rare, same kanji common → 戸締まり
        ("9000005", "いくさ", "軍", "war"),              # rare, the common one has other kanji → 軍
        ("9000001", "あまがさ", "雨傘", "umbrella"),     # in N5 already
        ("9999999", "なにか", "何か", "something"),      # entry not in JMdict: left out
    ],
    "n3": [
        ("9000007", "ゆうなぎ", "夕凪", "evening calm"),
        ("9000008", "カメラ", "", "camera"),
    ],
    "n2": [
        ("9000002", "ぽかぽか", "", "warm"),             # in N5 already
        ("9000010", "かざぐるま", "風車", "pinwheel"),
    ],
    "n1": [
        ("9000005", "いくさ", "戦", "war"),              # another spelling of an N4 word: left out
        ("9000011", "ゆうやけ", "夕焼け", "sunset"),
    ],
}

SUPPLEMENT_HEAD = "level\tentry\theadword\tmeaning\treviewed\n"
SUPPLEMENT = SUPPLEMENT_HEAD + "N3\t9000007\t夕凪\t저녁뜸\t검수자 11/13\n"

# F3: words an easier level shows in kana and a harder one in kanji (same entry).
KANJI_AGAIN = {
    "n5": [
        ("9000012", "あまぐも", "", "rain cloud"),
        ("9000013", "みんな", "", "everyone"),
        ("9000014", "いつも", "", "always"),
        ("9000015", "はやい", "早い", "fast"),
        ("9000016", "わかる", "分かる", "to understand"),
    ],
    "n4": [
        ("9000017", "きれい", "", "pretty"),
        ("9000017", "きれい", "綺麗", "pretty"),          # kanji in the same level: left out
        ("9000018", "よろしい", "", "good"),
    ],
    "n3": [
        ("9000013", "みな", "皆", "everyone"),           # another reading: kept as read
        ("9000014", "いつも", "何時も", "always"),
        ("9000016", "わかる", "", "to understand"),      # kanji first, kana again: left out
    ],
    "n2": [
        ("9000018", "よろしい", "宜しい", "good"),
        ("9000015", "はやい", "速い", "fast"),           # other kanji: left out
    ],
    "n1": [
        ("9000012", "あまぐも", "雨雲", "rain cloud"),
        ("9000014", "いつも", "何時も", "always"),       # its kanji came already: left out
        ("9000018", "よろしい", "好しい", "good"),       # the entry's kanji came already: left out
    ],
}


def write_inputs(root: Path, lists=LISTS, supplement=SUPPLEMENT) -> dict[str, Path]:
    src = root / "original_data"
    src.mkdir(parents=True, exist_ok=True)
    for name, rows in lists.items():
        lines = ["jmdict_seq,kana,kanji,waller_definition"]
        lines += [",".join(r) for r in rows]
        (src / f"{name}.csv").write_text("\n".join(lines) + "\n", encoding="utf-8")
    jm = root / "JMdict_e.gz"
    with gzip.GzipFile(jm, "wb", mtime=0) as f:
        f.write(JMDICT.encode("utf-8"))
    sup = root / "supplement.tsv"
    sup.write_text(supplement, encoding="utf-8")
    return {"source": src, "jmdict": jm, "supplement": sup}


def run(argv: list[str]) -> tuple[int, str]:
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        try:
            code = build_decks.main(argv)
        except SystemExit as e:
            code = e.code if isinstance(e.code, int) else 1
    return code, out.getvalue()


class BuildTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.inputs = write_inputs(self.tmp / "in")
        self.out = self.tmp / "out"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def build(self, out: Path | None = None, extra: list[str] | None = None) -> tuple[int, str]:
        return run([
            "--source", str(self.inputs["source"]), "--source-commit", COMMIT,
            "--jmdict", str(self.inputs["jmdict"]),
            "--supplement", str(self.inputs["supplement"]),
            "--built-on", BUILT_ON, "--out-dir", str(out or self.out), *(extra or []),
        ])

    def doc(self) -> dict:
        return json.loads((self.out / build_decks.DECKS_NAME).read_text(encoding="utf-8"))

    def edition(self) -> dict:
        return json.loads((self.out / build_decks.EDITION_NAME).read_text(encoding="utf-8"))

    def words(self, level: str) -> list[dict]:
        return next(d for d in self.doc()["decks"] if d["level"] == level)["words"]

    def test_same_inputs_same_bytes(self) -> None:
        self.assertEqual(self.build()[0], 0)
        other = self.tmp / "out2"
        self.assertEqual(self.build(out=other)[0], 0)
        for name in (build_decks.DECKS_NAME, build_decks.EDITION_NAME):
            self.assertEqual((self.out / name).read_bytes(), (other / name).read_bytes(), name)

    def test_document_header_and_decks(self) -> None:
        self.build()
        doc = self.doc()
        self.assertEqual(doc["format"], "shiori-decks")
        self.assertEqual(doc["version"], 1)
        self.assertEqual(doc["edition"], BUILT_ON)
        self.assertEqual([d["level"] for d in doc["decks"]], ["N5", "N4", "N3", "N2", "N1"])
        self.assertEqual([d["id"] for d in doc["decks"]], ["jlpt-n5", "jlpt-n4", "jlpt-n3", "jlpt-n2", "jlpt-n1"])
        self.assertEqual([d["name"] for d in doc["decks"]], [f"JLPT {lv} 대비" for lv in ("N5", "N4", "N3", "N2", "N1")])
        authors = [s["author"] for s in doc["sources"]]
        self.assertEqual(authors, ["Jonathan Waller", "Stephen Kraus"])
        self.assertEqual([s["license"] for s in doc["sources"]], ["CC BY", "CC BY-SA 4.0"])
        self.assertNotIn("공식", json.dumps(doc, ensure_ascii=False))

    def test_shown_spelling_rules(self) -> None:
        self.build()
        n4 = {w["e"]: w for w in self.words("N4")}
        self.assertEqual(n4[9000003]["h"], "この")       # rare kanji, usually kana
        self.assertEqual(n4[9000004]["h"], "戸締まり")   # same kanji, common spelling
        self.assertEqual(n4[9000005]["h"], "軍")         # not to other kanji
        n5 = {w["e"]: w for w in self.words("N5")}
        self.assertEqual(n5[9000001]["h"], "雨傘")       # common kanji stays
        self.assertEqual(n5[9000002]["h"], "ぽかぽか")   # kana stays
        self.assertEqual(n5[9000006]["h"], "たいへん")   # kana stays though kanji is common
        self.assertEqual(n5[9000001]["r"], "あまがさ")
        self.assertEqual(n4[9000003]["r"], "この")

    def test_lookup_spelling_only_when_it_differs(self) -> None:
        self.build()
        n5 = {w["e"]: w for w in self.words("N5")}
        self.assertEqual(n5[9000006]["l"], "大変")
        self.assertNotIn("l", n5[9000001])
        self.assertNotIn("l", n5[9000002])
        n4 = {w["e"]: w for w in self.words("N4")}
        self.assertNotIn("l", n4[9000005])               # 軍 shown; 戦 is another word's kanji
        self.assertNotIn("l", n4[9000003])

    def test_each_word_once_in_its_easiest_level(self) -> None:
        self.build()
        self.assertEqual(sorted(w["e"] for w in self.words("N5")), [9000001, 9000002, 9000006, 9000009])
        self.assertNotIn(9000001, [w["e"] for w in self.words("N4")])
        self.assertEqual([w["h"] for w in self.words("N2")], ["風車"])
        # 戦 is the entry of N4's 軍: one word per entry too.
        self.assertEqual([w["h"] for w in self.words("N1")], ["夕焼け"])

    def test_order_by_frequency_then_common_then_list(self) -> None:
        self.build()
        self.assertEqual([w["h"] for w in self.words("N5")], ["たいへん", "雨傘", "小道", "ぽかぽか"])

    def test_left_out_rows_are_counted(self) -> None:
        self.build()
        ed = self.edition()
        self.assertEqual(ed["counts"], {"N5": 4, "N4": 3, "N3": 2, "N2": 1, "N1": 1})
        self.assertEqual(ed["left_out"], {"no_entry": 1, "not_in_jmdict": 1, "duplicate": 4})

    def test_supplement_meaning_on_its_word(self) -> None:
        self.build()
        n3 = {w["e"]: w for w in self.words("N3")}
        self.assertEqual(n3[9000007]["m"], "저녁뜸")
        self.assertNotIn("m", n3[9000008])

    def test_supplement_row_without_its_word_stops(self) -> None:
        write_inputs(self.tmp / "in", supplement=SUPPLEMENT + "N3\t9000008\tカメラX\t카메라\n")
        code, out = self.build()
        self.assertNotEqual(code, 0)
        self.assertIn("supplement", out)

    def test_edition_records_inputs_and_output(self) -> None:
        self.build()
        ed = self.edition()
        raw = (self.out / build_decks.DECKS_NAME).read_bytes()
        self.assertEqual(ed["json_sha256"], hashlib.sha256(raw).hexdigest())
        self.assertEqual(ed["json_bytes"], len(raw))
        self.assertEqual(ed["built_on"], BUILT_ON)
        self.assertEqual(ed["source"]["commit"], COMMIT)
        self.assertEqual(
            ed["source"]["files"]["n5"],
            hashlib.sha256((self.inputs["source"] / "n5.csv").read_bytes()).hexdigest(),
        )
        self.assertEqual(ed["jmdict"]["created"], "2026-11-06")
        self.assertEqual(
            ed["jmdict"]["source_sha256"],
            hashlib.sha256(self.inputs["jmdict"].read_bytes()).hexdigest(),
        )
        self.assertEqual(
            ed["supplement_sha256"],
            hashlib.sha256(self.inputs["supplement"].read_bytes()).hexdigest(),
        )

    def test_wrong_input_hash_stops(self) -> None:
        code, out = self.build(extra=["--expect-sha256", "n5=" + "0" * 64])
        self.assertNotEqual(code, 0)
        self.assertIn("n5", out)
        code, out = self.build(extra=["--expect-jmdict-sha256", "0" * 64])
        self.assertNotEqual(code, 0)
        self.assertFalse((self.out / build_decks.DECKS_NAME).exists())

    def test_right_input_hash_builds(self) -> None:
        sha = hashlib.sha256((self.inputs["source"] / "n5.csv").read_bytes()).hexdigest()
        jm = hashlib.sha256(self.inputs["jmdict"].read_bytes()).hexdigest()
        code, _ = self.build(extra=["--expect-sha256", f"n5={sha}", "--expect-jmdict-sha256", jm])
        self.assertEqual(code, 0)

    def test_check_passes_on_a_fresh_build(self) -> None:
        self.build()
        code, out = run(["--check", "--out-dir", str(self.out)])
        self.assertEqual(code, 0, out)

    def test_check_fails_on_a_changed_file(self) -> None:
        self.build()
        path = self.out / build_decks.DECKS_NAME
        path.write_text(path.read_text(encoding="utf-8").replace("雨傘", "雨笠"), encoding="utf-8")
        code, out = run(["--check", "--out-dir", str(self.out)])
        self.assertNotEqual(code, 0)
        self.assertIn("sha256", out)

    def test_check_fails_when_counts_disagree(self) -> None:
        self.build()
        ed_path = self.out / build_decks.EDITION_NAME
        ed = json.loads(ed_path.read_text(encoding="utf-8"))
        ed["counts"]["N5"] = 5
        ed_path.write_text(json.dumps(ed), encoding="utf-8")
        code, out = run(["--check", "--out-dir", str(self.out)])
        self.assertNotEqual(code, 0)
        self.assertIn("N5", out)

    def test_check_fails_without_files(self) -> None:
        code, out = run(["--check", "--out-dir", str(self.tmp / "nothing")])
        self.assertNotEqual(code, 0)
        self.assertIn("build_decks.py", out)

    def test_word_key_matches_the_app(self) -> None:
        self.assertEqual(build_decks.word_key(" 丈夫だ "), "丈夫")
        self.assertEqual(build_decks.word_key("まだ"), "まだ")
        self.assertEqual(build_decks.word_key("ＡＢＣ"), "ABC")
        self.assertEqual(build_decks.word_key("小 道"), "小道")


class KanjiAgainTest(unittest.TestCase):
    """F3: a word first shown in kana comes back once in kanji in a harder level."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.inputs = write_inputs(self.tmp / "in", lists=KANJI_AGAIN, supplement=SUPPLEMENT_HEAD)
        self.out = self.tmp / "out"
        code, out = run([
            "--source", str(self.inputs["source"]), "--source-commit", COMMIT,
            "--jmdict", str(self.inputs["jmdict"]), "--supplement", str(self.inputs["supplement"]),
            "--built-on", BUILT_ON, "--out-dir", str(self.out),
        ])
        self.assertEqual(code, 0, out)
        self.doc = json.loads((self.out / build_decks.DECKS_NAME).read_text(encoding="utf-8"))
        self.edition = json.loads((self.out / build_decks.EDITION_NAME).read_text(encoding="utf-8"))

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def heads(self, level: str) -> list[str]:
        words = next(d for d in self.doc["decks"] if d["level"] == level)["words"]
        return sorted(w["h"] for w in words)

    def test_kanji_comes_back_in_the_harder_level(self) -> None:
        self.assertEqual(self.heads("N5"), sorted(["あまぐも", "みんな", "いつも", "早い", "分かる"]))
        self.assertEqual(self.heads("N1"), ["雨雲"])
        n1 = next(d for d in self.doc["decks"] if d["level"] == "N1")["words"]
        self.assertEqual(n1, [{"h": "雨雲", "r": "あまぐも", "e": 9000012}])

    def test_another_reading_is_kept_as_read(self) -> None:
        n3 = {w["h"]: w for w in next(d for d in self.doc["decks"] if d["level"] == "N3")["words"]}
        self.assertEqual(n3["皆"]["r"], "みな")
        self.assertEqual(sorted(n3), ["何時も", "皆"])

    def test_once_per_entry_and_never_in_the_same_level(self) -> None:
        self.assertEqual(self.heads("N4"), ["きれい", "よろしい"])
        self.assertEqual(self.heads("N2"), ["宜しい"])

    def test_other_kanji_and_kana_again_stay_out(self) -> None:
        all_heads = [h for lv in build_decks.LEVELS for h in self.heads(lv)]
        for left in ("速い", "わかる", "綺麗", "好しい"):
            self.assertNotIn(left, all_heads)
        self.assertEqual(len(all_heads), len({build_decks.word_key(h) for h in all_heads}))

    def test_edition_counts_them(self) -> None:
        self.assertEqual(self.edition["kanji_again"], 4)
        self.assertEqual(self.edition["left_out"]["duplicate"], 5)
        self.assertEqual(self.edition["counts"], {"N5": 5, "N4": 2, "N3": 2, "N2": 1, "N1": 1})


class SupplementTest(unittest.TestCase):
    """F4: the supplement table's rows."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def build(self, supplement: str) -> tuple[int, str, Path]:
        inputs = write_inputs(self.tmp / "in", supplement=supplement)
        out = self.tmp / "out"
        code, text = run([
            "--source", str(inputs["source"]), "--source-commit", COMMIT,
            "--jmdict", str(inputs["jmdict"]), "--supplement", str(inputs["supplement"]),
            "--built-on", BUILT_ON, "--out-dir", str(out),
        ])
        return code, text, out

    def test_a_reviewed_row_goes_in(self) -> None:
        code, text, out = self.build(SUPPLEMENT)
        self.assertEqual(code, 0, text)
        self.assertEqual(json.loads((out / build_decks.EDITION_NAME).read_text(encoding="utf-8"))["supplement_rows"], 1)

    def test_a_row_not_reviewed_stops_the_build(self) -> None:
        code, text, out = self.build(SUPPLEMENT_HEAD + "N3\t9000007\t夕凪\t저녁뜸\t\n")
        self.assertNotEqual(code, 0)
        self.assertIn("reviewed", text)
        self.assertFalse((out / build_decks.DECKS_NAME).exists())

    def test_a_table_without_the_reviewed_column_stops_the_build(self) -> None:
        code, text, _ = self.build("level\tentry\theadword\tmeaning\nN3\t9000007\t夕凪\t저녁뜸\n")
        self.assertNotEqual(code, 0)
        self.assertIn("reviewed", text)

    def test_a_row_twice_stops_the_build(self) -> None:
        code, text, _ = self.build(SUPPLEMENT + "N3\t9000007\t夕凪\t저녁 바람\t검수자 11/13\n")
        self.assertNotEqual(code, 0)
        self.assertIn("twice", text)

    def test_a_row_without_a_meaning_stops_the_build(self) -> None:
        code, text, _ = self.build(SUPPLEMENT_HEAD + "N3\t9000007\t夕凪\t \t검수자 11/13\n")
        self.assertNotEqual(code, 0)
        self.assertIn("meaning", text)

    def test_other_columns_are_left_alone(self) -> None:
        code, text, _ = self.build(
            "level\tentry\theadword\treading\tmeaning\treviewed\tnote\n"
            "N3\t9000007\t夕凪\tゆうなぎ\t저녁뜸\t검수자 11/13\t메모\n")
        self.assertEqual(code, 0, text)


OVERRIDES_HEAD = "level\tentry\theadword\tlookup\treviewed\n"


class LookupOverrideTest(unittest.TestCase):
    """F6: a reviewed table sets the spelling a word's meaning is asked under first."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.inputs = write_inputs(self.tmp / "in")
        self.table = self.tmp / "in" / "lookup-overrides.tsv"
        self.out = self.tmp / "out"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def build(self, table: str | None) -> tuple[int, str]:
        if table is not None:
            self.table.write_text(table, encoding="utf-8")
        return run([
            "--source", str(self.inputs["source"]), "--source-commit", COMMIT,
            "--jmdict", str(self.inputs["jmdict"]), "--supplement", str(self.inputs["supplement"]),
            "--lookup-overrides", str(self.table),
            "--built-on", BUILT_ON, "--out-dir", str(self.out),
        ])

    def word(self, level: str, entry: int) -> dict:
        doc = json.loads((self.out / build_decks.DECKS_NAME).read_text(encoding="utf-8"))
        deck = next(d for d in doc["decks"] if d["level"] == level)
        return next(w for w in deck["words"] if w["e"] == entry)

    def edition(self) -> dict:
        return json.loads((self.out / build_decks.EDITION_NAME).read_text(encoding="utf-8"))

    def test_a_row_sets_the_lookup_spelling(self) -> None:
        code, out = self.build(OVERRIDES_HEAD + "N5\t9000001\t雨傘\tあまがさ\t검수자 11/14\n")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.word("N5", 9000001)["l"], "あまがさ")

    def test_a_row_replaces_the_rule_s_lookup_spelling(self) -> None:
        code, out = self.build(OVERRIDES_HEAD + "N5\t9000006\tたいへん\tたいへん?\t검수자 11/14\n")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.word("N5", 9000006)["l"], "たいへん?")
        self.assertEqual(self.word("N4", 9000003)["h"], "この")
        self.assertNotIn("l", self.word("N4", 9000003))

    def test_without_a_table_nothing_changes(self) -> None:
        code, out = self.build(None)
        self.assertEqual(code, 0, out)
        self.assertEqual(self.word("N5", 9000006)["l"], "大変")
        self.assertNotIn("l", self.word("N5", 9000001))
        self.assertEqual(self.edition()["lookup_overrides_rows"], 0)
        self.assertEqual(self.edition()["lookup_overrides_sha256"], "")

    def test_the_edition_records_the_table(self) -> None:
        table = OVERRIDES_HEAD + "N5\t9000001\t雨傘\tあまがさ\t검수자 11/14\n"
        self.build(table)
        self.assertEqual(self.edition()["lookup_overrides_rows"], 1)
        self.assertEqual(self.edition()["lookup_overrides_sha256"],
                         hashlib.sha256(table.encode("utf-8")).hexdigest())

    def test_a_row_not_reviewed_stops_the_build(self) -> None:
        code, out = self.build(OVERRIDES_HEAD + "N5\t9000001\t雨傘\tあまがさ\t\n")
        self.assertNotEqual(code, 0)
        self.assertIn("reviewed", out)
        self.assertFalse((self.out / build_decks.DECKS_NAME).exists())

    def test_a_table_without_the_reviewed_column_stops_the_build(self) -> None:
        code, out = self.build("level\tentry\theadword\tlookup\nN5\t9000001\t雨傘\tあまがさ\n")
        self.assertNotEqual(code, 0)
        self.assertIn("reviewed", out)

    def test_a_row_without_its_word_stops_the_build(self) -> None:
        code, out = self.build(OVERRIDES_HEAD + "N4\t9000001\t雨傘\tあまがさ\t검수자 11/14\n")
        self.assertNotEqual(code, 0)
        self.assertIn("lookup", out)

    def test_a_row_twice_stops_the_build(self) -> None:
        row = "N5\t9000001\t雨傘\tあまがさ\t검수자 11/14\n"
        code, out = self.build(OVERRIDES_HEAD + row + row)
        self.assertNotEqual(code, 0)
        self.assertIn("twice", out)

    def test_a_lookup_like_the_headword_stops_the_build(self) -> None:
        code, out = self.build(OVERRIDES_HEAD + "N5\t9000001\t雨傘\t雨傘\t검수자 11/14\n")
        self.assertNotEqual(code, 0)
        self.assertIn("lookup", out)


# F7: a list row whose entry number names another word with the same kana.
ENTRY_JMDICT = JMDICT.replace("</JMdict>", """<entry><ent_seq>9000020</ent_seq>
 <r_ele><reb>そのこ</reb></r_ele>
 <sense><pos>&adv;</pos><gloss>(interjection) there you go</gloss></sense></entry>
<entry><ent_seq>9000021</ent_seq>
 <k_ele><keb>其の子</keb><ke_pri>ichi1</ke_pri></k_ele>
 <r_ele><reb>そのこ</reb><re_pri>ichi1</re_pri></r_ele>
 <sense><pos>&n;</pos><misc>&uk;</misc><gloss>that child</gloss></sense></entry>
</JMdict>""")
ENTRY_LISTS = {**LISTS, "n5": [*LISTS["n5"], ("9000020", "そのこ", "", "that child")]}
ENTRIES_HEAD = "level\tentry\theadword\tfixed\treviewed\n"
ENTRY_ROW = "N5\t9000020\tそのこ\t9000021\t검수자 11/14\n"


class EntryOverrideTest(unittest.TestCase):
    """F7: a reviewed table gives a list row the entry its word really is."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.inputs = write_inputs(self.tmp / "in", lists=ENTRY_LISTS)
        with gzip.GzipFile(self.inputs["jmdict"], "wb", mtime=0) as f:
            f.write(ENTRY_JMDICT.encode("utf-8"))
        self.table = self.tmp / "in" / "entry-overrides.tsv"
        self.out = self.tmp / "out"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def args(self) -> list[str]:
        return ["--source", str(self.inputs["source"]), "--source-commit", COMMIT,
                "--jmdict", str(self.inputs["jmdict"]), "--supplement", str(self.inputs["supplement"]),
                "--entry-overrides", str(self.table), "--out-dir", str(self.out)]

    def build(self, table: str | None) -> tuple[int, str]:
        if table is not None:
            self.table.write_text(table, encoding="utf-8")
        return run([*self.args(), "--built-on", BUILT_ON])

    def word(self, level: str, headword: str) -> dict:
        doc = json.loads((self.out / build_decks.DECKS_NAME).read_text(encoding="utf-8"))
        deck = next(d for d in doc["decks"] if d["level"] == level)
        return next(w for w in deck["words"] if w["h"] == headword)

    def edition(self) -> dict:
        return json.loads((self.out / build_decks.EDITION_NAME).read_text(encoding="utf-8"))

    def test_a_row_gives_the_word_its_entry(self) -> None:
        code, out = self.build(ENTRIES_HEAD + ENTRY_ROW)
        self.assertEqual(code, 0, out)
        w = self.word("N5", "そのこ")
        self.assertEqual(w["e"], 9000021)
        self.assertEqual(w["l"], "其の子")

    def test_without_a_table_the_list_s_entry_stays(self) -> None:
        code, out = self.build(None)
        self.assertEqual(code, 0, out)
        self.assertEqual(self.word("N5", "そのこ")["e"], 9000020)
        self.assertEqual(self.edition()["entry_overrides_rows"], 0)
        self.assertEqual(self.edition()["entry_overrides_sha256"], "")

    def test_the_edition_records_the_table(self) -> None:
        table = ENTRIES_HEAD + ENTRY_ROW
        self.build(table)
        self.assertEqual(self.edition()["entry_overrides_rows"], 1)
        self.assertEqual(self.edition()["entry_overrides_sha256"],
                         hashlib.sha256(table.encode("utf-8")).hexdigest())

    def test_check_rebuilds_with_the_table(self) -> None:
        self.build(ENTRIES_HEAD + ENTRY_ROW)
        code, out = run(["--check", *self.args()])
        self.assertEqual(code, 0, out)
        self.assertNotIn("skipped", out)

    def test_a_row_not_reviewed_stops_the_build(self) -> None:
        code, out = self.build(ENTRIES_HEAD + "N5\t9000020\tそのこ\t9000021\t\n")
        self.assertNotEqual(code, 0)
        self.assertIn("reviewed", out)
        self.assertFalse((self.out / build_decks.DECKS_NAME).exists())

    def test_a_table_without_the_reviewed_column_stops_the_build(self) -> None:
        code, out = self.build("level\tentry\theadword\tfixed\nN5\t9000020\tそのこ\t9000021\n")
        self.assertNotEqual(code, 0)
        self.assertIn("reviewed", out)

    def test_a_row_without_its_list_row_stops_the_build(self) -> None:
        code, out = self.build(ENTRIES_HEAD + "N4\t9000020\tそのこ\t9000021\t검수자 11/14\n")
        self.assertNotEqual(code, 0)
        self.assertIn("entry overrides", out)

    def test_a_row_twice_stops_the_build(self) -> None:
        code, out = self.build(ENTRIES_HEAD + ENTRY_ROW + ENTRY_ROW)
        self.assertNotEqual(code, 0)
        self.assertIn("twice", out)

    def test_an_entry_not_in_jmdict_stops_the_build(self) -> None:
        code, out = self.build(ENTRIES_HEAD + "N5\t9000020\tそのこ\t9999998\t검수자 11/14\n")
        self.assertNotEqual(code, 0)
        self.assertIn("9999998", out)

    def test_an_entry_without_the_row_s_reading_stops_the_build(self) -> None:
        code, out = self.build(ENTRIES_HEAD + "N5\t9000020\tそのこ\t9000001\t검수자 11/14\n")
        self.assertNotEqual(code, 0)
        self.assertIn("そのこ", out)

    def test_the_same_entry_stops_the_build(self) -> None:
        code, out = self.build(ENTRIES_HEAD + "N5\t9000020\tそのこ\t9000020\t검수자 11/14\n")
        self.assertNotEqual(code, 0)
        self.assertIn("entry overrides", out)


if __name__ == "__main__":
    unittest.main()
