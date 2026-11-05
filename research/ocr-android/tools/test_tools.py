"""Unit tests for the fixture converter and the ML Kit parser rules.

run: python3 -m unittest discover -s tools -p 'test_*.py'   (from research/ocr-android; score_all.sh runs it first)
"""
import importlib.util
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import raw_to_fixture as rf  # noqa: E402


def load_parser():
    spec = importlib.util.spec_from_file_location("parse_eval_mlkit", HERE.parent / "parse_eval_mlkit.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


pe = load_parser()


def sym(t, l, r, c=0.9):
    return {"t": t, "c": c, "box": [l, 0, r, 10]}


def element(t, symbols, box=None, c=0.8):
    box = box or ([symbols[0]["box"][0], 0, symbols[-1]["box"][2], 10] if symbols else None)
    return {"t": t, "c": c, "box": box, "symbols": symbols}


def line(elements, box=(0, 0, 100, 10), c=0.7, angle=0.0):
    return {"t": " ".join(e["t"] for e in elements), "c": c, "angle": angle, "box": list(box) if box else None,
            "elements": elements}


class RunsAndSegments(unittest.TestCase):
    def test_star_symbol_is_its_own_run(self):
        runs = rf.runs(element("★かわ", [sym("★", 0, 5), sym("か", 8, 12), sym("わ", 12, 16)]))
        self.assertEqual([(r["t"], r["star"]) for r in runs], [("★", True), ("かわ", False)])

    def test_element_without_any_box_is_dropped(self):
        self.assertEqual(rf.runs(element("x", [], box=None)), [])

    def test_wide_gap_cuts_the_line_and_keeps_line_height(self):
        ln = line([element("到着", [sym("到", 0, 10), sym("着", 10, 20)]), element("とうちゃく", [sym("とうちゃく", 40, 70)])],
                  box=(0, 2, 70, 12))
        segs = rf.segments(ln)
        self.assertEqual([s["t"] for s in segs], ["到着", "とうちゃく"])
        self.assertEqual(segs[1]["box"], [40, 2, 70, 12])

    def test_narrow_gap_returns_the_line_unchanged(self):
        ln = line([element("명", [sym("명", 0, 10)]), element("바다", [sym("바다", 15, 35)])])
        self.assertEqual(rf.segments(ln), [ln])

    def test_line_without_box_gives_no_segments(self):
        self.assertEqual(rf.segments(line([element("a", [sym("a", 0, 5)])], box=None)), [])

    def test_segment_confidence_is_the_symbol_mean(self):
        ln = line([element("★|", [sym("★", 0, 5, c=0.2), sym("|", 5, 6, c=0.1)]),
                   element("ゆれる", [sym("ゆれる", 8, 38, c=0.8)])])
        segs = rf.segments(ln)
        self.assertEqual([s["t"] for s in segs], ["★", "| ゆれる"])
        self.assertAlmostEqual(segs[1]["c"], (0.1 + 0.8) / 2)


class Rotation(unittest.TestCase):
    def raw(self, angle, rotation=0, w=4, h=3):
        return {"input_w": w, "input_h": h, "input_rotation": rotation,
                "blocks": [{"box": [0, 0, 1, 1], "lines": [line([element("abc", [sym("abc", 0, 1)])], box=(0, 0, 1, 1),
                                                                 angle=angle)]}]}

    def test_turns_from_angle_plus_passed_rotation(self):
        self.assertEqual(rf.text_turns(self.raw(-90)), 1)
        self.assertEqual(rf.text_turns(self.raw(-90, rotation=90)), 0)  # angle is in the unrotated bitmap frame
        self.assertEqual(rf.text_turns(self.raw(179)), 2)
        self.assertEqual(rf.text_turns(self.raw(45)), 0)                # unclear: leave as is

    def test_quarter_turn_maps_boxes_clockwise_and_four_turns_are_identity(self):
        raw = self.raw(-90)
        once = rf.turned(raw, 1)
        self.assertEqual(once["frame"], (3, 4))
        self.assertEqual(once["blocks"][0]["lines"][0]["box"], [2, 0, 3, 1])  # [H-b, l, H-t, r]
        four = rf.turned(raw, 4)
        self.assertEqual(four["blocks"][0]["lines"][0]["box"], [0, 0, 1, 1])
        self.assertEqual(raw["blocks"][0]["lines"][0]["box"], [0, 0, 1, 1])   # input not mutated

    def test_fixture_normalizes_by_the_rotated_frame(self):
        raw = dict(self.raw(0, rotation=90), lang="ja", ms=1)
        fx, _ = rf.to_fixture(raw, "line")
        self.assertEqual((fx["lines"][0]["w"], fx["lines"][0]["h"]), (round(1 / 3, 4), 0.25))


class ParserRules(unittest.TestCase):
    def test_id_digits(self):
        self.assertEqual(pe.id_digits("O007"), "0007")
        self.assertEqual(pe.id_digits("DO17"), "0017")
        self.assertIsNone(pe.id_digits("DOOD"))  # needs two real digits

    def test_star_split(self):
        out = pe.split_stars([pe.Line({"t": "★かわ", "c": 0.7, "x": 0.4, "y": 0.1, "w": 0.06, "h": 0.01})])
        self.assertEqual([l.t for l in out], ["★", "かわ"])
        self.assertLess(out[0].x, out[1].x)
        lone = pe.split_stars([pe.Line({"t": "*", "c": 0.1, "x": 0.3, "y": 0.1, "w": 0.01, "h": 0.01})])
        self.assertEqual(lone[0].t, "★")

    def test_readings(self):
        self.assertEqual(pe.parse_readings("| ひかる で"), ["ひかる"])
        self.assertEqual(pe.parse_readings("のリかえる"), ["のりかえる"])
        self.assertEqual(pe.parse_readings("あした/あす"), ["あした", "あす"])
        self.assertEqual(pe.parse_readings("–"), [])

    def test_pos_badges_and_meaning(self):
        self.assertEqual(pe.split_pos("8 불다"), ("동", "불다"))
        self.assertEqual(pe.split_pos("8,여덟"), (None, "8,여덟"))
        self.assertEqual(pe.clean_meaning("싸다. 포장하다."), "싸다, 포장하다")

    def test_glued_badge(self):
        rows = [{"meaning": "명 바다", "mx": 0.600}, {"meaning": "명산", "mx": 0.604}, {"meaning": "명 하늘", "mx": 0.601},
                {"meaning": "명3, 셋", "mx": 0.62}, {"meaning": "동생", "mx": 0.630}]
        pe.unglue_badges(rows)
        self.assertEqual([r["meaning"] for r in rows], ["명 바다", "명 산", "명 하늘", "명 3, 셋", "동생"])

    def test_infer_pos(self):
        self.assertEqual(pe.infer_pos("光る"), "동")
        self.assertEqual(pe.infer_pos("天気"), "명")
        self.assertIsNone(pe.infer_pos("のんびり"))

    def test_interpolate_ids(self):
        self.assertEqual(pe.interpolate_ids([None, None, "0103", None]), ["0101", "0102", "0103", "0104"])
        self.assertEqual(pe.interpolate_ids([None, "0000"]), [None, "0000"])  # never negative
        self.assertEqual(pe.interpolate_ids([None, None]), [None, None])


if __name__ == "__main__":
    unittest.main()
