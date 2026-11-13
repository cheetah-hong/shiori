"""B1: build_decks.py on a made-up word list and a made-up JMdict (no network).

  python3 -m unittest discover -s tools/decks -p 'test_*.py'
"""
from __future__ import annotations

import contextlib
import gzip
import hashlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import build_decks  # noqa: E402

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

SUPPLEMENT = "level\tentry\theadword\tmeaning\nN3\t9000007\t夕凪\t저녁뜸\n"


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


if __name__ == "__main__":
    unittest.main()
