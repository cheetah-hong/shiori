"""W1: build_wikt_glossary.py and wikt_en_rows.py on made-up Wiktionary samples (no network).

  python3 -m unittest discover -s tools/dict -p 'test_*.py'

The samples (testdata/wikt_sample_ko.jsonl, testdata/wikt_sample_en_rows.jsonl) copy
the shape of kaikki.org's wiktextract lines with made-up words only. The Basic Korean
Dictionary keys left out are those of testdata/krdict_sample.json.
"""
from __future__ import annotations

import gzip
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

import build_ko_glossary as ko  # noqa: E402
import build_wikt_glossary as wk  # noqa: E402
import wikt_en_rows  # noqa: E402

FIXTURE_SQL = HERE.parent.parent / "packages" / "krdict_block" / "test" / "fixtures" / "mini_wikt.sql"
BUILT_ON = "2026-11-07"
KO_DUMP = "2026-11-01"


def _lines(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def _sha256(path: Path) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class TextRulesTest(unittest.TestCase):
    def test_korean_gloss_words(self) -> None:
        self.assertEqual(wk.korean_words("눈숲, 설삼."), ["눈숲", "설삼"])
        self.assertEqual(wk.korean_words("(옛말) 겨울 숲."), ["겨울 숲"])
        self.assertEqual(wk.korean_words("어간의 하나."), [])
        self.assertEqual(wk.korean_words("안개가 자욱하게 낀 숲을 이르는 말."), [])
        self.assertEqual(wk.korean_words("ゆきもり 눈숲"), [])

    def test_translation_words(self) -> None:
        self.assertEqual(wk.translation_words("(숲을) 덮다, 꾹 참다"), ["덮다", "꾹 참다"])
        self.assertEqual(wk.translation_words("가만히 (서다)"), ["가만히 서다"])
        self.assertEqual(wk.translation_words("월로(月路)"), ["월로"])
        self.assertEqual(wk.translation_words("moon"), [])

    def test_ruby_over_kanji_pieces_gives_the_whole_reading(self) -> None:
        self.assertEqual(wk.ruby_reading("雪森る", [["雪", "ゆき"], ["森", "もり"]]), "ゆきもりる")
        self.assertEqual(wk.ruby_reading("森める", [["森", "も"]]), "もめる")
        self.assertEqual(wk.ruby_reading("雪森", [["林", "はやし"]]), "")

    def test_readings_leave_old_spellings_out(self) -> None:
        entry = {"word": "雪森る", "forms": [
            {"form": "雪森る", "ruby": [["雪", "ゆき"], ["森", "もり"]]},
            {"form": "ゆきもりふ", "tags": ["archaic"]},
            {"form": "ゆきもりる", "tags": ["hiragana"]},
            {"form": "yukimoriru", "tags": ["romanization"]},
        ]}
        self.assertEqual(wk.readings_of(entry), ["ゆきもりる"])


class GroupsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.ko = wk.kowikt_groups(_lines(wk.SAMPLE_KO))
        _, rows = wikt_en_rows.read_rows(wk.SAMPLE_EN)
        self.en = wk.enwikt_groups(rows)

    def words(self, groups: dict, key: str) -> list[tuple[str, ...]]:
        return [g.words for g in groups.get(key, [])]

    def test_kowikt_senses_in_order_once_each(self) -> None:
        self.assertEqual(self.words(self.ko, "雪森"), [("눈숲", "설삼"), ("겨울 숲",)])
        self.assertEqual({r for g in self.ko["雪森"] for r in g.readings}, {"ゆきもり"})

    def test_kowikt_okurigana_reading_and_no_old_spelling(self) -> None:
        [group] = self.ko["雪森る"]
        self.assertEqual(group.readings, frozenset({"ゆきもりる"}))

    def test_kowikt_keys_and_endings_like_the_glossary(self) -> None:
        [windy] = self.ko["風森"]
        self.assertEqual((windy.ending, windy.words, windy.readings), ("だ", ("바람차다",), frozenset()))
        self.assertEqual(self.words(self.ko, "ゆきやま"), [("눈산",)])

    def test_kowikt_entries_without_a_word_and_korean_entries_give_nothing(self) -> None:
        self.assertNotIn("霧", self.ko)
        self.assertNotIn("눈숲", self.ko)

    def test_enwikt_pairs_each_japanese_term_with_the_sense_korean_once(self) -> None:
        self.assertEqual(self.words(self.en, "月道"), [("달길", "월로")])
        self.assertEqual(self.en["月道"][0].readings, frozenset({"つきみち"}))
        self.assertEqual(self.words(self.en, "月路"), [("달길", "월로")])
        self.assertEqual(self.en["月路"][0].readings, frozenset())


class MergeTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        ko.build_asset(ko.SAMPLE, self.tmp / "dict", built_on=BUILT_ON)
        raw = gzip.decompress((self.tmp / "dict" / ko.ASSET_NAME).read_bytes())
        (self.tmp / "ko.sqlite").write_bytes(raw)
        self.excluded = wk.krdict_keys(self.tmp / "ko.sqlite")
        _, rows = wikt_en_rows.read_rows(wk.SAMPLE_EN)
        self.merged = wk.merge_groups(wk.kowikt_groups(_lines(wk.SAMPLE_KO)), wk.enwikt_groups(rows),
                                      self.excluded)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_glossary_keys_and_kana_pair_readings_are_left_out(self) -> None:
        self.assertIn("静森", self.excluded)
        self.assertIn("しずもり", self.excluded)
        for key in ("静森", "しずもり", "星波"):
            self.assertNotIn(key, self.merged)

    def test_only_keys_the_glossary_lacks_and_kowikt_before_enwikt(self) -> None:
        self.assertEqual(sorted(self.merged), sorted(["雪森", "雪森る", "風森", "ゆきやま", "月道", "月路"]))
        # 雪森 is in both: the Korean edition's senses only.
        self.assertEqual([g.words for g in self.merged["雪森"]], [("눈숲", "설삼"), ("겨울 숲",)])
        self.assertEqual([g.source for g in self.merged["雪森"]], ["kowikt", "kowikt"])
        self.assertEqual([g.source for g in self.merged["月道"]], ["enwikt"])


class BuildTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.dict = self.tmp / "dict"
        ko.build_asset(ko.SAMPLE, self.dict, built_on=BUILT_ON)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def build(self, out: Path, **kw) -> dict:
        return wk.build_asset(wk.SAMPLE_KO, wk.SAMPLE_EN, self.dict, out, built_on=BUILT_ON,
                              kowikt_dump=KO_DUMP, **kw)

    def unpacked(self, out: Path) -> sqlite3.Connection:
        raw = gzip.decompress((out / wk.ASSET_NAME).read_bytes())
        path = out / "check.sqlite"
        path.write_bytes(raw)
        return sqlite3.connect(path)

    def test_edition_names_both_sources_and_the_glossary_it_was_cut_against(self) -> None:
        edition = self.build(self.dict)
        self.assertEqual(edition["schema"], ko.SCHEMA_VERSION)
        self.assertEqual(edition["variant"], "lean")
        self.assertEqual([s["source"] for s in edition["sources"]], ["wiktionary", "wiktionary"])
        self.assertEqual(edition["sources"][0]["edition"], KO_DUMP)
        self.assertEqual(edition["sources"][0]["source_sha256"], _sha256(wk.SAMPLE_KO))
        self.assertEqual(edition["sources"][1]["edition"], "2026-10-01")
        self.assertEqual(edition["sources"][1]["source_sha256"], "1" * 64)
        for s in edition["sources"]:
            self.assertEqual(s["license"], "CC BY-SA 4.0")
            self.assertTrue(s["license_url"].startswith("https://creativecommons.org/licenses/by-sa/4.0"))
        self.assertIn("위키낱말사전", edition["attribution"])
        self.assertIn("CC BY-SA 4.0", edition["attribution"])
        ko_edition = json.loads((self.dict / ko.EDITION_NAME).read_text(encoding="utf-8"))
        self.assertEqual(edition["krdict_sqlite_sha256"], ko_edition["sqlite_sha256"])
        on_disk = json.loads((self.dict / wk.EDITION_NAME).read_text(encoding="utf-8"))
        self.assertEqual(on_disk, edition)
        self.assertEqual(edition["gzip_bytes"], (self.dict / wk.ASSET_NAME).stat().st_size)

    def test_the_database_has_the_glossary_schema_with_wiktionary_rows(self) -> None:
        self.build(self.dict)
        db = self.unpacked(self.dict)
        self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], ko.SCHEMA_VERSION)
        meta = dict(db.execute("SELECT key, value FROM meta"))
        self.assertEqual(meta["sources"], "wiktionary")
        self.assertEqual(meta["wiktionary.edition"], KO_DUMP)
        self.assertEqual(meta["wiktionary.license"], "CC BY-SA 4.0")
        self.assertEqual({r[0] for r in db.execute("SELECT DISTINCT source FROM sense")}, {1})
        rows = set(db.execute("SELECT j.key, j.reading, j.kind, j.ending, s.word, s.synonyms, s.sense_no "
                              "FROM ja j JOIN sense s ON s.id = j.sense_id"))
        self.assertIn(("雪森", "ゆきもり", 0, "", "눈숲", "눈숲|설삼", 1), rows)
        self.assertIn(("雪森", "ゆきもり", 0, "", "겨울 숲", "겨울 숲", 2), rows)
        self.assertIn(("雪森る", "ゆきもりる", 0, "", "눈으로 덮다", "눈으로 덮다", 1), rows)
        self.assertIn(("風森", "", 1, "だ", "바람차다", "바람차다", 1), rows)
        self.assertIn(("ゆきやま", "", 2, "", "눈산", "눈산", 1), rows)
        self.assertIn(("月道", "つきみち", 0, "", "월로", "달길|월로", 1), rows)
        self.assertNotIn("静森", {r[0] for r in rows})
        self.assertEqual(int(meta["senses"]), len(rows))

    def test_the_same_inputs_give_the_same_bytes(self) -> None:
        first = self.build(self.tmp / "a")
        second = self.build(self.tmp / "b")
        self.assertEqual(first, second)
        self.assertEqual((self.tmp / "a" / wk.ASSET_NAME).read_bytes(), (self.tmp / "b" / wk.ASSET_NAME).read_bytes())

    def test_a_source_of_another_sha256_builds_nothing(self) -> None:
        with self.assertRaises(SystemExit):
            self.build(self.tmp / "x", expect_kowikt_sha256="0" * 64)
        with self.assertRaises(SystemExit):
            self.build(self.tmp / "y", expect_en_sha256="0" * 64)
        self.assertFalse((self.tmp / "x" / wk.ASSET_NAME).exists())
        self.assertFalse((self.tmp / "y" / wk.ASSET_NAME).exists())
        self.build(self.tmp / "z", expect_kowikt_sha256=_sha256(wk.SAMPLE_KO), expect_en_sha256="1" * 64)

    def test_a_glossary_not_matching_its_edition_stops_the_build(self) -> None:
        edition = json.loads((self.dict / ko.EDITION_NAME).read_text(encoding="utf-8"))
        edition["sqlite_sha256"] = "0" * 64
        (self.dict / ko.EDITION_NAME).write_text(json.dumps(edition), encoding="utf-8")
        with self.assertRaises(SystemExit):
            self.build(self.tmp / "out")


class EnRowsTest(unittest.TestCase):
    def raw(self, lines: list[dict]) -> bytes:
        return gzip.compress("".join(json.dumps(x, ensure_ascii=False) + "\n" for x in lines).encode(), mtime=0)

    def test_rows_keep_english_senses_with_both_languages_and_name_the_stream(self) -> None:
        data = self.raw([
            {"word": "snowwood", "lang_code": "en", "translations": [
                {"lang_code": "ja", "word": "雪森", "alt": "ゆきもり", "sense": "a wood"},
                {"lang_code": "ko", "word": "눈숲", "sense": "a wood"},
                {"lang_code": "ja", "word": "雪林", "sense": "a white wood"},
                {"lang_code": "fr", "word": "neigebois", "sense": "a white wood"}]},
            {"word": "雪森", "lang_code": "ja", "translations": [
                {"lang_code": "ja", "word": "雪森"}, {"lang_code": "ko", "word": "눈숲"}]},
        ])
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "rows.jsonl"
            header = wikt_en_rows.extract(io.BytesIO(data), out, dump="2026-10-01")
            self.assertEqual(header["source_sha256"], hashlib.sha256(data).hexdigest())
            self.assertEqual(header["source_bytes"], len(data))
            read_header, rows = wikt_en_rows.read_rows(out)
            self.assertEqual(read_header, header)
            self.assertEqual(len(rows), 1)
            self.assertEqual([j["word"] for j in rows[0]["ja"]], ["雪森"])

    def test_a_stream_of_another_sha256_writes_nothing(self) -> None:
        data = self.raw([{"word": "x", "lang_code": "en"}])
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "rows.jsonl"
            with self.assertRaises(SystemExit):
                wikt_en_rows.extract(io.BytesIO(data), out, dump="2026-10-01", expect_sha256="0" * 64)
            self.assertFalse(out.exists())
            self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_a_rows_file_cut_short_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "rows.jsonl"
            lines = wk.SAMPLE_EN.read_text(encoding="utf-8").splitlines()
            out.write_text("\n".join(lines[:-1]) + "\n", encoding="utf-8")
            with self.assertRaises(SystemExit):
                wikt_en_rows.read_rows(out)


class SampleSqlTest(unittest.TestCase):
    def test_the_block_fixture_is_the_sample_built(self) -> None:
        self.assertEqual(wk.sample_sql(), FIXTURE_SQL.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
