"""X2: asset_check.py with the example sentence asset (made-up assets, no network).

A release needs the example asset next to the dictionaries, matching its edition. A plain
check reports it when it is there and does not fail without it (a debug build runs
without it: its cards show no filled example).

  python3 -m unittest discover -s tools/dict -p 'test_*.py'
"""
from __future__ import annotations

import contextlib
import datetime as dt
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import asset_check  # noqa: E402
import build_examples  # noqa: E402
import test_asset_check  # noqa: E402  (its made-up speech assets and builders)

EX_GZ, EX_EDITION = asset_check.FALLBACK_ASSETS["examples"]
BUILT_ON = dt.date.today().isoformat()


def setUpModule() -> None:
    test_asset_check.setUpModule()


def tearDownModule() -> None:
    test_asset_check.tearDownModule()


class ExamplesAssetCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.out = self.tmp / "assets"
        # Every dictionary asset, the example asset among them.
        test_asset_check.build_both(self.out, self.tmp, built_on=BUILT_ON)
        self.assertTrue((self.out / EX_GZ).is_file())

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def edit(self, change) -> None:
        path = self.out / EX_EDITION
        edition = json.loads(path.read_text(encoding="utf-8"))
        change(edition)
        path.write_text(json.dumps(edition, ensure_ascii=False), encoding="utf-8")

    def run_main(self, argv: list[str]) -> tuple[int, str]:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            code = asset_check.main(argv)
        return code, buf.getvalue()

    def test_a_matching_asset_passes_check_and_release(self) -> None:
        self.assertEqual(asset_check.check_asset("examples", self.out / EX_GZ, self.out / EX_EDITION), [])
        self.assertEqual(asset_check.release_problems(self.out), [])
        code, out = self.run_main(["--release", "--dir", str(self.out)])
        self.assertEqual(code, 0, out)
        self.assertIn("examples: ok", out)
        code, out = self.run_main(["--dir", str(self.out)])
        self.assertEqual(code, 0, out)
        self.assertIn("examples: ok", out)

    def test_a_missing_asset_fails_a_release_and_tells_how_to_build_it(self) -> None:
        (self.out / EX_GZ).unlink()
        problems = asset_check.release_problems(self.out)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("examples", problems[0])
        code, out = self.run_main(["--release", "--dir", str(self.out)])
        self.assertEqual(code, 1, out)
        self.assertIn("build_examples.py", out)

    def test_a_plain_check_passes_without_it_with_one_line(self) -> None:
        (self.out / EX_GZ).unlink()
        (self.out / EX_EDITION).unlink()
        code, out = self.run_main(["--dir", str(self.out)])
        self.assertEqual(code, 0, out)
        lines = [line for line in out.splitlines() if line.startswith("examples:")]
        self.assertEqual(len(lines), 1, out)
        self.assertIn("not built", lines[0])

    def test_a_damaged_asset_fails(self) -> None:
        gz = self.out / EX_GZ
        gz.write_bytes(gz.read_bytes()[:-20])
        self.assertTrue(asset_check.release_problems(self.out))
        code, out = self.run_main(["--dir", str(self.out)])
        self.assertEqual(code, 1, out)

    def test_an_edition_of_another_export_than_the_database_fails(self) -> None:
        def other(e: dict) -> None:
            e["sources"][0]["edition"] = "2020-01-04"
        self.edit(other)
        problems = asset_check.release_problems(self.out)
        self.assertTrue(any("examples" in p and "edition" in p for p in problems), problems)

    def test_a_missing_edition_field_fails(self) -> None:
        self.edit(lambda e: e.pop("attribution"))
        problems = asset_check.check_asset("examples", self.out / EX_GZ, self.out / EX_EDITION)
        self.assertTrue(any("attribution" in p for p in problems), problems)

    def test_no_age_limit(self) -> None:
        """Only JMdict has the release age limit; an old example asset still ships."""
        build_examples.build_asset(build_examples.SAMPLE_DIR,
                                   build_examples.jmdict_from_assets(self.out, self.tmp / "jm"),
                                   self.out, built_on="2020-01-04", tatoeba_export="2020-01-04")
        self.assertEqual(asset_check.release_problems(self.out), [])

    def test_the_builder_check_is_the_same_check(self) -> None:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(build_examples.main(["--check", "--out-dir", str(self.out)]), 0)
        self.assertIn("examples: ok", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
