#!/usr/bin/env python3
"""Unit tests for the pure helpers of the scan experiment (no photos, no Vision needed).

usage: cd research/scan/tools && python3 -m unittest test_tools -v
"""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import orient_eval
import page_units
import run_eval
import star_merge
import text_recall

QUAD = {"tl": [0.10, 0.05], "tr": [0.90, 0.10], "br": [0.95, 0.95], "bl": [0.05, 0.90]}


def write_fixture(path, lines):
    path.write_text(json.dumps({"engine": "test", "lines": lines}, ensure_ascii=False))


def line(t, x=0.1, y=0.1, w=0.1, h=0.01):
    return {"t": t, "c": 1, "x": x, "y": y, "w": w, "h": h}


class SquareToQuadTest(unittest.TestCase):
    def test_unit_square_corners_land_on_quad_corners(self):
        m = run_eval.square_to_quad(QUAD)
        for (u, v), key in (((0, 0), "tl"), ((1, 0), "tr"), ((1, 1), "br"), ((0, 1), "bl")):
            x, y = m(u, v)
            self.assertAlmostEqual(x, QUAD[key][0], places=9)
            self.assertAlmostEqual(y, QUAD[key][1], places=9)

    def test_centre_maps_to_diagonal_intersection(self):
        # a projective map keeps lines straight, so the square's centre lands where the quad's diagonals cross
        (x0, y0), (x2, y2) = QUAD["tl"], QUAD["br"]
        (x1, y1), (x3, y3) = QUAD["tr"], QUAD["bl"]
        den = (x0 - x2) * (y1 - y3) - (y0 - y2) * (x1 - x3)
        t = ((x0 - x1) * (y1 - y3) - (y0 - y1) * (x1 - x3)) / den
        cx, cy = x0 + t * (x2 - x0), y0 + t * (y2 - y0)
        x, y = run_eval.square_to_quad(QUAD)(0.5, 0.5)
        self.assertAlmostEqual(x, cx, places=9)
        self.assertAlmostEqual(y, cy, places=9)

    def test_axis_aligned_quad_is_plain_scaling(self):
        q = {"tl": [0.2, 0.1], "tr": [0.8, 0.1], "br": [0.8, 0.9], "bl": [0.2, 0.9]}
        x, y = run_eval.square_to_quad(q)(0.25, 0.5)
        self.assertAlmostEqual(x, 0.35)
        self.assertAlmostEqual(y, 0.5)

    def test_degenerate_quad_raises_with_the_quad_in_the_message(self):
        flat = {"tl": [0, 1], "tr": [1, 0], "br": [0, 0], "bl": [-1, 0]}  # tr, br, bl on one line
        with self.assertRaisesRegex(ValueError, "degenerate page quad"):
            run_eval.square_to_quad(flat)


class RemapFixtureTest(unittest.TestCase):
    def test_box_is_mapped_into_the_quad_and_source_is_left_alone(self):
        with tempfile.TemporaryDirectory() as d:
            src, dst = Path(d) / "a.json", Path(d) / "b.json"
            write_fixture(src, [line("川", x=0.0, y=0.0, w=1.0, h=1.0)])
            before = src.read_text()
            run_eval.remap_fixture(src, dst, QUAD)
            mapped = json.loads(dst.read_text())["lines"][0]
            self.assertEqual(src.read_text(), before)
        self.assertEqual(mapped["t"], "川")
        self.assertAlmostEqual(mapped["x"], 0.05)  # bounding box of the whole quad
        self.assertAlmostEqual(mapped["y"], 0.05)
        self.assertAlmostEqual(mapped["x"] + mapped["w"], 0.95)
        self.assertAlmostEqual(mapped["y"] + mapped["h"], 0.95)


PARSE_EVAL_OUT = (
    "page tpl  n found head read pos  mean star row  exJA exKO meta\n"
    "  12 list 15    15   13   15   15   14   15   12    -    - ok\n"
    " 157 entry 6     6    6    6    6    6    5    5    6    6 ok\n"
    " 158 entry12    12   12   12   12   12   11   10   12   12 ok\n\n"
    "TOTAL  headword=57/59  row=52/59\n"
    "core fields wrong but NOT flagged (silent errors): 1\n"
    "core fields wrong and flagged for review: 3;  flagged but actually correct: 3\n")


class ScoreParsingTest(unittest.TestCase):
    def test_totals_and_per_page_rows_including_a_two_digit_entry_page(self):
        r = run_eval.parse_scores(PARSE_EVAL_OUT)
        self.assertEqual(r["row"], (52, 59))
        self.assertEqual(r["silent"], 1)
        self.assertEqual((r["flagged_wrong"], r["flagged_ok"]), (3, 3))
        self.assertEqual(r["per_page_rows"], {"p012": 12, "p157": 5, "p158": 10})

    def test_unexpected_output_raises_instead_of_scoring_nothing(self):
        with self.assertRaisesRegex(ValueError, "not understood"):
            run_eval.parse_scores("Traceback (most recent call last): ...")

    def test_score_writes_the_raw_output_next_to_the_summary(self):
        with tempfile.TemporaryDirectory() as d, mock.patch.object(run_eval, "run", return_value=PARSE_EVAL_OUT):
            scores = Path(d) / "new-scores"
            r = run_eval.score(Path(d), "x", scores)
            self.assertTrue((scores / "x.txt").exists())
        self.assertEqual(r["row"], (52, 59))

    def test_partial_baseline_is_not_reused(self):
        pages = {"s010": ("a.jpg", -90), "s140": ("b.jpg", 0)}
        with tempfile.TemporaryDirectory() as d:
            fx = Path(d)
            for page in pages:
                (fx / f"{page}.ja.json").write_text("{}")
            self.assertFalse(run_eval.fixtures_complete(fx, pages))
            for page in pages:
                (fx / f"{page}.ko.json").write_text("{}")
            self.assertTrue(run_eval.fixtures_complete(fx, pages))


class PageTableTest(unittest.TestCase):
    def test_photo_table_is_read_from_the_photo_folder(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "pages.json").write_text(json.dumps({"pages": {"s010": {"photo": "a.jpg", "rotate": -90}}}))
            self.assertEqual(run_eval.load_pages(Path(d)), {"s010": ("a.jpg", -90)})

    def test_missing_or_broken_table_stops_with_a_message(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaisesRegex(SystemExit, "local only"):
                run_eval.load_pages(Path(d))
            (Path(d) / "pages.json").write_text(json.dumps({"pages": {"s010": {"photo": "a.jpg"}}}))
            with self.assertRaisesRegex(SystemExit, "expected"):
                run_eval.load_pages(Path(d))

    def test_outputs_go_to_the_private_folder_not_the_repository(self):
        self.assertNotIn(run_eval.SCAN, run_eval.WORK.parents)
        self.assertEqual(run_eval.WORK.parts[-2:], ("textbook", "scan"))


class RunEvalArgsTest(unittest.TestCase):
    def test_tag_starting_with_a_dash_and_scan_options_after_double_dash(self):
        args, extra = run_eval.parse_args(["--process", "--tag", "-nowarp", "--", "--detector", "none"])
        self.assertTrue(args.process)
        self.assertEqual(args.tag, "-nowarp")
        self.assertEqual(extra, ["--detector", "none"])

    def test_defaults(self):
        args, extra = run_eval.parse_args([])
        self.assertEqual((args.tag, extra), ("", []))
        self.assertEqual(args.variants.split(","), run_eval.ALL_VARIANTS)


class TextRecallHelpersTest(unittest.TestCase):
    def test_id_checkbox_and_star_are_removed(self):
        self.assertIn("川", text_recall.head_candidates("0015 ロロロ 川★"))
        self.assertIn("川", text_recall.head_candidates("★ 0015 川"))

    def test_real_katakana_is_not_eaten_by_the_checkbox_pattern(self):
        self.assertIn("コレラ", text_recall.head_candidates("コレラ"))

    def test_kana_keeps_slash_separated_readings(self):
        self.assertEqual(text_recall.kana("★ あした / あす"), "あした/あす")

    def test_coverage_counts_matched_characters(self):
        self.assertEqual(text_recall.coverage("abcd", "xxabcdxx"), 1.0)
        self.assertEqual(text_recall.coverage("abcd", "ab"), 0.5)

    def test_sentence_split_over_two_lines_with_furigana_matches(self):
        lines = ["ひこうき", "飛行機は予定より早く", "とうちゃく", "到着しました。"]
        self.assertGreaterEqual(text_recall.best_coverage("飛行機は予定より早く到着しました。", lines), 0.9)

    def test_scattered_characters_across_the_page_do_not_add_up(self):
        sentence = "abcdefgh"
        filler = ["-" * 20] * 5
        lines = [x for c in sentence for x in [c] + filler]  # one character every six lines
        self.assertTrue(text_recall.coverage(sentence, "".join(lines)) >= 0.9)  # the old whole-page measure
        self.assertLess(text_recall.best_coverage(sentence, lines), 0.9)

    def test_recall_counts_fields_on_a_tiny_page(self):
        page = {"fixture": "p001", "entries": [
            {"headword": "川", "readings": ["かわ"], "meaning": "강, 개천", "important": True},
            {"headword": "海", "readings": ["うみ"], "meaning": "바다", "important": False}]}
        with tempfile.TemporaryDirectory() as d:
            fx = Path(d)
            write_fixture(fx / "p001.ja.json", [line("0015 ロロロ 川"), line("★"), line("かわ", y=0.2)])
            write_fixture(fx / "p001.ko.json", [line("명 강, 개천")])
            tot, stars = text_recall.recall(fx, [page])
        self.assertEqual(tot["headword"], [1, 2])
        self.assertEqual(tot["reading"], [1, 2])
        self.assertEqual(tot["meaning"], [1, 2])
        self.assertEqual(stars, [1, 1])


class PageUnitsTest(unittest.TestCase):
    def test_shrink_keeps_the_centre_and_scales_sizes(self):
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "page"
            src.mkdir()
            write_fixture(src / "p001.ja.json", [line("x", x=0.5, y=0.0, w=0.2, h=0.1)])
            dst = page_units.shrink(src, 0.8)
            shrunk = json.loads((dst / "p001.ja.json").read_text())["lines"][0]
        self.assertEqual(dst.name, "page-K80")
        self.assertAlmostEqual(shrunk["x"], 0.5)
        self.assertAlmostEqual(shrunk["y"], 0.1)
        self.assertAlmostEqual(shrunk["w"], 0.16)

    def test_folder_name_rounds_instead_of_truncating(self):
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "page"
            src.mkdir()
            self.assertEqual(page_units.shrink(src, 0.29).name, "page-K29")  # int(0.29 * 100) == 28


class StarMergeTest(unittest.TestCase):
    def test_only_star_glyphs_are_added_and_legend_is_skipped(self):
        with tempfile.TemporaryDirectory() as d:
            base, src, out = Path(d) / "base", Path(d) / "src", Path(d) / "out"
            base.mkdir()
            src.mkdir()
            write_fixture(base / "p001.ja.json", [line("かわ", x=0.4, w=0.04)])
            write_fixture(base / "p001.ko.json", [])
            write_fixture(src / "p001.ja.json", [line("★ かわ", x=0.39, w=0.08),
                                                 line("★표시 = 2010년", x=0.5, y=0.02, w=0.2)])
            star_merge.merge(base, src, out)
            merged = json.loads((out / "p001.ja.json").read_text())["lines"]
        self.assertEqual([l["t"] for l in merged], ["かわ", "★"])
        self.assertAlmostEqual(merged[1]["x"], 0.39)  # star is the first character of its source line

    def test_every_star_in_a_line_is_taken(self):
        stars = star_merge.star_lines([line("★ かわ ☆ うみ", x=0.0, w=0.9)])
        self.assertEqual(len(stars), 2)
        self.assertAlmostEqual(stars[1]["x"], 0.5)  # 6th of 9 characters


@unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow not installed")
class ContactSheetTest(unittest.TestCase):
    def test_rotation_comes_from_the_meta_or_the_photo_table(self):
        import contact_sheet
        from PIL import Image
        with tempfile.TemporaryDirectory() as d:
            photo = Path(d) / "a.png"
            Image.new("RGB", (40, 20)).save(photo)
            self.assertEqual(contact_sheet.upright({"name": "s010", "photo": photo, "rotate": 90}).size, (20, 40))
            pages = {"s010": ("a.png", -90)}
            self.assertEqual(contact_sheet.upright({"name": "s010", "photo": photo}, pages).size, (20, 40))
            self.assertEqual(contact_sheet.upright({"name": "s011", "photo": photo}, pages).size, (40, 20))


class OrientationTableTest(unittest.TestCase):
    def test_turning_by_k_quarters_needs_the_opposite_correction(self):
        expected = {0: 0, 1: -90, 2: 180, 3: 90}
        for k, corr in expected.items():
            self.assertEqual(orient_eval.NORM[(-k * 90) % 360], corr)


if __name__ == "__main__":
    unittest.main()
