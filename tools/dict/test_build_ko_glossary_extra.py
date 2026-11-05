"""Tests added after the review of build_ko_glossary.py (the frozen tests are in
test_build_ko_glossary.py).

  python3 -m unittest discover -s tools/dict -p 'test_*.py'
"""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import build_ko_glossary as ko  # noqa: E402

EXTRA_KEYS = HERE / "testdata" / "ko_glossary_keys_extra.json"
SAMPLE = HERE / "testdata" / "krdict_sample.json"


class ExtraKeyTableTest(unittest.TestCase):
    def test_spaces_are_the_same_set_as_in_dart(self) -> None:
        for c in json.loads(EXTRA_KEYS.read_text(encoding="utf-8"))["cases"]:
            with self.subTest(why=c["why"]):
                self.assertEqual(ko.pair_key(c["form"], c["reading"]), (c["key"], c["reading_key"]))


class TrailingEndingTest(unittest.TestCase):
    def test_an_ending_after_the_bracket_belongs_to_the_pair(self) -> None:
        self.assertEqual(ko.parse_equivalent("せいじゅく【成熟】する"),
                         [ko.Part(0, ko.PAIR, "成熟する", "せいじゅくする")])

    def test_other_kana_after_the_bracket_is_a_word_of_its_own(self) -> None:
        self.assertEqual(ko.parse_equivalent("なりゆき【成り行き】プロセス"), [
            ko.Part(0, ko.PAIR, "成り行き", "なりゆき"),
            ko.Part(0, ko.KANA, "プロセス", ""),
        ])


class FolderOrderTest(unittest.TestCase):
    def test_a_folder_is_read_in_file_number_order_like_the_zip(self) -> None:
        doc = json.loads(SAMPLE.read_text(encoding="utf-8"))
        entries = doc["LexicalResource"]["Lexicon"]["LexicalEntry"]
        with tempfile.TemporaryDirectory() as tmp:
            for n, part in ((1, entries[:10]), (2, entries[10:20]), (10, entries[20:])):
                piece = json.loads(json.dumps(doc))
                piece["LexicalResource"]["Lexicon"]["LexicalEntry"] = part
                Path(tmp, f"{n}_5000_20261019.json").write_text(json.dumps(piece, ensure_ascii=False),
                                                                encoding="utf-8")
            words = [e.word for e in ko.read_source(Path(tmp)).entries]
        self.assertEqual(words, [e.word for e in ko.read_source(SAMPLE).entries])


if __name__ == "__main__":
    unittest.main()
