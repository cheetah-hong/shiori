"""Unit tests for build_ko_glossary.py on a made-up Basic Korean Dictionary sample (no network).

  python3 -m unittest discover -s tools/dict -p 'test_*.py'

The sample (testdata/krdict_sample.json) copies the shape of the real JSON download:
feat lists that are sometimes a single dict, Sense as a dict or a list, Japanese
equivalents written `よみ【漢字】。カナ`, tabs and spaces after them, `(対訳語無し)`.
"""
from __future__ import annotations

import gzip
import hashlib
import json
import sqlite3
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import build_ko_glossary as ko  # noqa: E402

SAMPLE = HERE / "testdata" / "krdict_sample.json"
KEY_TABLE = HERE / "testdata" / "ko_glossary_keys.json"
POS_TABLE = HERE / "testdata" / "ko_pos_codes.json"
FIXTURE_SQL = HERE.parent.parent / "packages" / "krdict_block" / "test" / "fixtures" / "mini_krdict.sql"


def _zip_sample(path: Path) -> Path:
    """The sample split over two JSON files in one zip, like the real download."""
    doc = json.loads(SAMPLE.read_text(encoding="utf-8"))
    entries = doc["LexicalResource"]["Lexicon"]["LexicalEntry"]
    with zipfile.ZipFile(path, "w") as z:
        for i, part in enumerate((entries[:12], entries[12:]), start=1):
            piece = json.loads(json.dumps(doc))
            piece["LexicalResource"]["Lexicon"]["LexicalEntry"] = part
            z.writestr(f"{i}_5000_20261019.json", json.dumps(piece, ensure_ascii=False))
    return path


class KeyTableTest(unittest.TestCase):
    """K9: the same keys as packages/krdict_block (both read the table)."""

    def test_every_case_of_the_shared_table(self) -> None:
        cases = json.loads(KEY_TABLE.read_text(encoding="utf-8"))["cases"]
        self.assertGreaterEqual(len(cases), 20)
        for c in cases:
            with self.subTest(form=c["form"], reading=c["reading"], why=c["why"]):
                self.assertEqual(ko.pair_key(c["form"], c["reading"]), (c["key"], c["reading_key"]))


class ParseEquivalentTest(unittest.TestCase):
    def test_pairs_and_kana_in_order(self) -> None:
        parts = ko.parse_equivalent("しょくどう【食堂】。レストラン")
        self.assertEqual(parts, [
            ko.Part(0, ko.PAIR, "食堂", "しょくどう"),
            ko.Part(1, ko.KANA, "レストラン", ""),
        ])

    def test_alternatives_on_both_sides_share_a_position(self) -> None:
        self.assertEqual(ko.parse_equivalent("ただ【只・唯】"), [
            ko.Part(0, ko.PAIR, "只", "ただ"),
            ko.Part(0, ko.PAIR, "唯", "ただ"),
        ])
        self.assertEqual(ko.parse_equivalent("そん・むら【村】"), [
            ko.Part(0, ko.PAIR, "村", "そん"),
            ko.Part(0, ko.PAIR, "村", "むら"),
        ])

    def test_trailing_tabs_and_spaces_are_ignored(self) -> None:
        self.assertEqual(ko.parse_equivalent("ただ。たんに【単に】\t"), [
            ko.Part(0, ko.KANA, "ただ", ""),
            ko.Part(1, ko.PAIR, "単に", "たんに"),
        ])

    def test_no_equivalent_gives_nothing(self) -> None:
        """K5 at the parser: `(対訳語無し)` is not a word."""
        self.assertEqual(ko.parse_equivalent("(対訳語無し)"), [])
        self.assertEqual(ko.parse_equivalent("（対訳語無し）"), [])

    def test_a_kana_spelling_in_brackets_is_a_kana_word(self) -> None:
        self.assertEqual(ko.parse_equivalent("たばこ【タバコ】"), [
            ko.Part(0, ko.KANA, "たばこ", ""),
            ko.Part(0, ko.KANA, "タバコ", ""),
        ])

    def test_a_bracket_closed_with_the_wrong_mark_still_pairs(self) -> None:
        self.assertEqual(ko.parse_equivalent("いちばん【一番」"), [ko.Part(0, ko.PAIR, "一番", "いちばん")])

    def test_a_written_form_without_reading(self) -> None:
        self.assertEqual(ko.parse_equivalent("着手する"), [ko.Part(0, ko.WRITTEN, "着手する", "")])


class BuildTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.zip = _zip_sample(self.tmp / "krdict_json.zip")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _db(self, variant: str = "lean") -> sqlite3.Connection:
        path = self.tmp / f"{variant}.sqlite"
        ko.build_db(ko.read_source(self.zip), path, variant=variant, built_on="2026-11-05")
        return sqlite3.connect(path)

    def test_reads_every_file_of_the_zip_and_the_edition_date(self) -> None:
        source = ko.read_source(self.zip)
        self.assertEqual(source.edition, "2026-10-19")
        self.assertEqual(len(source.entries), 43)

    def test_schema_version_and_meta(self) -> None:
        with self._db() as db:
            self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], ko.SCHEMA_VERSION)
            meta = dict(db.execute("SELECT key, value FROM meta"))
        self.assertEqual(meta["krdict.edition"], "2026-10-19")
        self.assertEqual(meta["krdict.license"], "CC BY-SA 2.0 KR")
        self.assertEqual(meta["krdict.publisher"], "국립국어원")
        self.assertTrue(meta["krdict.license_url"].startswith("https://creativecommons.org/licenses/by-sa/2.0/kr"))
        self.assertEqual(meta["variant"], "lean")

    def test_a_pair_is_keyed_by_its_written_form_and_reading(self) -> None:
        """K1 at the index: 食堂 with しょくどう, レストラン as kana."""
        with self._db() as db:
            rows = db.execute(
                "SELECT j.key, j.reading, j.kind, j.pos FROM ja j JOIN sense s ON s.id = j.sense_id "
                "WHERE s.word = '식당' ORDER BY j.pos").fetchall()
        self.assertEqual(rows, [("食堂", "しょくどう", 0, 0), ("れすとらん", "", 2, 1)])

    def test_no_equivalent_and_other_languages_are_not_indexed(self) -> None:
        """K5: the sense of 거저 has only `(対訳語無し)`, so it is left out."""
        with self._db() as db:
            self.assertEqual(db.execute("SELECT count(*) FROM sense WHERE word = '거저'").fetchone()[0], 0)
            keys = {k for (k,) in db.execute("SELECT key FROM ja")}
        self.assertFalse(any("対訳語" in k for k in keys))
        self.assertNotIn("restaurant", keys)

    def test_only_single_words_are_kept(self) -> None:
        """Idioms and proverbs (lexicalUnit other than 단어) translate phrases, not words."""
        with self._db() as db:
            self.assertEqual(db.execute("SELECT count(*) FROM sense WHERE word = '코가 높다'").fetchone()[0], 0)

    def test_level_sense_number_and_synonyms(self) -> None:
        with self._db() as db:
            rows = dict((w, (lv, no, syn)) for w, lv, no, syn in db.execute(
                "SELECT word, level, sense_no, synonyms FROM sense WHERE word IN ('다만', '단지', '그저', '체코어', '사전')"))
        self.assertEqual(rows["다만"], (2, 1, "단지"))
        self.assertEqual(rows["단지"], (2, 1, "다만"), "only 유의어 relations, not 반대말")
        self.assertEqual(rows["그저"][1], 2, "the sense that has ただ is the second")
        self.assertIsNone(rows["체코어"][0], "level 없음")
        self.assertIsNone(rows["사전"][0], "no level at all")

    def test_each_sense_keeps_its_korean_part_of_speech(self) -> None:
        """Schema 2: sense.pos is the entry's partOfSpeech as a code (0 without one)."""
        with self._db() as db:
            self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 2)
            rows = dict(db.execute(
                "SELECT word, pos FROM sense WHERE word IN ('공짜', '다만', '유명하다', '걸다', '사전')"))
        codes = ko.POS_CODES
        self.assertEqual(rows["공짜"], codes["명사"])
        self.assertEqual(rows["다만"], codes["부사"])
        self.assertEqual(rows["유명하다"], codes["형용사"])
        self.assertEqual(rows["걸다"], codes["동사"])
        self.assertEqual(rows["사전"], 0, "no partOfSpeech in the entry")

    def test_part_of_speech_without_a_code_is_zero(self) -> None:
        self.assertEqual(ko.pos_code("품사 없음"), 0)
        self.assertEqual(ko.pos_code(""), 0)
        self.assertEqual(ko.pos_code("새 품사"), 0)

    def test_only_the_full_variant_keeps_the_korean_definitions(self) -> None:
        # Sizes on the real data are in docs/dictionary.md; this sample is too
        # small for the files to differ in pages.
        with self._db("full") as db:
            full = db.execute("SELECT definition FROM sense WHERE word = '식당'").fetchone()[0]
            self.assertEqual(dict(db.execute("SELECT key, value FROM meta"))["variant"], "full")
        self.assertEqual(full, "음식을 만들어 파는 가게.")
        with self._db("lean") as db:
            cols = [r[1] for r in db.execute("PRAGMA table_info(sense)")]
        self.assertNotIn("definition", cols)

    def test_an_unknown_variant_stops_the_build(self) -> None:
        with self.assertRaises(SystemExit):
            ko.build_db(ko.read_source(self.zip), self.tmp / "x.sqlite", variant="tiny", built_on="2026-11-05")

    def test_the_same_source_gives_the_same_bytes(self) -> None:
        a, b = self.tmp / "a.sqlite", self.tmp / "b.sqlite"
        ko.build_db(ko.read_source(self.zip), a, variant="lean", built_on="2026-11-05")
        ko.build_db(ko.read_source(self.zip), b, variant="lean", built_on="2026-11-05")
        self.assertEqual(a.read_bytes(), b.read_bytes())


class AssetTest(unittest.TestCase):
    """K14: the edition file next to the asset."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.zip = _zip_sample(self.tmp / "krdict_json.zip")
        self.out = self.tmp / "assets" / "dict"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_writes_the_gzip_and_the_edition_where_the_app_reads_them(self) -> None:
        ko.build_asset(self.zip, self.out, built_on="2026-11-05")
        self.assertEqual(sorted(p.name for p in self.out.iterdir()),
                         [ko.EDITION_NAME, ko.ASSET_NAME])
        self.assertEqual(ko.ASSET_NAME, "ko-glossary.sqlite.gz")
        self.assertEqual(ko.EDITION_NAME, "ko-glossary.edition.json")

    def test_edition_names_source_date_licence_and_hashes(self) -> None:
        edition = ko.build_asset(self.zip, self.out, built_on="2026-11-05")
        on_disk = json.loads((self.out / ko.EDITION_NAME).read_text(encoding="utf-8"))
        self.assertEqual(on_disk, edition)
        (src,) = edition["sources"]
        self.assertEqual(src["source"], "krdict")
        self.assertEqual(src["name"], "한국어기초사전")
        self.assertEqual(src["publisher"], "국립국어원")
        self.assertEqual(src["edition"], "2026-10-19")
        self.assertEqual(src["license"], "CC BY-SA 2.0 KR")
        self.assertEqual(src["source_sha256"], hashlib.sha256(self.zip.read_bytes()).hexdigest())
        self.assertEqual(edition["attribution"], "한국어기초사전, 국립국어원, CC BY-SA 2.0 KR, 2026-10-19판을 가공함")
        self.assertEqual(edition["built_on"], "2026-11-05")
        self.assertEqual(edition["variant"], "lean")
        raw = gzip.decompress((self.out / ko.ASSET_NAME).read_bytes())
        self.assertEqual(edition["sqlite_bytes"], len(raw))
        self.assertEqual(edition["sqlite_sha256"], hashlib.sha256(raw).hexdigest())
        self.assertEqual(edition["gzip_bytes"], (self.out / ko.ASSET_NAME).stat().st_size)

    def test_a_wrong_source_hash_stops_the_build(self) -> None:
        with self.assertRaises(SystemExit):
            ko.build_asset(self.zip, self.out, built_on="2026-11-05", expect_sha256="00" * 32)
        self.assertFalse((self.out / ko.EDITION_NAME).exists())

    def test_a_missing_source_stops_the_build_without_downloading(self) -> None:
        with self.assertRaises(SystemExit):
            ko.build_asset(self.tmp / "nothing.zip", self.out, built_on="2026-11-05")

    def test_a_bad_build_day_stops_the_build(self) -> None:
        with self.assertRaises(SystemExit):
            ko.build_asset(self.zip, self.out, built_on="5 Nov")


class PosTableTest(unittest.TestCase):
    """The codes packages/krdict_block reads (both read the table)."""

    def test_the_codes_are_the_shared_table(self) -> None:
        table = json.loads(POS_TABLE.read_text(encoding="utf-8"))
        self.assertEqual(ko.POS_CODES, table["codes"])
        self.assertEqual(len(set(ko.POS_CODES.values())), len(ko.POS_CODES), "one name per code")
        self.assertNotIn(0, ko.POS_CODES.values(), "0 is no part of speech")


class FixtureTest(unittest.TestCase):
    def test_the_dart_test_fixture_is_built_from_the_sample(self) -> None:
        """packages/krdict_block/test/fixtures/mini_krdict.sql is this script's dump of the sample."""
        expected = ko.sql_dump(ko.read_source(SAMPLE), variant="lean", built_on="2026-11-05")
        self.assertEqual(FIXTURE_SQL.read_text(encoding="utf-8"), expected,
                         "rebuild it: python3 tools/dict/build_ko_glossary.py --sample-sql")


if __name__ == "__main__":
    unittest.main()
