"""build_accent_asset.py on a small made-up accents.txt (no network).

  cd tools/voice && python3 -m unittest discover -p 'test_*.py'
"""
from __future__ import annotations

import contextlib
import gzip
import hashlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "dict"))

import asset_check  # noqa: E402
import build_accent_asset as baa  # noqa: E402
import voice_sources as vs  # noqa: E402

# Made-up lines in the Kanjium layout: surface, reading (empty for kana words), accents.
TINY_ACCENTS = (
    "箸\tはし\t1\n"
    "雨\tあめ\t(名)1,1\n"
    "ゆっくり\t\t(副)3,(名)0\n"
    "さらさら\tさらさら\t(副)1,(形動)0,1\n"
    "記号\tきごう\t-\n"
    "\n"
    "一つ\tひとつ\t2,0\n"
)
TINY_TSV = (
    "箸\tはし\t1\n"
    "雨\tあめ\t1\n"
    "ゆっくり\t\t3,0\n"
    "さらさら\t\t1,0\n"
    "一つ\tひとつ\t2,0\n"
)


def make_fake_source(work: Path, text: str = TINY_ACCENTS) -> tuple[vs.Source, Path]:
    """The made-up accents.txt in work/src and a pin that matches it."""
    src = work / "src"
    src.mkdir(parents=True, exist_ok=True)
    data = text.encode("utf-8")
    (src / baa.SOURCE.name).write_bytes(data)
    pin = vs.Source(name=baa.SOURCE.name, url=(src / baa.SOURCE.name).as_uri(), bytes=len(data),
                    sha256=hashlib.sha256(data).hexdigest(), title=baa.SOURCE.title,
                    license=baa.SOURCE.license)
    return pin, src


def build_fake_accent(out: Path, work: Path, *, built_on: str = "2026-11-06") -> dict:
    """The accent asset in [out], built from the made-up accents.txt."""
    pin, src = make_fake_source(work)
    path = vs.obtain(pin, cache=work / "cache", source_dirs=[src])
    return baa.build_accent_asset(path, out, built_on=built_on, source=pin)


def quiet(fn, *args, **kwargs):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        return fn(*args, **kwargs)


class ConvertTest(unittest.TestCase):
    def test_only_the_accent_numbers_are_kept(self) -> None:
        self.assertEqual(baa.convert_line("雨\tあめ\t(副)1,(名)0"), "雨\tあめ\t1,0")

    def test_repeated_numbers_are_dropped_in_order(self) -> None:
        self.assertEqual(baa.convert_line("雨\tあめ\t2,(名)0,2,0"), "雨\tあめ\t2,0")
        self.assertEqual(baa.convert_line("一つ\tひとつ\t2,0"), "一つ\tひとつ\t2,0")
        self.assertEqual(baa.convert_line("箸\tはし\t10,1"), "箸\tはし\t10,1")

    def test_a_kana_word_has_an_empty_reading(self) -> None:
        self.assertEqual(baa.convert_line("さらさら\tさらさら\t0"), "さらさら\t\t0")
        self.assertEqual(baa.convert_line("ゆっくり\t\t3"), "ゆっくり\t\t3")

    def test_a_line_without_a_number_is_left_out(self) -> None:
        self.assertIsNone(baa.convert_line("記号\tきごう\t-"))
        self.assertIsNone(baa.convert_line("記号\tきごう\t(名)"))
        self.assertIsNone(baa.convert_line(""))

    def test_full_width_digits_are_not_accents(self) -> None:
        self.assertIsNone(baa.convert_line("記号\tきごう\t１"))

    def test_a_line_not_in_three_columns_is_refused(self) -> None:
        with self.assertRaises(vs.SourceError):
            baa.convert_line("箸\tはし")

    def test_the_whole_text(self) -> None:
        self.assertEqual(baa.convert_text("\ufeff" + TINY_ACCENTS.replace("\n", "\r\n")), TINY_TSV)


class AccentAssetTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_the_edition_describes_the_table(self) -> None:
        out = self.tmp / "accent"
        edition = build_fake_accent(out, self.tmp)
        saved = json.loads((out / baa.EDITION_NAME).read_text(encoding="utf-8"))
        self.assertEqual(saved, edition)
        gz = out / baa.ASSET_NAME
        raw = gzip.decompress(gz.read_bytes())
        self.assertEqual(raw.decode("utf-8"), TINY_TSV)
        self.assertFalse(raw.startswith(b"\xef\xbb\xbf"))
        data = TINY_ACCENTS.encode("utf-8")
        self.assertEqual(edition, {
            "variant": "kanjium-accents",
            "built_on": "2026-11-06",
            "gzip_bytes": gz.stat().st_size,
            "tsv_bytes": len(raw),
            "tsv_sha256": hashlib.sha256(raw).hexdigest(),
            "entries": 5,
            "source_url": (self.tmp / "src" / "accents.txt").as_uri(),
            "source_sha256": hashlib.sha256(data).hexdigest(),
            "license": "CC BY-SA 4.0",
            "attribution": baa.ATTRIBUTION,
        })

    def test_the_built_asset_passes_the_asset_check(self) -> None:
        out = self.tmp / "accent"
        build_fake_accent(out, self.tmp)
        self.assertEqual(asset_check.check_accent(out), [])

    def test_the_same_input_gives_the_same_bytes(self) -> None:
        a, b = self.tmp / "a", self.tmp / "b"
        build_fake_accent(a, self.tmp / "w")
        (self.tmp / "w" / "cache").rename(self.tmp / "first-cache")  # the second build starts afresh
        build_fake_accent(b, self.tmp / "w")
        files_a = {p.name: p.read_bytes() for p in a.iterdir()}
        self.assertEqual(files_a, {p.name: p.read_bytes() for p in b.iterdir()})
        self.assertEqual(sorted(files_a), [baa.EDITION_NAME, baa.ASSET_NAME])
        self.assertEqual(files_a[baa.ASSET_NAME][4:8], b"\0\0\0\0")

    def test_a_source_with_another_sha256_is_refused(self) -> None:
        pin, src = make_fake_source(self.tmp)
        (src / "accents.txt").write_text(TINY_ACCENTS.replace("1", "2"), encoding="utf-8")  # same size
        with self.assertRaises(vs.SourceError):
            vs.obtain(pin, cache=self.tmp / "cache", source_dirs=[src])
        # build_accent_asset checks the file it is given, too.
        with self.assertRaises(vs.SourceError):
            baa.build_accent_asset(src / "accents.txt", self.tmp / "out", built_on="2026-11-06",
                                   source=pin)
        self.assertFalse((self.tmp / "out").exists())

    def test_main_builds_checks_and_refuses(self) -> None:
        pin, src = make_fake_source(self.tmp)
        out = self.tmp / "accent"
        argv = ["--cache", str(self.tmp / "cache"), "--source-dir", str(src), "--out-dir", str(out),
                "--built-on", "2026-11-06"]
        with mock.patch.object(baa, "SOURCE", pin):
            self.assertEqual(quiet(baa.main, argv), 0)
            self.assertEqual(quiet(baa.main, ["--check", "--out-dir", str(out)]), 0)
            with self.assertRaises(SystemExit):
                quiet(baa.main, ["--cache", str(self.tmp / "empty"), "--offline",
                                 "--out-dir", str(self.tmp / "other")])


class PinTest(unittest.TestCase):
    def test_the_source_is_pinned_to_a_commit_and_a_sha256(self) -> None:
        self.assertRegex(baa.SOURCE.url,
                         r"^https://raw\.githubusercontent\.com/mifunetoshiro/kanjium/[0-9a-f]{40}/"
                         r"data/source_files/raw/accents\.txt$")
        self.assertEqual(baa.SOURCE.sha256,
                         "8bd0dd127dab32ceec94cb03ab1ba6b68858ea73421dfa1731af2f373deb4f20")
        self.assertEqual(baa.SOURCE.bytes, 3_226_405)

    def test_the_attribution_is_the_one_the_kanjium_readme_asks_for(self) -> None:
        self.assertEqual(baa.ATTRIBUTION,
                         "The pitch accent notation, verb particle data, phonetics, homonyms and other "
                         "additions or modifications to EDICT, KANJIDIC or KRADFILE were provided by "
                         "Uros O. through his free database.")


if __name__ == "__main__":
    unittest.main()
