"""Review follow-ups of build_wikt_glossary.py and wikt_en_rows.py (made-up words only).

  python3 -m unittest discover -s tools/dict -p 'test_*.py'
"""
from __future__ import annotations

import io
import gzip
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import build_wikt_glossary as wk  # noqa: E402
import wikt_en_rows  # noqa: E402


class TranslationWordsTest(unittest.TestCase):
    def test_a_hanja_spelling_in_brackets_goes_even_with_hangul_in_it(self) -> None:
        self.assertEqual(wk.translation_words("눈숲나무(雪숲木)"), ["눈숲나무"])
        self.assertEqual(wk.translation_words("남쪽숲(南쪽森)자리"), ["남쪽숲자리"])

    def test_a_piece_with_japanese_left_is_dropped(self) -> None:
        self.assertEqual(wk.translation_words("눈숲 ゆきもり, 설삼"), ["설삼"])

    def test_separators_inside_brackets_do_not_split(self) -> None:
        self.assertEqual(wk.translation_words("숲(을/를) 덮다, 뒤덮다"), ["숲을/를 덮다", "뒤덮다"])


class RowsFileTest(unittest.TestCase):
    def test_a_rows_file_cut_inside_a_row_is_refused_with_a_message(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "rows.jsonl"
            text = wk.SAMPLE_EN.read_text(encoding="utf-8")
            first = text.index("\n") + 1
            out.write_text(text[: first + 40], encoding="utf-8")
            with self.assertRaises(SystemExit) as caught:
                wikt_en_rows.read_rows(out)
            self.assertIn("cut short", str(caught.exception.code))

    def test_extract_leaves_no_temporary_files(self) -> None:
        data = gzip.compress(json.dumps({"word": "snowwood", "lang_code": "en", "translations": [
            {"lang_code": "ja", "word": "雪森", "sense": "s"},
            {"lang_code": "ko", "word": "눈숲", "sense": "s"}]}, ensure_ascii=False).encode() + b"\n", mtime=0)
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "rows.jsonl"
            wikt_en_rows.extract(io.BytesIO(data), out, dump="2026-10-01")
            self.assertEqual([p.name for p in Path(tmp).iterdir()], ["rows.jsonl"])


if __name__ == "__main__":
    unittest.main()
