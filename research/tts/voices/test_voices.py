#!/usr/bin/env python3
"""Unit tests for the pure helpers of the voice survey (no engine, model or network).

usage: cd research/tts/voices && python3 -m unittest test_voices -v
"""
import math
import tempfile
import unittest
from pathlib import Path, PurePosixPath

import voices

SAMPLES_HEADER = "id\tkind\ttext\treading\taccent\tmemo\n"
CANDIDATES_HEADER = "id\tengine\tvoice\tstyle_id\tmodel\tapp\tlicense\tadded_mb\taccent\tnote\tshortlist\n"


_TEMP = tempfile.TemporaryDirectory()


def tearDownModule():
    _TEMP.cleanup()


def write(text: str) -> Path:
    path = Path(tempfile.mkdtemp(dir=_TEMP.name)) / "table.tsv"
    path.write_text(text, encoding="utf-8")
    return path


class ReadSamplesTest(unittest.TestCase):
    def test_reads_words_and_sentences(self):
        path = write(SAMPLES_HEADER + "w01\tword\t箸\tはし\t1\t\ns01\tsentence\t箸で食べます。\n")
        items = voices.read_samples(path)
        self.assertEqual(items[0], voices.SampleItem("w01", "word", "箸", "はし", 1))
        self.assertEqual(items[1], voices.SampleItem("s01", "sentence", "箸で食べます。"))

    def test_flat_accent_is_zero(self):
        path = write(SAMPLES_HEADER + "w03\tword\t端\tはし\t0\t\n")
        self.assertEqual(voices.read_samples(path)[0].accent, 0)

    def test_word_without_accent_is_refused(self):
        path = write(SAMPLES_HEADER + "w01\tword\t箸\tはし\t\t\n")
        with self.assertRaises(voices.TableError):
            voices.read_samples(path)

    def test_unknown_kind_is_refused(self):
        path = write(SAMPLES_HEADER + "x01\tphrase\t箸\tはし\t1\t\n")
        with self.assertRaises(voices.TableError):
            voices.read_samples(path)

    def test_repeated_id_is_refused(self):
        path = write(SAMPLES_HEADER + "w01\tword\t箸\tはし\t1\t\nw01\tword\t橋\tはし\t2\t\n")
        with self.assertRaisesRegex(voices.TableError, "twice"):
            voices.read_samples(path)

    def test_id_with_upper_case_is_refused(self):
        path = write(SAMPLES_HEADER + "W01\tword\t箸\tはし\t1\t\n")
        with self.assertRaises(voices.TableError):
            voices.read_samples(path)

    def test_the_survey_samples_file_reads(self):
        items = voices.read_samples(Path(__file__).resolve().parent / "samples.tsv")
        self.assertEqual([i.kind for i in items].count("word"), 8)
        self.assertEqual([i.kind for i in items].count("sentence"), 3)


class ReadCandidatesTest(unittest.TestCase):
    ROW = "vv-2\tVOICEVOX\t四国めたん ノーマル\t2\t0.vvm\t가능\tcredit\t0\t28/28\t\ty\n"

    def test_reads_a_row(self):
        c = voices.read_candidates(write(CANDIDATES_HEADER + self.ROW))[0]
        self.assertEqual((c.id, c.style_id, c.added_mb, c.shortlist), ("vv-2", 2, 0.0, True))

    def test_unknown_numbers_are_none(self):
        row = "kokoro-jf-alpha\tKokoro\tjf_alpha\t-\tkokoro.onnx\t확인 못 함\tApache-2.0\t\t측정 불가\t\t\n"
        c = voices.read_candidates(write(CANDIDATES_HEADER + row))[0]
        self.assertIsNone(c.style_id)
        self.assertIsNone(c.added_mb)
        self.assertFalse(c.shortlist)

    def test_bad_number_is_refused(self):
        row = self.ROW.replace("\t0\t28/28", "\tabout 60\t28/28")
        with self.assertRaisesRegex(voices.TableError, "not a number"):
            voices.read_candidates(write(CANDIDATES_HEADER + row))

    def test_bad_shortlist_mark_is_refused(self):
        with self.assertRaises(voices.TableError):
            voices.read_candidates(write(CANDIDATES_HEADER + self.ROW.replace("\ty\n", "\tyes\n")))

    def test_repeated_id_is_refused(self):
        with self.assertRaisesRegex(voices.TableError, "vv-2"):
            voices.read_candidates(write(CANDIDATES_HEADER + self.ROW + self.ROW))

    def test_voicevox_id_must_match_its_style(self):
        with self.assertRaisesRegex(voices.TableError, "style id"):
            voices.read_candidates(write(CANDIDATES_HEADER + self.ROW.replace("\t2\t0.vvm", "\t3\t0.vvm")))

    def test_voicevox_row_needs_a_style_id(self):
        with self.assertRaises(voices.TableError):
            voices.read_candidates(write(CANDIDATES_HEADER + self.ROW.replace("\t2\t0.vvm", "\t-\t0.vvm")))

    def test_missing_column_is_refused(self):
        header = CANDIDATES_HEADER.replace("\tshortlist", "")
        with self.assertRaisesRegex(voices.TableError, "shortlist"):
            voices.read_candidates(write(header + self.ROW.rsplit("\t", 1)[0] + "\n"))


class SamplePathTest(unittest.TestCase):
    def test_path_is_relative_to_the_page(self):
        self.assertEqual(voices.sample_path("vv-10003", "w01"), PurePosixPath("samples/vv-10003/w01.wav"))

    def test_path_cannot_leave_the_folder(self):
        for bad in ("../x", "a/b", "", "A"):
            with self.subTest(bad=bad), self.assertRaises(voices.TableError):
                voices.sample_path(bad, "w01")
        with self.assertRaises(voices.TableError):
            voices.sample_path("vv-2", "../w01")


class PitchStatsTest(unittest.TestCase):
    def test_one_octave_apart(self):
        stats = voices.pitch_stats([math.log(200.0), math.log(400.0)])
        self.assertAlmostEqual(stats.mean_hz, 282.8, places=1)
        self.assertAlmostEqual(stats.range_semitones, 12.0)
        self.assertAlmostEqual(stats.sd_semitones, 6.0)

    def test_unvoiced_and_glitch_morae_are_left_out(self):
        stats = voices.pitch_stats([0.0, 1.2, math.log(220.0), math.log(220.0)])
        self.assertEqual((stats.mean_hz, stats.sd_semitones, stats.range_semitones), (220.0, 0.0, 0.0))

    def test_nothing_voiced_is_none(self):
        self.assertIsNone(voices.pitch_stats([0.0, 0.0, 2.0]))

    def test_semitones_sign(self):
        self.assertAlmostEqual(voices.semitones(440.0, 220.0), -12.0)


class MoraeRateTest(unittest.TestCase):
    def test_rate(self):
        self.assertEqual(voices.morae_per_second(14, 2.0), 7.0)

    def test_empty_is_refused(self):
        with self.assertRaises(ValueError):
            voices.morae_per_second(0, 1.0)
        with self.assertRaises(ValueError):
            voices.morae_per_second(3, 0.0)


class HtmlTest(unittest.TestCase):
    def test_escape(self):
        self.assertEqual(voices.escape("<script>"), "&lt;script&gt;")
        self.assertEqual(voices.escape(None), "")

    def test_table_escapes_the_header_and_marks_rows(self):
        html = voices.html_table(["a<b"], [["<b>x</b>"], ["y"]], ["pick", ""])
        self.assertIn("<th>a&lt;b</th>", html)
        self.assertIn('<tr class="pick"><td><b>x</b></td></tr>', html)
        self.assertIn("<tr><td>y</td></tr>", html)

    def test_audio_tag_quotes_the_path(self):
        tag = voices.audio_tag(PurePosixPath('samples/x"y/w01.wav'))
        self.assertIn('src="samples/x&quot;y/w01.wav"', tag)


if __name__ == "__main__":
    unittest.main()
