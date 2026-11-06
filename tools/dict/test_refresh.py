"""D6: refresh.py with a fake download and a fake accuracy gate (no network, no dart).

  python3 -m unittest discover -s tools/dict -p 'test_*.py'
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

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import asset_check  # noqa: E402
import build_app_asset  # noqa: E402
import build_ko_glossary  # noqa: E402
import refresh  # noqa: E402
from test_build_app_asset import TINY_JMDICT  # noqa: E402

OLD_LAST_MODIFIED = "Wed, 04 Nov 2026 11:05:58 GMT"
NEW_LAST_MODIFIED = "Fri, 06 Nov 2026 03:30:26 GMT"
BUILT_ON = "2026-11-06"

NEW_JMDICT = TINY_JMDICT.replace("2026-01-02", "2026-11-06").replace(
    "</JMdict>",
    "<entry>\n<ent_seq>3</ent_seq>\n<k_ele><keb>海</keb></k_ele>\n"
    "<r_ele><reb>うみ</reb></r_ele>\n<sense><pos>&n;</pos><gloss>sea</gloss></sense>\n</entry>\n</JMdict>",
)


def gz(text: str) -> bytes:
    return gzip.compress(text.encode("utf-8"), mtime=0)


class FakeFetcher:
    """Answers every request with [body] (None: 304) or raises [error]."""

    def __init__(self, body: bytes | None, *, last_modified: str = NEW_LAST_MODIFIED,
                 content_length: int | None = -1, error: Exception | None = None) -> None:
        self.body = body
        self.last_modified = last_modified
        self.content_length = content_length
        self.error = error
        self.calls: list[tuple[str, Path, str | None]] = []

    def get(self, url: str, dest: Path, *, if_modified_since: str | None) -> refresh.Download | None:
        self.calls.append((url, dest, if_modified_since))
        if self.error is not None:
            raise self.error
        if self.body is None:
            return None
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(self.body)
        length = len(self.body) if self.content_length == -1 else self.content_length
        return refresh.Download(last_modified=self.last_modified, content_length=length)


class FakeGate:
    def __init__(self, passed: bool, reasons: tuple[str, ...] = ()) -> None:
        self.passed = passed
        self.reasons = reasons
        self.calls: list[tuple[Path, Path]] = []
        self.seen: list[tuple[dict, dict]] = []

    def __call__(self, old: Path, new: Path, work: Path) -> refresh.GateResult:
        self.calls.append((old, new))
        # The gate gets two complete asset folders: both pass the build check.
        assert asset_check.check_dir(old) == [], asset_check.check_dir(old)
        assert asset_check.check_dir(new) == [], asset_check.check_dir(new)
        self.seen.append((_editions(old), _editions(new)))
        return refresh.GateResult(passed=self.passed, reasons=self.reasons,
                                  rows=({"set": "synthetic", "found": "70/70 → 70/70"},))


def _editions(folder: Path) -> dict:
    return {name: json.loads((folder / edition).read_text(encoding="utf-8"))
            for name, (_, edition) in asset_check.ASSETS.items()}


def _snapshot(folder: Path) -> dict[str, tuple[bytes, int]]:
    return {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in sorted(folder.iterdir())}


class RefreshTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.assets = self.tmp / "assets"
        self.work = self.tmp / "work"
        source_dir = self.tmp / "old-source"
        source_dir.mkdir()
        self.old_source = source_dir / "JMdict_e.gz"
        self.old_source.write_bytes(gz(TINY_JMDICT))
        (source_dir / "JMdict_e.gz.last-modified").write_text(OLD_LAST_MODIFIED, encoding="utf-8")
        build_app_asset.build_asset(self.old_source, self.assets, built_on="2026-11-05")
        self.krdict = self.tmp / "krdict.json"
        self.krdict.write_bytes(build_ko_glossary.SAMPLE.read_bytes())
        build_ko_glossary.build_asset(self.krdict, self.assets, built_on="2026-11-05")
        self.before = _snapshot(self.assets)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_refresh(self, fetcher, gate, **kw) -> refresh.Outcome:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            return refresh.refresh(self.assets, self.work, fetcher=fetcher, gate=gate,
                                   built_on=BUILT_ON, **kw)

    def run_main(self, argv: list[str], fetcher, gate) -> tuple[int, str]:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            code = refresh.main(["--assets", str(self.assets), "--work", str(self.work),
                                 "--built-on", BUILT_ON, *argv], fetcher=fetcher, gate=gate)
        return code, buf.getvalue()

    def assert_assets_untouched(self) -> None:
        self.assertEqual(_snapshot(self.assets), self.before)

    def no_part_files_left(self) -> None:
        if self.work.exists():
            self.assertEqual([p for p in self.work.rglob("*.part")], [])

    def changed_krdict(self) -> Path:
        doc = json.loads(build_ko_glossary.SAMPLE.read_text(encoding="utf-8"))
        text = json.dumps(doc, ensure_ascii=False).replace("2026/10/19", "2026/12/01").replace(
            "2026-10-19", "2026-12-01")
        path = self.tmp / "krdict-new.json"
        path.write_text(text, encoding="utf-8")
        self.assertNotEqual(path.read_bytes(), self.krdict.read_bytes())
        return path

    # ------------------------------------------------------------ (a) unchanged

    def test_a_not_modified_answer_changes_nothing(self) -> None:
        fetcher, gate = FakeFetcher(None), FakeGate(True)
        out = self.run_refresh(fetcher, gate)
        self.assertEqual(out.status, "unchanged")
        self.assertEqual(out.changed, ())
        self.assertEqual(gate.calls, [])
        self.assertEqual(len(fetcher.calls), 1)
        self.assertEqual(fetcher.calls[0][2], OLD_LAST_MODIFIED)
        self.assert_assets_untouched()

    def test_the_same_file_again_changes_nothing(self) -> None:
        fetcher = FakeFetcher(self.old_source.read_bytes(), last_modified=OLD_LAST_MODIFIED)
        gate = FakeGate(True)
        out = self.run_refresh(fetcher, gate)
        self.assertEqual(out.status, "unchanged")
        self.assertEqual(gate.calls, [])
        self.assert_assets_untouched()

    def test_the_same_krdict_zip_changes_nothing(self) -> None:
        gate = FakeGate(True)
        out = self.run_refresh(FakeFetcher(None), gate, krdict_source=self.krdict)
        self.assertEqual(out.status, "unchanged")
        self.assertEqual(gate.calls, [])
        self.assert_assets_untouched()

    def test_unchanged_exits_0_and_says_so(self) -> None:
        code, out = self.run_main([], FakeFetcher(None), FakeGate(True))
        self.assertEqual(code, 0)
        self.assertIn("변화 없음", out)
        self.assert_assets_untouched()

    def test_without_a_krdict_zip_the_report_says_it_is_checked_by_hand(self) -> None:
        code, out = self.run_main([], FakeFetcher(None), FakeGate(True))
        self.assertEqual(code, 0)
        self.assertIn("한국어기초사전", out)
        self.assertIn("수동", out)

    # ------------------------------------------------------------ (b) changed

    def test_a_new_jmdict_is_built_gated_and_adopted(self) -> None:
        gate = FakeGate(True)
        out = self.run_refresh(FakeFetcher(gz(NEW_JMDICT)), gate)
        self.assertEqual(out.status, "adopted", out.reasons)
        self.assertEqual(out.changed, ("jmdict-full-lean",))
        self.assertEqual(len(gate.calls), 1)
        old, new = gate.seen[0]
        self.assertEqual(old["jmdict-full-lean"]["jmdict_created"], "2026-01-02")
        self.assertEqual(new["jmdict-full-lean"]["jmdict_created"], "2026-11-06")
        self.assertEqual(new["ko-glossary"], old["ko-glossary"])

        editions = _editions(self.assets)
        jm = editions["jmdict-full-lean"]
        self.assertEqual(jm["jmdict_created"], "2026-11-06")
        self.assertEqual(jm["source_last_modified"], NEW_LAST_MODIFIED)
        self.assertEqual(jm["source_sha256"], hashlib.sha256(gz(NEW_JMDICT)).hexdigest())
        self.assertEqual(jm["built_on"], BUILT_ON)
        self.assertEqual(asset_check.check_dir(self.assets), [])
        # The glossary had no new source: its files are the same bytes.
        for name in ("ko-glossary.sqlite.gz", "ko-glossary.edition.json"):
            self.assertEqual((self.assets / name).read_bytes(), self.before[name][0])
        self.assertIsNotNone(out.report)
        self.assertTrue(out.report.exists())
        self.assertTrue((self.work / "report.json").exists())
        self.no_part_files_left()

    def test_a_new_krdict_zip_is_built_gated_and_adopted(self) -> None:
        gate = FakeGate(True)
        out = self.run_refresh(FakeFetcher(None), gate, krdict_source=self.changed_krdict())
        self.assertEqual(out.status, "adopted", out.reasons)
        self.assertEqual(out.changed, ("ko-glossary",))
        self.assertEqual(len(gate.calls), 1)
        ko = _editions(self.assets)["ko-glossary"]
        self.assertEqual(ko["sources"][0]["edition"], "2026-12-01")
        for name in ("jmdict-full-lean.sqlite.gz", "jmdict-full-lean.edition.json"):
            self.assertEqual((self.assets / name).read_bytes(), self.before[name][0])
        self.assertEqual(asset_check.check_dir(self.assets), [])

    def test_dry_run_builds_and_gates_but_adopts_nothing(self) -> None:
        gate = FakeGate(True)
        out = self.run_refresh(FakeFetcher(gz(NEW_JMDICT)), gate, dry_run=True)
        self.assertEqual(out.status, "candidate")
        self.assertEqual(len(gate.calls), 1)
        self.assert_assets_untouched()
        # The candidate stays in the work folder for a look.
        self.assertEqual(asset_check.check_dir(gate.calls[0][1]), [])

    def test_the_report_names_the_editions_and_the_gate(self) -> None:
        out = self.run_refresh(FakeFetcher(gz(NEW_JMDICT)), FakeGate(True))
        report = out.report.read_text(encoding="utf-8")
        self.assertIn("2026-01-02", report)
        self.assertIn("2026-11-06", report)
        self.assertIn("synthetic", report)
        data = json.loads((self.work / "report.json").read_text(encoding="utf-8"))
        self.assertEqual(data["status"], "adopted")

    # ------------------------------------------------------------ (c) gate fails

    def test_a_failed_gate_adopts_nothing_and_keeps_the_reason(self) -> None:
        gate = FakeGate(False, reasons=("synthetic_general: found 70 → 69",))
        out = self.run_refresh(FakeFetcher(gz(NEW_JMDICT)), gate)
        self.assertEqual(out.status, "rejected")
        self.assertIn("synthetic_general: found 70 → 69", out.reasons)
        self.assert_assets_untouched()
        report = out.report.read_text(encoding="utf-8")
        self.assertIn("found 70 → 69", report)

    def test_a_failed_gate_exits_1(self) -> None:
        code, out = self.run_main([], FakeFetcher(gz(NEW_JMDICT)), FakeGate(False, ("worse",)))
        self.assertEqual(code, 1)
        self.assertIn("worse", out)
        self.assert_assets_untouched()

    # ------------------------------------------------- (d) download goes wrong

    def test_a_failed_download_touches_nothing(self) -> None:
        fetcher = FakeFetcher(None, error=refresh.FetchError("connection reset"))
        gate = FakeGate(True)
        code, out = self.run_main([], fetcher, gate)
        self.assertEqual(code, 2)
        self.assertIn("connection reset", out)
        self.assertEqual(gate.calls, [])
        self.assert_assets_untouched()
        self.no_part_files_left()

    def test_a_download_cut_short_touches_nothing(self) -> None:
        body = gz(NEW_JMDICT)
        cases = {
            "shorter than Content-Length": FakeFetcher(body[: len(body) // 2], content_length=len(body)),
            "gzip cut short": FakeFetcher(body[: len(body) - 10]),
            "not gzip": FakeFetcher(b"<html>maintenance</html>"),
            "no JMdict header date": FakeFetcher(gz(NEW_JMDICT.replace("<!-- JMdict created: 2026-11-06 -->", ""))),
        }
        for label, fetcher in cases.items():
            with self.subTest(label):
                gate = FakeGate(True)
                out = self.run_refresh(fetcher, gate)
                self.assertEqual(out.status, "failed", label)
                self.assertTrue(out.reasons, label)
                self.assertEqual(gate.calls, [], label)
                self.assert_assets_untouched()
                self.no_part_files_left()

    def test_a_previous_download_in_the_work_folder_is_not_mistaken_for_the_new_one(self) -> None:
        # A failed run leaves nothing that a later "not modified" answer would build from.
        self.run_refresh(FakeFetcher(gz(NEW_JMDICT)[:100], content_length=10_000), FakeGate(True))
        gate = FakeGate(True)
        out = self.run_refresh(FakeFetcher(None), gate)
        self.assertEqual(out.status, "unchanged")
        self.assertEqual(gate.calls, [])
        self.assert_assets_untouched()

    def test_a_missing_krdict_zip_fails_without_touching_anything(self) -> None:
        out = self.run_refresh(FakeFetcher(None), FakeGate(True), krdict_source=self.tmp / "nope.zip")
        self.assertEqual(out.status, "failed")
        self.assert_assets_untouched()


class TotalsTest(unittest.TestCase):
    OUTPUT = """dictionary: all/none JMdict 2026-11-04

== general, JMdict, glossary
page        n found read mean   sentR   sentP extra dup high hiWrong    ms exHigh
g01        14    14   14   14     9/9     9/9     0   0   11       0  27.2      0

TOTAL found=70/70 reading=70/70 meaning=68/68 sentence_recall=54/54 sentence_precision=44/44 extras=0 duplicates=0 high=42 high_wrong=0 extra_high=0 ms_per_page=20.1

== general, no dictionary
TOTAL found=65/70 reading=54/65 meaning=62/63 sentence_recall=10/54 sentence_precision=0/0 extras=3 duplicates=0 high=9 high_wrong=0 extra_high=0 ms_per_page=1.0
"""

    def test_reads_the_first_total_line(self) -> None:
        t = refresh.parse_totals(self.OUTPUT)
        self.assertEqual(t["found"], 70)
        self.assertEqual(t["high"], 42)
        self.assertEqual(t["extras"], 0)
        self.assertEqual(t["sentence_precision"], 44)

    def test_no_total_line_is_an_error(self) -> None:
        with self.assertRaises(ValueError):
            refresh.parse_totals("answers not found")

    def test_the_same_scores_are_no_regression(self) -> None:
        t = refresh.parse_totals(self.OUTPUT)
        self.assertEqual(refresh.regressions(t, dict(t)), [])

    def test_better_scores_and_slower_pages_are_no_regression(self) -> None:
        old = refresh.parse_totals(self.OUTPUT)
        new = {**old, "high": 45, "extras": 0, "ms_per_page": 99.0}
        self.assertEqual(refresh.regressions(old, new), [])

    def test_each_worse_score_is_named(self) -> None:
        old = refresh.parse_totals(self.OUTPUT)
        for key, value in [("found", 69), ("reading", 69), ("meaning", 67), ("sentence_recall", 53),
                           ("sentence_precision", 43), ("high", 41), ("extras", 1), ("duplicates", 1),
                           ("high_wrong", 1), ("extra_high", 1)]:
            with self.subTest(key):
                found = refresh.regressions(old, {**old, key: value})
                self.assertEqual(len(found), 1)
                self.assertIn(key, found[0])


if __name__ == "__main__":
    unittest.main()
