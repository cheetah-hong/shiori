"""The release check's speech engine files (--engine) and the app's gzip name rules."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import speech_check  # noqa: E402


class EngineCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())

    def _make(self, platform: str, skip: int | None = None, empty: int | None = None) -> None:
        for i, (rel, _) in enumerate(speech_check.ENGINE_FILES[platform]):
            if i == skip:
                continue
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"" if i == empty else b"engine")

    def test_every_file_present_passes(self) -> None:
        for platform in ("android", "ios"):
            self._make(platform)
            self.assertEqual(speech_check.check_engine(platform, self.root), [], platform)

    def test_a_missing_or_empty_file_fails(self) -> None:
        self._make("android", skip=1)
        self.assertEqual(len(speech_check.check_engine("android", self.root)), 1)
        self._make("ios", empty=0)
        problems = speech_check.check_engine("ios", self.root)
        self.assertEqual(len(problems), 1)
        self.assertIn("voicevox_core.xcframework", problems[0])

    def test_nothing_there_fails_for_each_file(self) -> None:
        self.assertEqual(len(speech_check.check_engine("android", self.root)), 3)


class GzipNameTest(unittest.TestCase):
    def test_names_the_app_accepts(self) -> None:
        for name in ("0.vvm.gz", "open_jtalk_dic.sys.dic.gz", "a-b_c.gz"):
            self.assertFalse(speech_check.unsafe_file_name(name), name)

    def test_names_the_app_refuses(self) -> None:
        for name in ("0.vvm", ".hidden.gz", "a/b.gz", "../x.gz", "sp ace.gz", "", "名前.gz"):
            self.assertTrue(speech_check.unsafe_file_name(name), name)


if __name__ == "__main__":
    unittest.main()
