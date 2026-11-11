"""X1: build_examples.py on made-up Tatoeba files and the JMdict test fixture (no network).

  python3 -m unittest discover -s tools/dict -p 'test_*.py'
"""
from __future__ import annotations

import bz2
import contextlib
import gzip
import io
import json
import shutil
import sqlite3
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import build_examples  # noqa: E402

SAMPLE = HERE / "testdata" / "tatoeba_sample"
MINI_JMDICT = HERE.parent.parent / "packages" / "dict_jmdict" / "test" / "fixtures" / "mini_jmdict.sql"
BUILT_ON = "2026-11-12"
EXPORT = "2026-11-07"

# JMdict entries of the fixture the sample sentences use.
SORA, KARA = 1245290, 1245280          # 空: そら / から
HON = 1522150                          # 本: ほん
SHICHI = 1319210                       # 七: しち, なな, …
BENKYOU = 1512670                      # 勉強
YOGOSU = 1178960                       # 汚す: よごす, けがす
YUUGATA = 1542790                      # 夕方
SHIZUKA = 1381820                      # 静か
TANA = 1416700                         # 棚
COFFEE = 1049180                       # コーヒー (珈琲, usually kana)
NI = 2028990                           # に (the particle: a kana-only common entry)


def jmdict_sqlite(path: Path) -> Path:
    db = sqlite3.connect(path)
    db.executescript(MINI_JMDICT.read_text(encoding="utf-8"))
    db.close()
    return path


def rows(db_path: Path) -> dict[tuple[int, str], dict]:
    with contextlib.closing(sqlite3.connect(db_path)) as db:
        db.row_factory = sqlite3.Row
        return {(r["entry"], r["reading"]): dict(r) for r in db.execute("SELECT * FROM example")}


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._tmp = tempfile.TemporaryDirectory()
        cls.tmp = Path(cls._tmp.name)
        cls.jmdict = jmdict_sqlite(cls.tmp / "jmdict.sqlite")
        cls.out = cls.tmp / "out"
        cls.edition = build_examples.build_asset(SAMPLE, cls.jmdict, cls.out, built_on=BUILT_ON,
                                                 tatoeba_export=EXPORT)
        cls.db = cls.tmp / "examples.sqlite"
        cls.db.write_bytes(gzip.decompress((cls.out / build_examples.ASSET_NAME).read_bytes()))
        cls.rows = rows(cls.db)

    @classmethod
    def tearDownClass(cls) -> None:
        cls._tmp.cleanup()

    def test_one_sentence_per_entry_joined_through_the_dictionary_form(self) -> None:
        self.assertEqual(self.rows[(BENKYOU, "")]["ja"], "図書館で勉強しました。")
        self.assertEqual(self.rows[(YOGOSU, "")]["ja"], "服を汚してしまった。")   # 汚して → 汚す
        self.assertEqual(self.rows[(YOGOSU, "")]["surface"], "汚して")
        self.assertEqual(self.rows[(COFFEE, "")]["ja"], "コーヒーを飲みます。")
        entries = [e for e, _ in self.rows]
        self.assertEqual(len(entries), len(self.rows))
        self.assertEqual(sorted(set(entries)), sorted([SORA, KARA, HON, SHICHI, BENKYOU, YOGOSU, YUUGATA,
                                                       SHIZUKA, TANA, COFFEE, NI]))

    def test_the_reading_in_the_sentence_picks_the_entry_and_its_row(self) -> None:
        self.assertEqual(self.rows[(SORA, "")]["ja"], "空が青いです。")
        # から is one of two readings of its entry: the row says which.
        self.assertEqual(self.rows[(KARA, "から")]["ja"], "箱は空です。")
        self.assertEqual(self.rows[(SHICHI, "しち")]["ja"], "七時に起きます。")
        self.assertEqual(self.rows[(SHICHI, "なな")]["ja"], "七回聞きました。")

    def test_unfit_sentences_are_left_out(self) -> None:
        # 静か: the sentence with a sensitive word goes; 棚: too short, and tagged for a check.
        self.assertNotIn("くそ", self.rows[(SHIZUKA, "")]["ja"])
        self.assertEqual(self.rows[(TANA, "")]["ja"], "棚に本があります。")

    def test_korean_first_then_english_then_none(self) -> None:
        shizuka = self.rows[(SHIZUKA, "")]
        self.assertEqual((shizuka["ja"], shizuka["ko"], shizuka["en"]),
                         ("静かにしなさい。", "조용히 하세요.", None))
        sora = self.rows[(SORA, "")]
        self.assertEqual((sora["ko"], sora["en"]), ("하늘이 파랗습니다.", None))
        hon = self.rows[(HON, "")]       # a sentence with an English translation before one without
        self.assertEqual((hon["ja"], hon["ko"], hon["en"]),
                         ("毎日本を読みます。", None, "I read books every day."))
        yogosu = self.rows[(YOGOSU, "")]
        self.assertEqual((yogosu["ko"], yogosu["en"]), (None, None))

    def test_the_sentence_number_is_kept(self) -> None:
        self.assertEqual(self.rows[(BENKYOU, "")]["sentence"], 107)

    def test_edition(self) -> None:
        e = self.edition
        self.assertEqual(e["schema"], build_examples.SCHEMA_VERSION)
        self.assertEqual(e["built_on"], BUILT_ON)
        (source,) = e["sources"]
        self.assertEqual((source["source"], source["edition"], source["license"]),
                         ("tatoeba", EXPORT, "CC BY 2.0 FR"))
        self.assertIn("tatoeba.org", source["url"])
        self.assertEqual(set(e["files"]), set(build_examples.SOURCE_FILES))
        self.assertEqual(e["examples"], len(self.rows))
        self.assertEqual(e["korean"] + e["english"] + e["untranslated"], len(self.rows))
        with contextlib.closing(sqlite3.connect(self.db)) as db:
            meta = dict(db.execute("SELECT key, value FROM meta"))
            version = db.execute("PRAGMA user_version").fetchone()[0]
        self.assertEqual(version, build_examples.SCHEMA_VERSION)
        self.assertEqual(meta["tatoeba.edition"], EXPORT)
        self.assertEqual(meta["variant"], e["variant"])

    def test_same_input_same_bytes(self) -> None:
        again = self.tmp / "again"
        build_examples.build_asset(SAMPLE, self.jmdict, again, built_on=BUILT_ON, tatoeba_export=EXPORT)
        for name in (build_examples.ASSET_NAME, build_examples.EDITION_NAME):
            self.assertEqual((again / name).read_bytes(), (self.out / name).read_bytes(), name)

    def test_compressed_exports_give_the_same_asset(self) -> None:
        """The real exports are .tsv.bz2 files and jpn_indices.tar.bz2."""
        packed = self.tmp / "packed"
        packed.mkdir()
        for f in SAMPLE.glob("*.tsv"):
            (packed / f"{f.name}.bz2").write_bytes(bz2.compress(f.read_bytes()))
        with tarfile.open(packed / "jpn_indices.tar.bz2", "w:bz2") as tar:
            tar.add(SAMPLE / "jpn_indices.csv", arcname="jpn_indices.csv")
        out = self.tmp / "from-packed"
        build_examples.build_asset(packed, self.jmdict, out, built_on=BUILT_ON, tatoeba_export=EXPORT)
        self.assertEqual(rows_of(out), rows_of(self.out))

    def test_a_different_sha256_stops_the_build(self) -> None:
        with self.assertRaises(SystemExit):
            build_examples.build_asset(SAMPLE, self.jmdict, self.tmp / "bad", built_on=BUILT_ON,
                                       tatoeba_export=EXPORT,
                                       expect_sha256={"jpn_indices": "0" * 64})
        self.assertFalse((self.tmp / "bad" / build_examples.ASSET_NAME).exists())

    def test_the_expected_sha256_of_every_file_passes(self) -> None:
        out = self.tmp / "pinned"
        build_examples.build_asset(SAMPLE, self.jmdict, out, built_on=BUILT_ON, tatoeba_export=EXPORT,
                                   expect_sha256=dict(self.edition["files"]))
        self.assertTrue((out / build_examples.ASSET_NAME).is_file())

    def test_a_missing_file_stops_the_build(self) -> None:
        partial = self.tmp / "partial"
        shutil.copytree(SAMPLE, partial)
        (partial / "jpn-eng_links.tsv").unlink()
        with self.assertRaises(SystemExit):
            build_examples.build_asset(partial, self.jmdict, self.tmp / "none", built_on=BUILT_ON,
                                       tatoeba_export=EXPORT)

    def test_a_bad_day_stops_the_build(self) -> None:
        with self.assertRaises(SystemExit):
            build_examples.build_asset(SAMPLE, self.jmdict, self.tmp / "day", built_on=BUILT_ON,
                                       tatoeba_export="last week")


def rows_of(out: Path) -> dict:
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "x.sqlite"
        path.write_bytes(gzip.decompress((out / build_examples.ASSET_NAME).read_bytes()))
        return rows(path)


class RulesTest(unittest.TestCase):
    def test_card_sentence(self) -> None:
        self.assertTrue(build_examples.is_card_sentence("棚に本があります。"))
        for bad in ("棚", "棚" * 31 + "だ", "棚に本がある 책", "棚に本 (hon)", "棚、本、空、日", "棚を見る / 本を見る"):
            self.assertFalse(build_examples.is_card_sentence(bad), bad)

    def test_sensitive_words(self) -> None:
        self.assertTrue(build_examples.is_sensitive("くそ、静かにしろ。"))
        self.assertFalse(build_examples.is_sensitive("静かにしなさい。"))

    def test_bline(self) -> None:
        words = build_examples.parse_bline("七(なな)[02]{七回}~ が(#2028930) 聞く{聞きました} {壊れ")
        self.assertEqual([(w.headword, w.reading, w.surface, w.checked) for w in words], [
            ("七", "なな", "七回", True), ("が", "#2028930", None, False), ("聞く", None, "聞きました", False)])

    def test_reading_agrees_ignores_the_ending_and_the_script(self) -> None:
        self.assertTrue(build_examples.reading_agrees("よごして", "よごす"))
        self.assertTrue(build_examples.reading_agrees("コーヒー", "こーひー"))
        self.assertFalse(build_examples.reading_agrees("けがして", "よごす"))


class SampleSqlTest(unittest.TestCase):
    def test_the_block_fixture_is_the_sample_build(self) -> None:
        """packages/example_block/test/fixtures/mini_examples.sql is what --sample-sql writes."""
        self.assertEqual(build_examples.SAMPLE_SQL.read_text(encoding="utf-8"), build_examples.sample_sql())

    def test_check_reports_a_good_asset(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            jm = jmdict_sqlite(Path(tmp) / "jm.sqlite")
            out = Path(tmp) / "out"
            build_examples.build_asset(SAMPLE, jm, out, built_on=BUILT_ON, tatoeba_export=EXPORT)
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                code = build_examples.main(["--check", "--out-dir", str(out)])
            self.assertEqual(code, 0, buf.getvalue())
            self.assertIn("examples: ok", buf.getvalue())
            edition = json.loads((out / build_examples.EDITION_NAME).read_text(encoding="utf-8"))
            edition["sqlite_sha256"] = "0" * 64
            (out / build_examples.EDITION_NAME).write_text(json.dumps(edition), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(build_examples.main(["--check", "--out-dir", str(out)]), 1)


if __name__ == "__main__":
    unittest.main()
