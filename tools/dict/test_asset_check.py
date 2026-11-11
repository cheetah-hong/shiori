"""D1: asset_check.py and the builders' --check on small made-up assets (no network).

The voice and accent assets have their own folders (--voice-dir, --accent-dir). For the
whole module those default to made-up assets built here, so the checks of the
dictionaries do not depend on what app/assets/ holds.

  python3 -m unittest discover -s tools/dict -p 'test_*.py'
"""
from __future__ import annotations

import contextlib
import datetime as dt
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
sys.path.insert(0, str(HERE.parent / "voice"))

import asset_check  # noqa: E402
import build_app_asset  # noqa: E402
import build_examples  # noqa: E402
import build_ko_glossary  # noqa: E402
import build_wikt_glossary  # noqa: E402
from test_build_accent_asset import build_fake_accent  # noqa: E402
from test_build_app_asset import TINY_JMDICT  # noqa: E402
from test_build_voice_asset import build_fake_voice  # noqa: E402

JM_GZ, JM_EDITION = asset_check.ASSETS["jmdict-full-lean"]
KO_GZ, KO_EDITION = asset_check.ASSETS["ko-glossary"]
VOICE_EDITION = asset_check.VOICE_EDITION
ACCENT_GZ, ACCENT_EDITION = asset_check.ACCENT_FILES

_speech_tmp: tempfile.TemporaryDirectory | None = None
_saved_defaults: tuple[Path, Path] | None = None


def setUpModule() -> None:
    """Good made-up voice and accent assets in the default folders main() checks."""
    global _speech_tmp, _saved_defaults
    _speech_tmp = tempfile.TemporaryDirectory()
    root = Path(_speech_tmp.name)
    build_fake_voice(root / "voice", root / "voice-work")
    build_fake_accent(root / "accent", root / "accent-work")
    _saved_defaults = (asset_check.DEFAULT_VOICE_DIR, asset_check.DEFAULT_ACCENT_DIR)
    asset_check.DEFAULT_VOICE_DIR = root / "voice"
    asset_check.DEFAULT_ACCENT_DIR = root / "accent"


def tearDownModule() -> None:
    asset_check.DEFAULT_VOICE_DIR, asset_check.DEFAULT_ACCENT_DIR = _saved_defaults
    _speech_tmp.cleanup()


def build_both(out: Path, work: Path, *, built_on: str = "2026-11-05") -> None:
    """Both assets in [out], built from the made-up sources, the Wiktionary fallback
    glossary cut against them and the example sentences (a release needs both too)."""
    source = work / "JMdict_e.gz"
    source.write_bytes(gzip.compress(TINY_JMDICT.encode("utf-8"), mtime=0))
    build_app_asset.build_asset(source, out, built_on=built_on)
    build_ko_glossary.build_asset(build_ko_glossary.SAMPLE, out, built_on=built_on)
    build_wikt_glossary.build_asset(build_wikt_glossary.SAMPLE_KO, build_wikt_glossary.SAMPLE_EN, out, out,
                                    built_on=built_on, kowikt_dump="2026-11-01")
    build_examples.build_asset(build_examples.SAMPLE_DIR, build_examples.jmdict_from_assets(out, work / "jm"),
                               out, built_on=built_on, tatoeba_export="2026-11-07")


class AssetCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.out = self.tmp / "assets"
        build_both(self.out, self.tmp)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def edit_edition(self, name: str, change) -> None:
        path = self.out / name
        edition = json.loads(path.read_text(encoding="utf-8"))
        change(edition)
        path.write_text(json.dumps(edition, ensure_ascii=False), encoding="utf-8")

    def run_main(self, argv: list[str]) -> tuple[int, str]:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            code = asset_check.main(argv)
        return code, buf.getvalue()

    def assert_one_line_each(self, problems: list[str]) -> None:
        self.assertTrue(problems)
        for p in problems:
            self.assertNotIn("\n", p)

    # -------------------------------------------------------------- good assets

    def test_matching_assets_pass(self) -> None:
        self.assertEqual(asset_check.check_dir(self.out), [])
        code, out = self.run_main(["--dir", str(self.out)])
        self.assertEqual(code, 0)
        self.assertIn("jmdict-full-lean", out)
        self.assertIn("ko-glossary", out)

    def test_a_single_asset_can_be_checked(self) -> None:
        problems = asset_check.check_asset("ko-glossary", self.out / KO_GZ, self.out / KO_EDITION)
        self.assertEqual(problems, [])

    # ---------------------------------------------------------- what goes wrong

    def test_a_different_sqlite_sha256_fails_and_says_so(self) -> None:
        self.edit_edition(JM_EDITION, lambda e: e.update(sqlite_sha256="0" * 64))
        problems = asset_check.check_dir(self.out)
        self.assert_one_line_each(problems)
        self.assertEqual(len(problems), 1)
        self.assertIn("jmdict-full-lean", problems[0])
        self.assertIn("sqlite_sha256", problems[0])
        code, out = self.run_main(["--dir", str(self.out)])
        self.assertNotEqual(code, 0)
        self.assertIn("sqlite_sha256", out)

    def test_a_different_gzip_size_fails_and_says_so(self) -> None:
        self.edit_edition(KO_EDITION, lambda e: e.update(gzip_bytes=e["gzip_bytes"] + 1))
        problems = asset_check.check_dir(self.out)
        self.assert_one_line_each(problems)
        self.assertTrue(any("ko-glossary" in p and "gzip_bytes" in p for p in problems))
        code, _ = self.run_main(["--dir", str(self.out)])
        self.assertNotEqual(code, 0)

    def test_a_different_sqlite_size_fails(self) -> None:
        self.edit_edition(JM_EDITION, lambda e: e.update(sqlite_bytes=e["sqlite_bytes"] - 1))
        problems = asset_check.check_dir(self.out)
        self.assertTrue(any("sqlite_bytes" in p for p in problems))

    def test_a_gzip_cut_short_fails(self) -> None:
        gz = self.out / JM_GZ
        data = gz.read_bytes()
        gz.write_bytes(data[: len(data) // 2])
        # Even with the edition claiming the cut size, the content gives it away.
        self.edit_edition(JM_EDITION, lambda e: e.update(gzip_bytes=len(data) // 2))
        problems = asset_check.check_dir(self.out)
        self.assert_one_line_each(problems)
        self.assertTrue(any("jmdict-full-lean" in p for p in problems))

    def test_a_missing_edition_field_fails_and_names_it(self) -> None:
        cases = [
            (JM_EDITION, "sqlite_bytes", lambda e: e.pop("sqlite_bytes")),
            (JM_EDITION, "jmdict_created", lambda e: e.pop("jmdict_created")),
            (JM_EDITION, "source_sha256", lambda e: e.pop("source_sha256")),
            (KO_EDITION, "sqlite_sha256", lambda e: e.pop("sqlite_sha256")),
            (KO_EDITION, "license", lambda e: e["sources"][0].pop("license")),
            (KO_EDITION, "attribution", lambda e: e.pop("attribution")),
        ]
        for name, field, change in cases:
            with self.subTest(field=field):
                build_both(self.out, self.tmp)
                self.edit_edition(name, change)
                problems = asset_check.check_dir(self.out)
                self.assert_one_line_each(problems)
                self.assertTrue(any(field in p for p in problems), problems)
                code, _ = self.run_main(["--dir", str(self.out)])
                self.assertNotEqual(code, 0)

    def test_a_missing_file_fails(self) -> None:
        (self.out / KO_GZ).unlink()
        problems = asset_check.check_dir(self.out)
        self.assert_one_line_each(problems)
        self.assertTrue(any("ko-glossary" in p for p in problems))

    def test_an_edition_that_is_not_json_fails(self) -> None:
        (self.out / JM_EDITION).write_text("not json", encoding="utf-8")
        problems = asset_check.check_dir(self.out)
        self.assert_one_line_each(problems)

    def test_a_database_from_another_source_than_the_edition_fails(self) -> None:
        # Edition and gzip agree on size and sha256, but the database inside was
        # built from another JMdict file than the edition names.
        self.edit_edition(JM_EDITION, lambda e: e.update(source_sha256="1" * 64))
        problems = asset_check.check_dir(self.out)
        self.assert_one_line_each(problems)
        self.assertTrue(any("source_sha256" in p for p in problems))

    def test_a_glossary_of_another_edition_than_its_file_says_fails(self) -> None:
        def other_edition(e: dict) -> None:
            e["sources"][0]["edition"] = "2020-01-01"
        self.edit_edition(KO_EDITION, other_edition)
        problems = asset_check.check_dir(self.out)
        self.assertTrue(any("edition" in p for p in problems))

    # ----------------------------------------------------------------- age

    def test_age_is_not_checked_by_default(self) -> None:
        far = dt.date(2030, 1, 1)
        self.assertEqual(asset_check.check_dir(self.out, today=far), [])

    def test_max_age_days_fails_an_old_build(self) -> None:
        late = dt.date(2026, 12, 20)  # 45 days after 2026-11-05
        problems = asset_check.check_dir(self.out, max_age_days=35, today=late)
        self.assert_one_line_each(problems)
        self.assertEqual(len(problems), 2)
        self.assertTrue(all("built_on" in p for p in problems))
        self.assertEqual(asset_check.check_dir(self.out, max_age_days=45, today=late), [])


class ReleaseCheckTest(unittest.TestCase):
    """--release: what a release build runs. JMdict also has an age limit, the glossary does not."""

    BUILT_ON = dt.date(2026, 11, 5)

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.out = self.tmp / "assets"
        build_both(self.out, self.tmp, built_on=self.BUILT_ON.isoformat())

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def days_after(self, days: int) -> dt.date:
        return self.BUILT_ON + dt.timedelta(days=days)

    def edit_edition(self, name: str, change) -> None:
        path = self.out / name
        edition = json.loads(path.read_text(encoding="utf-8"))
        change(edition)
        path.write_text(json.dumps(edition, ensure_ascii=False), encoding="utf-8")

    def run_main(self, argv: list[str]) -> tuple[int, str]:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            code = asset_check.main(argv)
        return code, buf.getvalue()

    def test_the_release_limit_is_35_days(self) -> None:
        self.assertEqual(asset_check.RELEASE_MAX_AGE_DAYS, 35)

    def test_jmdict_35_days_old_passes_and_36_days_old_fails(self) -> None:
        self.assertEqual(asset_check.release_problems(self.out, today=self.days_after(35)), [])
        problems = asset_check.release_problems(self.out, today=self.days_after(36))
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("jmdict-full-lean", problems[0])
        self.assertIn("built_on", problems[0])
        self.assertNotIn("\n", problems[0])

    def test_the_same_boundary_holds_for_max_age_days_35(self) -> None:
        self.assertEqual(asset_check.check_dir(self.out, max_age_days=35, today=self.days_after(35)), [])
        self.assertTrue(asset_check.check_dir(self.out, max_age_days=35, today=self.days_after(36)))

    def test_an_old_glossary_passes_a_release(self) -> None:
        late = self.days_after(36)
        self.edit_edition(JM_EDITION, lambda e: e.update(built_on=late.isoformat()))
        self.assertEqual(asset_check.release_problems(self.out, today=late), [])
        # --max-age-days still covers every asset.
        self.assertTrue(any("ko-glossary" in p for p in
                            asset_check.check_dir(self.out, max_age_days=35, today=late)))

    def test_a_glossary_not_matching_its_edition_fails_a_release(self) -> None:
        self.edit_edition(KO_EDITION, lambda e: e.update(sqlite_sha256="0" * 64))
        problems = asset_check.release_problems(self.out, today=self.BUILT_ON)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("ko-glossary", problems[0])
        self.assertIn("sqlite_sha256", problems[0])

    def test_main_release_uses_today_and_the_35_day_limit(self) -> None:
        today = dt.date.today()
        for days, want in ((35, 0), (36, 1)):
            with self.subTest(days=days):
                built_on = (today - dt.timedelta(days=days)).isoformat()
                self.edit_edition(JM_EDITION, lambda e: e.update(built_on=built_on))
                code, out = self.run_main(["--release", "--dir", str(self.out)])
                self.assertEqual(code, want, out)

    def test_a_too_old_jmdict_tells_how_to_refresh(self) -> None:
        old = (dt.date.today() - dt.timedelta(days=40)).isoformat()
        self.edit_edition(JM_EDITION, lambda e: e.update(built_on=old))
        code, out = self.run_main(["--release", "--dir", str(self.out)])
        self.assertEqual(code, 1)
        self.assertIn("error:", out)
        self.assertIn("python3 tools/dict/refresh.py", out)
        self.assertNotIn("build_ko_glossary.py", out)

    def test_a_mismatch_tells_how_to_rebuild_that_asset(self) -> None:
        today = dt.date.today().isoformat()
        self.edit_edition(JM_EDITION, lambda e: e.update(built_on=today))
        self.edit_edition(KO_EDITION, lambda e: e.update(gzip_bytes=e["gzip_bytes"] + 1))
        code, out = self.run_main(["--release", "--dir", str(self.out)])
        self.assertEqual(code, 1)
        self.assertIn("error:", out)
        self.assertIn("python3 tools/dict/build_ko_glossary.py", out)
        self.assertNotIn("build_app_asset.py", out)
        self.assertNotIn("refresh.py", out)

    def test_release_and_max_age_days_do_not_go_together(self) -> None:
        with self.assertRaises(SystemExit):
            self.run_main(["--release", "--max-age-days", "10", "--dir", str(self.out)])


class BuilderCheckFlagTest(unittest.TestCase):
    """build_app_asset.py --check and build_ko_glossary.py --check check their own asset."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.out = self.tmp / "assets"
        build_both(self.out, self.tmp)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def quiet(self, fn, argv: list[str]) -> int:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            return fn(argv)

    def test_check_passes_on_a_good_asset_and_builds_nothing(self) -> None:
        before = {p.name: p.read_bytes() for p in self.out.iterdir()}
        self.assertEqual(self.quiet(build_app_asset.main, ["--check", "--out-dir", str(self.out)]), 0)
        self.assertEqual(self.quiet(build_ko_glossary.main, ["--check", "--out-dir", str(self.out)]), 0)
        self.assertEqual({p.name: p.read_bytes() for p in self.out.iterdir()}, before)

    def test_check_fails_on_its_own_asset_only(self) -> None:
        path = self.out / KO_EDITION
        edition = json.loads(path.read_text(encoding="utf-8"))
        edition["sqlite_sha256"] = "0" * 64
        path.write_text(json.dumps(edition, ensure_ascii=False), encoding="utf-8")
        self.assertNotEqual(self.quiet(build_ko_glossary.main, ["--check", "--out-dir", str(self.out)]), 0)
        self.assertEqual(self.quiet(build_app_asset.main, ["--check", "--out-dir", str(self.out)]), 0)

    def test_check_takes_max_age_days(self) -> None:
        # Built on 2026-11-05: a generous limit passes, an edition from 2000 fails a 35-day one.
        self.assertEqual(self.quiet(build_app_asset.main,
                                    ["--check", "--out-dir", str(self.out), "--max-age-days", "100000"]), 0)
        old = self.out / JM_EDITION
        edition = json.loads(old.read_text(encoding="utf-8"))
        edition["built_on"] = "2000-01-01"
        old.write_text(json.dumps(edition), encoding="utf-8")
        self.assertNotEqual(self.quiet(build_app_asset.main,
                                       ["--check", "--out-dir", str(self.out), "--max-age-days", "35"]), 0)


class SpeechAssetCase(unittest.TestCase):
    """Made-up voice and accent assets in their own folders, next to good dictionaries."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.dict_dir = self.tmp / "dict"
        build_both(self.dict_dir, self.tmp, built_on=dt.date.today().isoformat())
        self.voice = self.tmp / "voice"
        self.accent = self.tmp / "accent"
        build_fake_voice(self.voice, self.tmp / "voice-work")
        build_fake_accent(self.accent, self.tmp / "accent-work")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def edit(self, path: Path, change) -> None:
        edition = json.loads(path.read_text(encoding="utf-8"))
        change(edition)
        path.write_text(json.dumps(edition, ensure_ascii=False), encoding="utf-8")

    def edit_file_entry(self, index: int, **fields) -> None:
        self.edit(self.voice / VOICE_EDITION, lambda e: e["files"][index].update(fields))

    def run_main(self, argv: list[str]) -> tuple[int, str]:
        buf = io.StringIO()
        dirs = ["--dir", str(self.dict_dir), "--voice-dir", str(self.voice),
                "--accent-dir", str(self.accent)]
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            code = asset_check.main(argv + dirs)
        return code, buf.getvalue()

    def assert_fails(self, problems: list[str], name: str, *words: str) -> None:
        self.assertTrue(problems)
        for p in problems:
            self.assertNotIn("\n", p)
            self.assertTrue(p.startswith(f"{name}: "), p)
        for word in words:
            self.assertTrue(any(word in p for p in problems), (word, problems))


class VoiceCheckTest(SpeechAssetCase):
    def test_a_matching_voice_asset_passes(self) -> None:
        self.assertEqual(asset_check.check_voice(self.voice), [])
        code, out = self.run_main([])
        self.assertEqual(code, 0, out)
        self.assertIn("voice: ok", out)
        self.assertIn("jmdict-full-lean: ok", out)

    def test_the_shipped_voice_is_nemo_style_10003(self) -> None:
        self.assertEqual(asset_check.VOICE_VARIANT, "voicevox-0.17.1-n0vvm-style10003")
        self.assertEqual(asset_check.VOICE_MODEL_FILE, "n0.vvm")
        self.assertEqual(asset_check.VOICE_STYLE_ID, 10003)

    def test_an_asset_of_the_old_voice_fails_and_says_how_to_rebuild(self) -> None:
        old = {"variant": "voicevox-0.17.1-0vvm-style2", "model_file": "0.vvm", "style_id": 2}
        for field, value in old.items():
            with self.subTest(field=field):
                build_fake_voice(self.voice, self.tmp / f"again-{field}")
                self.edit(self.voice / VOICE_EDITION, lambda e: e.update({field: value}))
                self.assert_fails(asset_check.check_voice(self.voice), "voice", field, str(value))
        self.edit(self.voice / VOICE_EDITION, lambda e: e.update(old))
        code, out = self.run_main(["--release"])
        self.assertEqual(code, 1, out)
        self.assertIn("voicevox-0.17.1-n0vvm-style10003", out)
        self.assertIn("python3 tools/voice/build_voice_asset.py", out)
        self.assertIn("speech assets cannot ship", out)

    def test_a_gzip_the_edition_does_not_list_fails(self) -> None:
        # the app bundles the whole voice folder, so a left-over model would ship
        (self.voice / "0.vvm.gz").write_bytes(b"old model")
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "0.vvm.gz")
        code, out = self.run_main(["--release"])
        self.assertEqual(code, 1, out)

    def test_a_different_gzip_size_fails(self) -> None:
        self.edit_file_entry(0, gzip_bytes=1)
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "gzip_bytes", "n0.vvm")
        code, out = self.run_main([])
        self.assertEqual(code, 1)
        self.assertIn("python3 tools/voice/build_voice_asset.py", out)

    def test_a_different_size_or_sha256_fails(self) -> None:
        self.edit_file_entry(3, sha256="0" * 64)
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "sha256")
        build_fake_voice(self.voice, self.tmp / "again")
        self.edit_file_entry(2, bytes=7)
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "bytes")

    def test_a_missing_file_fails(self) -> None:
        (self.voice / "open_jtalk_dic.sys.dic.gz").unlink()
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "open_jtalk_dic.sys.dic.gz")
        (self.voice / VOICE_EDITION).unlink()
        self.assert_fails(asset_check.check_voice(self.voice), "voice", VOICE_EDITION)
        code, _ = self.run_main([])
        self.assertEqual(code, 1)

    def test_a_gzip_cut_short_fails(self) -> None:
        gz = self.voice / "n0.vvm.gz"
        data = gz.read_bytes()
        gz.write_bytes(data[: len(data) // 2])
        self.edit_file_entry(0, gzip_bytes=len(data) // 2)
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "n0.vvm.gz")

    def test_an_unsafe_path_fails(self) -> None:
        for bad in ("../0.vvm", "open_jtalk_dic_utf_8-1.11/../../x", "/tmp/0.vvm", "a\\..\\b", "",
                    "C:/x", "./0.vvm"):
            with self.subTest(path=bad):
                build_fake_voice(self.voice, self.tmp / "again")
                self.edit_file_entry(1, path=bad)
                self.assert_fails(asset_check.check_voice(self.voice), "voice", "path")

    def test_an_unsafe_gzip_name_fails(self) -> None:
        for bad in ("../0.vvm.gz", "sub/0.vvm.gz", "..", ""):
            with self.subTest(gzip=bad):
                build_fake_voice(self.voice, self.tmp / "again")
                self.edit_file_entry(0, gzip=bad)
                self.assert_fails(asset_check.check_voice(self.voice), "voice", "gzip")

    def test_an_unsafe_dictionary_dir_or_model_file_fails(self) -> None:
        self.edit(self.voice / VOICE_EDITION, lambda e: e.update(dictionary_dir="../dic"))
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "dictionary_dir")
        build_fake_voice(self.voice, self.tmp / "again")
        self.edit(self.voice / VOICE_EDITION, lambda e: e.update(model_file="/0.vvm"))
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "model_file")

    def test_a_missing_field_fails_and_names_it(self) -> None:
        cases = [
            ("style_id", lambda e: e.pop("style_id")),
            ("credit", lambda e: e.pop("credit")),
            ("files", lambda e: e.update(files=[])),
            ("license", lambda e: e["sources"][0].pop("license")),
            ("sha256", lambda e: e["files"][0].pop("sha256")),
        ]
        for field, change in cases:
            with self.subTest(field=field):
                build_fake_voice(self.voice, self.tmp / "again")
                self.edit(self.voice / VOICE_EDITION, change)
                self.assert_fails(asset_check.check_voice(self.voice), "voice", field)

    def test_a_style_id_that_is_not_a_number_fails(self) -> None:
        self.edit(self.voice / VOICE_EDITION, lambda e: e.update(style_id="2"))
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "style_id")

    def test_an_edition_missing_a_dictionary_file_fails(self) -> None:
        self.edit(self.voice / VOICE_EDITION, lambda e: e.update(
            files=[f for f in e["files"] if not f["path"].endswith("/matrix.bin")]))
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "matrix.bin")

    def test_an_edition_without_the_model_fails(self) -> None:
        self.edit(self.voice / VOICE_EDITION, lambda e: e.update(model_file="1.vvm"))
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "1.vvm")

    def test_an_edition_that_is_not_json_fails(self) -> None:
        (self.voice / VOICE_EDITION).write_text("not json", encoding="utf-8")
        self.assert_fails(asset_check.check_voice(self.voice), "voice", "JSON")


class AccentCheckTest(SpeechAssetCase):
    def test_a_matching_accent_asset_passes(self) -> None:
        self.assertEqual(asset_check.check_accent(self.accent), [])
        code, out = self.run_main([])
        self.assertEqual(code, 0, out)
        self.assertIn("accent: ok", out)

    def test_a_different_gzip_size_fails(self) -> None:
        self.edit(self.accent / ACCENT_EDITION, lambda e: e.update(gzip_bytes=e["gzip_bytes"] + 1))
        self.assert_fails(asset_check.check_accent(self.accent), "accent", "gzip_bytes")
        code, out = self.run_main([])
        self.assertEqual(code, 1)
        self.assertIn("python3 tools/voice/build_accent_asset.py", out)

    def test_a_different_sha256_or_size_fails(self) -> None:
        self.edit(self.accent / ACCENT_EDITION, lambda e: e.update(tsv_sha256="f" * 64))
        self.assert_fails(asset_check.check_accent(self.accent), "accent", "tsv_sha256")
        build_fake_accent(self.accent, self.tmp / "again")
        self.edit(self.accent / ACCENT_EDITION, lambda e: e.update(tsv_bytes=3))
        self.assert_fails(asset_check.check_accent(self.accent), "accent", "tsv_bytes")

    def test_a_different_entry_count_fails(self) -> None:
        self.edit(self.accent / ACCENT_EDITION, lambda e: e.update(entries=e["entries"] + 1))
        self.assert_fails(asset_check.check_accent(self.accent), "accent", "entries")

    def test_a_missing_file_fails(self) -> None:
        (self.accent / ACCENT_GZ).unlink()
        self.assert_fails(asset_check.check_accent(self.accent), "accent", ACCENT_GZ)

    def test_a_missing_field_fails_and_names_it(self) -> None:
        for field in ("attribution", "license", "source_sha256", "entries"):
            with self.subTest(field=field):
                build_fake_accent(self.accent, self.tmp / "again")
                self.edit(self.accent / ACCENT_EDITION, lambda e: e.pop(field))
                self.assert_fails(asset_check.check_accent(self.accent), "accent", field)


class SpeechReleaseTest(SpeechAssetCase):
    def test_a_release_passes_with_every_asset_matching(self) -> None:
        code, out = self.run_main(["--release"])
        self.assertEqual(code, 0, out)
        for name in ("jmdict-full-lean", "ko-glossary", "voice", "accent"):
            self.assertIn(f"{name}: ok", out)

    def test_a_release_checks_the_voice_asset(self) -> None:
        self.edit_file_entry(0, sha256="0" * 64)
        code, out = self.run_main(["--release"])
        self.assertEqual(code, 1)
        self.assertIn("voice: ", out)
        self.assertIn("error:", out)
        self.assertIn("python3 tools/voice/build_voice_asset.py", out)
        self.assertNotIn("build_accent_asset.py", out)
        self.assertNotIn("The dictionary assets cannot ship", out)
        self.assertIn("jmdict-full-lean: ok", out)

    def test_a_release_checks_the_accent_asset(self) -> None:
        (self.accent / ACCENT_EDITION).unlink()
        code, out = self.run_main(["--release"])
        self.assertEqual(code, 1)
        self.assertIn("accent: ", out)
        self.assertIn("python3 tools/voice/build_accent_asset.py", out)
        self.assertNotIn("build_voice_asset.py", out)

    def test_a_release_with_an_unsafe_voice_path_fails(self) -> None:
        self.edit_file_entry(1, path="../../outside")
        code, out = self.run_main(["--release"])
        self.assertEqual(code, 1)
        self.assertIn("path", out)

    def test_old_speech_assets_still_pass_a_release(self) -> None:
        # Only JMdict has an age limit; the voice and accent assets are pinned editions.
        old = (dt.date.today() - dt.timedelta(days=400)).isoformat()
        self.edit(self.voice / VOICE_EDITION, lambda e: e.update(built_on=old))
        self.edit(self.accent / ACCENT_EDITION, lambda e: e.update(built_on=old))
        code, out = self.run_main(["--release"])
        self.assertEqual(code, 0, out)

    def test_the_default_folders_are_next_to_the_dictionary_folder(self) -> None:
        self.assertEqual(asset_check.REPO_VOICE_DIR.parent, asset_check.DEFAULT_DIR.parent)
        self.assertEqual(asset_check.REPO_VOICE_DIR.name, "voice")
        self.assertEqual(asset_check.REPO_ACCENT_DIR.name, "accent")


class SelfConsistencyTest(unittest.TestCase):
    def test_the_fields_checked_are_the_fields_the_builders_write(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "assets"
            build_both(out, Path(tmp))
            for name, (gz_name, edition_name) in asset_check.ASSETS.items():
                edition = json.loads((out / edition_name).read_text(encoding="utf-8"))
                raw = gzip.decompress((out / gz_name).read_bytes())
                self.assertEqual(edition["sqlite_sha256"], hashlib.sha256(raw).hexdigest(), name)
                db = Path(tmp) / f"{name}.sqlite"
                db.write_bytes(raw)
                with sqlite3.connect(db) as conn:
                    self.assertTrue(dict(conn.execute("SELECT key, value FROM meta")), name)


if __name__ == "__main__":
    unittest.main()
