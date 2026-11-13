"""asset_check.py and the built-in deck asset: a plain run passes a folder without it, a release
fails without it or on a changed file, and the dictionary checks with their own --dir never look at
the repository's deck folder (made-up decks only).

  python3 -m unittest discover -s tools/dict -p 'test_*.py'
"""
from __future__ import annotations

import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "decks"))

import asset_check  # noqa: E402
import test_build_decks  # noqa: E402

import build_decks  # noqa: E402


def run(argv: list[str]) -> tuple[int, str]:
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        code = asset_check.main(argv)
    return code, out.getvalue()


class DecksAssetCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.decks = self.tmp / "decks"
        inputs = test_build_decks.write_inputs(self.tmp / "in")
        with contextlib.redirect_stdout(io.StringIO()):
            code = build_decks.main([
                "--source", str(inputs["source"]), "--source-commit", test_build_decks.COMMIT,
                "--jmdict", str(inputs["jmdict"]), "--supplement", str(inputs["supplement"]),
                "--built-on", test_build_decks.BUILT_ON, "--out-dir", str(self.decks)])
        self.assertEqual(code, 0)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_problems_for_a_release(self) -> None:
        self.assertEqual(asset_check._decks_problems(self.decks, release=True), [])
        missing = self.tmp / "none"
        self.assertTrue(asset_check._decks_problems(missing, release=True))
        path = self.decks / build_decks.DECKS_NAME
        path.write_bytes(path.read_bytes().replace("雨傘".encode(), "雨笠".encode()))
        self.assertTrue(any("sha256" in p for p in asset_check._decks_problems(self.decks, release=True)))

    def test_a_plain_run_passes_a_folder_without_decks(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(asset_check._decks_problems(self.tmp / "none"), [])
        self.assertIn("decks: not built", out.getvalue())

    def test_a_release_names_missing_decks(self) -> None:
        code, out = run(["--release", "--dir", str(self.tmp / "dict"), "--decks-dir", str(self.tmp / "none")])
        self.assertNotEqual(code, 0)
        self.assertIn("built-in decks cannot ship", out)

    def test_another_dict_folder_leaves_the_repository_decks_alone(self) -> None:
        saved = asset_check.DEFAULT_DECKS_DIR
        asset_check.DEFAULT_DECKS_DIR = self.tmp / "none"
        try:
            _, out = run(["--dir", str(self.tmp / "dict")])
            self.assertNotIn("decks:", out)
            _, out = run(["--release", "--dir", str(self.tmp / "dict")])
            self.assertNotIn("decks:", out)
        finally:
            asset_check.DEFAULT_DECKS_DIR = saved


if __name__ == "__main__":
    unittest.main()
