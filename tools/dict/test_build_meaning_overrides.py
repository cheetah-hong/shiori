"""M1, M5: build_meaning_overrides.py on a made-up table and the JMdict test database (no network).

  python3 -m unittest discover -s tools/dict -p 'test_*.py'
"""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import build_meaning_overrides as bmo  # noqa: E402

MINI_JMDICT = HERE.parent.parent / "packages" / "dict_jmdict" / "test" / "fixtures" / "mini_jmdict.sql"
BUILT_ON = "2026-11-14"
HEAD = "level\theadword\treading\tentry\tcurrent\tmeaning\tverdict\tconf\tenglish\tnote\treviewed\n"


def row(level: str, headword: str, reading: str, entry: int, meaning: str, reviewed: str = "검수자 11/14",
        current: str = "옛 뜻") -> str:
    return "\t".join([level, headword, reading, str(entry), current, meaning, "틀림", "높음", "-", "-", reviewed]) + "\n"


# Entries of the test database: 本 ほん 1522150 (本 is also 元 もと 1260670), 頭 あたま 1582310
# (頭 とう is 1450690), ごみ 1369900 (塵·芥, readings ゴミ·ごみ), コーヒー 1049180 (珈琲).
TABLE = HEAD + "".join([
    row("N5", "本", "ほん", 1522150, "책"),
    row("N5", "頭", "あたま", 1582310, "머리"),
    row("N4", "ごみ", "ごみ", 1369900, "쓰레기"),
    row("N5", "コーヒー", "コーヒー", 1049180, "커피"),
    row("N3", "元", "もと", 1260670, "근원", reviewed="skip"),
])


class _Case(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.jmdict = self.tmp / "jmdict.sqlite"
        with sqlite3.connect(self.jmdict) as db:
            db.executescript(MINI_JMDICT.read_text(encoding="utf-8"))
        self.table = self.tmp / "overrides.tsv"
        self.out = self.tmp / "out"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def build(self, table: str = TABLE, out: Path | None = None) -> dict:
        self.table.write_text(table, encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()):
            return bmo.build_asset(self.table, self.jmdict, out or self.out, built_on=BUILT_ON)

    def doc(self) -> dict:
        return json.loads((self.out / bmo.OVERRIDES_NAME).read_text(encoding="utf-8"))

    def rows(self) -> dict[tuple[str, str], dict]:
        return {(r["f"][0], r["r"]): r for r in self.doc()["rows"]}

    def assertStops(self, table: str, *words: str) -> None:
        with self.assertRaises(bmo.BuildError) as e:
            self.build(table)
        for w in words:
            self.assertIn(w, str(e.exception))
        self.assertFalse((self.out / bmo.OVERRIDES_NAME).exists())


class BuildTest(_Case):
    def test_header_and_rows(self) -> None:
        self.build()
        doc = self.doc()
        self.assertEqual(doc["format"], "shiori-meaning-overrides")
        self.assertEqual(doc["version"], 1)
        self.assertEqual(doc["edition"], BUILT_ON)
        rows = self.rows()
        self.assertEqual(rows[("本", "ほん")], {"f": ["本"], "r": "ほん", "m": "책"})
        self.assertEqual(rows[("頭", "あたま")], {"f": ["頭"], "r": "あたま", "m": "머리"})

    def test_a_kana_word_also_answers_for_its_entry_s_kanji(self) -> None:
        self.build()
        self.assertEqual(self.rows()[("ごみ", "ごみ")]["f"], ["ごみ", "塵", "芥"])
        self.assertEqual(self.rows()[("コーヒー", "コーヒー")]["f"], ["コーヒー", "珈琲"])

    def test_a_kanji_word_never_answers_for_its_kana(self) -> None:
        self.build()
        for r in self.doc()["rows"]:
            if r["f"][0] in ("本", "頭"):
                self.assertNotIn(r["r"], r["f"])

    def test_skipped_rows_are_left_out(self) -> None:
        self.build()
        self.assertNotIn(("元", "もと"), self.rows())
        self.assertEqual(len(self.doc()["rows"]), 4)

    def test_same_inputs_same_bytes(self) -> None:
        self.build()
        again = self.tmp / "again"
        self.build(out=again)
        for name in (bmo.OVERRIDES_NAME, bmo.EDITION_NAME):
            self.assertEqual((again / name).read_bytes(), (self.out / name).read_bytes(), name)

    def test_the_table_s_row_order_does_not_change_the_file(self) -> None:
        self.build()
        lines = TABLE.splitlines(keepends=True)
        again = self.tmp / "again"
        self.build(lines[0] + "".join(reversed(lines[1:])), out=again)
        self.assertEqual((again / bmo.OVERRIDES_NAME).read_bytes(), (self.out / bmo.OVERRIDES_NAME).read_bytes())

    def test_edition_records_inputs_and_output(self) -> None:
        self.build()
        ed = json.loads((self.out / bmo.EDITION_NAME).read_text(encoding="utf-8"))
        raw = (self.out / bmo.OVERRIDES_NAME).read_bytes()
        self.assertEqual(ed["built_on"], BUILT_ON)
        self.assertEqual(ed["rows"], 4)
        self.assertEqual(ed["skipped"], 1)
        self.assertEqual(ed["table_sha256"], hashlib.sha256(TABLE.encode("utf-8")).hexdigest())
        self.assertEqual(ed["jmdict_created"], "2026-11-04")
        self.assertEqual(ed["json_sha256"], hashlib.sha256(raw).hexdigest())
        self.assertEqual(ed["json_bytes"], len(raw))
        self.assertEqual(ed["license"], "CC BY-SA 4.0")
        self.assertTrue(ed["attribution"])

    def test_the_same_spelling_and_reading_with_the_same_meaning_is_one_row(self) -> None:
        self.build(HEAD + row("N5", "本", "ほん", 1522150, "책") + row("N1", "本", "ほん", 1522150, "책"))
        self.assertEqual(self.doc()["rows"], [{"f": ["本"], "r": "ほん", "m": "책"}])


class RefuseTest(_Case):
    def test_a_row_not_reviewed(self) -> None:
        self.assertStops(HEAD + row("N5", "本", "ほん", 1522150, "책", reviewed=""), "reviewed")

    def test_a_table_without_a_column(self) -> None:
        self.assertStops("level\theadword\treading\tentry\tmeaning\nN5\t本\tほん\t1522150\t책\n", "reviewed")

    def test_a_row_without_a_meaning(self) -> None:
        self.assertStops(HEAD + row("N5", "本", "ほん", 1522150, " "), "meaning")

    def test_a_meaning_with_japanese(self) -> None:
        self.assertStops(HEAD + row("N5", "本", "ほん", 1522150, "책(ほん)"), "本")

    def test_an_entry_not_in_jmdict(self) -> None:
        self.assertStops(HEAD + row("N5", "本", "ほん", 9999999, "책"), "9999999")

    def test_a_reading_the_entry_does_not_have(self) -> None:
        self.assertStops(HEAD + row("N5", "本", "もと", 1522150, "책"), "もと")

    def test_a_headword_the_entry_does_not_write(self) -> None:
        self.assertStops(HEAD + row("N5", "頭", "ほん", 1522150, "책"), "頭")

    def test_one_spelling_and_reading_with_two_meanings(self) -> None:
        self.assertStops(HEAD + row("N5", "本", "ほん", 1522150, "책") + row("N1", "本", "ほん", 1522150, "서적"),
                         "twice")


class CheckTest(_Case):
    def test_a_fresh_build_passes(self) -> None:
        self.build()
        self.assertEqual(bmo.check(self.out), [])

    def test_a_changed_file_fails(self) -> None:
        self.build()
        path = self.out / bmo.OVERRIDES_NAME
        path.write_bytes(path.read_bytes().replace("책".encode(), "칙".encode()))
        self.assertTrue(any("sha256" in p for p in bmo.check(self.out)))

    def test_no_files_fail(self) -> None:
        self.assertTrue(bmo.check(self.tmp / "none"))

    def test_main_check_rebuilds_from_its_inputs(self) -> None:
        self.build()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = bmo.main(["--check", "--table", str(self.table), "--jmdict-sqlite", str(self.jmdict),
                             "--out-dir", str(self.out)])
        self.assertEqual(code, 0, out.getvalue())
        self.assertNotIn("skipped", out.getvalue())

    def test_main_check_fails_when_the_table_s_rebuild_differs(self) -> None:
        self.build()
        ed_path = self.out / bmo.EDITION_NAME
        ed = json.loads(ed_path.read_text(encoding="utf-8"))
        raw = (self.out / bmo.OVERRIDES_NAME).read_bytes().replace("책".encode(), "칙".encode())
        (self.out / bmo.OVERRIDES_NAME).write_bytes(raw)
        ed["json_sha256"] = hashlib.sha256(raw).hexdigest()
        ed_path.write_text(json.dumps(ed, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = bmo.main(["--check", "--table", str(self.table), "--jmdict-sqlite", str(self.jmdict),
                             "--out-dir", str(self.out)])
        self.assertNotEqual(code, 0)
        self.assertIn("rebuild", out.getvalue())

    def test_main_builds(self) -> None:
        self.table.write_text(TABLE, encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()):
            code = bmo.main(["--table", str(self.table), "--jmdict-sqlite", str(self.jmdict),
                             "--built-on", BUILT_ON, "--out-dir", str(self.out)])
        self.assertEqual(code, 0)
        self.assertEqual(bmo.check(self.out), [])


if __name__ == "__main__":
    unittest.main()
