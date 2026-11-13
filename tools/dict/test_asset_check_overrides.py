"""asset_check.py and the meaning overrides asset (시오리 보정): a plain run passes a folder without
it, a release fails without it or on a changed file, and a check with its own --dir never looks at
the repository's file (a made-up table only).

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

import asset_check  # noqa: E402
import build_meaning_overrides as bmo  # noqa: E402
import test_build_meaning_overrides as t  # noqa: E402


def run(argv: list[str]) -> tuple[int, str]:
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        code = asset_check.main(argv)
    return code, out.getvalue()


class OverridesAssetCheckTest(t._Case):
    def setUp(self) -> None:
        super().setUp()
        self.build()

    def test_problems_for_a_release(self) -> None:
        self.assertEqual(asset_check._overrides_problems(self.out, release=True), [])
        self.assertTrue(asset_check._overrides_problems(self.tmp / "none", release=True))
        path = self.out / bmo.OVERRIDES_NAME
        path.write_bytes(path.read_bytes().replace("책".encode(), "칙".encode()))
        self.assertTrue(any("sha256" in p for p in asset_check._overrides_problems(self.out, release=True)))

    def test_a_plain_run_passes_a_folder_without_it(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(asset_check._overrides_problems(self.tmp / "none"), [])
        self.assertIn("meaning overrides: not built", out.getvalue())

    def test_a_plain_run_checks_a_file_that_is_there(self) -> None:
        path = self.out / bmo.OVERRIDES_NAME
        path.write_bytes(path.read_bytes() + b" ")
        self.assertTrue(asset_check._overrides_problems(self.out))

    def test_a_release_names_the_missing_file(self) -> None:
        code, out = run(["--release", "--dir", str(self.tmp / "dict"), "--overrides-dir", str(self.tmp / "none")])
        self.assertNotEqual(code, 0)
        self.assertIn("meaning overrides cannot ship", out)

    def test_another_dict_folder_leaves_the_repository_file_alone(self) -> None:
        saved = asset_check.DEFAULT_OVERRIDES_DIR
        asset_check.DEFAULT_OVERRIDES_DIR = self.tmp / "none"
        try:
            _, out = run(["--dir", str(self.tmp / "dict")])
            self.assertNotIn("meaning overrides:", out)
            _, out = run(["--release", "--dir", str(self.tmp / "dict")])
            self.assertNotIn("meaning overrides:", out)
        finally:
            asset_check.DEFAULT_OVERRIDES_DIR = saved


if __name__ == "__main__":
    unittest.main()
