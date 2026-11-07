"""W2: asset_check.py with the Wiktionary fallback glossary (made-up assets, no network).

A release needs the fallback glossary next to the other dictionaries, matching its
edition and cut against the Basic Korean Dictionary asset it sits with. A plain check
reports it when it is there and does not fail without it (debug builds run without it).

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
import build_ko_glossary  # noqa: E402
import build_wikt_glossary  # noqa: E402
import test_asset_check  # noqa: E402  (its made-up speech assets and builders)

WK_GZ, WK_EDITION = asset_check.FALLBACK_ASSETS["wikt-glossary"]
KO_GZ, KO_EDITION = asset_check.ASSETS["ko-glossary"]
BUILT_ON = dt.date.today().isoformat()


def setUpModule() -> None:
    test_asset_check.setUpModule()


def tearDownModule() -> None:
    test_asset_check.tearDownModule()


class WiktAssetCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.out = self.tmp / "assets"
        # The JMdict and Basic Korean Dictionary assets, then the fallback cut against them.
        test_asset_check.build_both(self.out, self.tmp, built_on=BUILT_ON)
        self.assertTrue((self.out / WK_GZ).is_file())

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def edit(self, name: str, change) -> None:
        path = self.out / name
        edition = json.loads(path.read_text(encoding="utf-8"))
        change(edition)
        path.write_text(json.dumps(edition, ensure_ascii=False), encoding="utf-8")

    def run_main(self, argv: list[str]) -> tuple[int, str]:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            code = asset_check.main(argv)
        return code, buf.getvalue()

    def test_a_matching_fallback_passes_check_and_release(self) -> None:
        self.assertEqual(asset_check.check_asset("wikt-glossary", self.out / WK_GZ, self.out / WK_EDITION), [])
        self.assertEqual(asset_check.release_problems(self.out), [])
        code, out = self.run_main(["--release", "--dir", str(self.out)])
        self.assertEqual(code, 0, out)
        self.assertIn("wikt-glossary: ok", out)
        code, out = self.run_main(["--dir", str(self.out)])
        self.assertEqual(code, 0, out)
        self.assertIn("wikt-glossary: ok", out)

    def test_a_missing_fallback_fails_a_release_and_tells_how_to_build_it(self) -> None:
        (self.out / WK_GZ).unlink()
        problems = asset_check.release_problems(self.out)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("wikt-glossary", problems[0])
        code, out = self.run_main(["--release", "--dir", str(self.out)])
        self.assertEqual(code, 1)
        self.assertIn("error:", out)
        self.assertIn("python3 tools/dict/build_wikt_glossary.py", out)
        self.assertNotIn("build_ko_glossary.py", out)

    def test_without_the_fallback_a_plain_check_still_passes(self) -> None:
        (self.out / WK_GZ).unlink()
        (self.out / WK_EDITION).unlink()
        code, out = self.run_main(["--dir", str(self.out)])
        self.assertEqual(code, 0, out)
        self.assertIn("wikt-glossary: not built", out)
        self.assertIn("ko-glossary: ok", out)

    def test_a_damaged_fallback_fails_a_release(self) -> None:
        data = (self.out / WK_GZ).read_bytes()
        (self.out / WK_GZ).write_bytes(data[: len(data) // 2])
        problems = asset_check.release_problems(self.out)
        self.assertTrue(problems)
        self.assertTrue(all("wikt-glossary" in p for p in problems), problems)
        code, _ = self.run_main(["--dir", str(self.out)])
        self.assertEqual(code, 1)

    def test_a_fallback_not_matching_its_edition_fails_a_release(self) -> None:
        self.edit(WK_EDITION, lambda e: e.update(sqlite_sha256="0" * 64))
        problems = asset_check.release_problems(self.out)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("wikt-glossary", problems[0])
        self.assertIn("sqlite_sha256", problems[0])

    def test_a_fallback_of_another_edition_than_its_database_fails(self) -> None:
        self.edit(WK_EDITION, lambda e: e["sources"][0].update(edition="2020-01-01"))
        problems = asset_check.release_problems(self.out)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("edition", problems[0])

    def test_a_fallback_cut_against_another_glossary_fails_a_release(self) -> None:
        # The Basic Korean Dictionary was rebuilt (another edition) after the fallback.
        self.edit(WK_EDITION, lambda e: e.update(krdict_sqlite_sha256="0" * 64))
        problems = asset_check.release_problems(self.out)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("wikt-glossary", problems[0])
        self.assertIn("krdict_sqlite_sha256", problems[0])
        code, out = self.run_main(["--release", "--dir", str(self.out)])
        self.assertEqual(code, 1)
        self.assertIn("python3 tools/dict/build_wikt_glossary.py", out)

    def test_a_missing_edition_field_fails_and_names_it(self) -> None:
        for field in ("attribution", "sources", "krdict_sqlite_sha256"):
            with self.subTest(field=field):
                self.edit(WK_EDITION, lambda e: e.pop(field))
                problems = asset_check.check_asset("wikt-glossary", self.out / WK_GZ, self.out / WK_EDITION)
                self.assertTrue(any(field in p for p in problems), problems)
                test_asset_check.build_both(self.out, self.tmp, built_on=BUILT_ON)

    def test_the_fallback_has_no_age_limit(self) -> None:
        old = (dt.date.today() - dt.timedelta(days=400)).isoformat()
        self.edit(WK_EDITION, lambda e: e.update(built_on=old))
        self.assertEqual(asset_check.release_problems(self.out), [])

    def test_the_builder_check_flag_checks_its_own_asset(self) -> None:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = build_wikt_glossary.main(["--check", "--out-dir", str(self.out)])
        self.assertEqual(code, 0, buf.getvalue())
        self.assertIn("wikt-glossary: ok", buf.getvalue())
        self.assertNotIn("jmdict", buf.getvalue())
        self.edit(WK_EDITION, lambda e: e.update(gzip_bytes=1))
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(build_wikt_glossary.main(["--check", "--out-dir", str(self.out)]), 1)

    def test_the_glossary_and_its_fallback_names_are_known(self) -> None:
        self.assertEqual(build_wikt_glossary.ASSET_NAME, WK_GZ)
        self.assertEqual(build_wikt_glossary.EDITION_NAME, WK_EDITION)
        self.assertNotEqual(build_ko_glossary.ASSET_NAME, WK_GZ)


if __name__ == "__main__":
    unittest.main()
