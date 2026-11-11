#!/usr/bin/env python3
"""Measure the accent experiment again with another voice (needs the engine; see README.md).

  python remeasure.py --core DIR --vvm-dir DIR [--style VVM:ID ...] [--out FILE]

Words: the 28 words + が given as kana with their accent (as the app gives a word), the
engine's accent value against the expected one and the minimal-pair checks (accent_check
of make_vv_samples.py). Sentences: the 7 sentences of ../sentences.tsv as text, with the
engine's own guess (base) and with the 28 words in a user dictionary (udict), counted by
accent phrase as in ../README.md 5: a sentence split differently counts all its phrases wrong.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "tools"))

import make_vv_samples  # noqa: E402

DEFAULT_STYLES = ("0.vvm:2", "n0.vvm:10003")  # the earlier voice and the one the app ships


def phrase_score(phrases, expected) -> tuple[int, int]:
    """(right accent phrases, expected phrases) of one sentence."""
    import accent

    if [p["morae"] for p in phrases] != [accent.count_morae(k) for k, _ in expected]:
        return 0, len(expected)
    return sum(p["nucleus"] == n for p, (_, n) in zip(phrases, expected)), len(expected)


def sentence_scores(synth, open_jtalk, style_id: int) -> dict:
    import engine_vv
    import run_voicevox
    import words

    sentences = run_voicevox.load_sentences(HERE.parent / "sentences.tsv")
    entries, seen = [], set()
    for w in words.load_words(HERE.parent / "words.tsv"):
        if w.surface not in seen:  # one entry per written form, as in the experiment
            seen.add(w.surface)
            entries.append((w.surface, engine_vv.pron_kana(w.reading), w.expected[0], run_voicevox.word_type(w)))
    result = {}
    for case in ("base", "udict"):
        if case == "udict":
            open_jtalk.use_user_dict(run_voicevox.user_dict_for(entries))
        ok = total = whole = 0
        for s in sentences:
            phrases = engine_vv.phrase_rows(synth.create_audio_query(s.text, style_id).accent_phrases)
            right, n = phrase_score(phrases, s.phrases)
            ok, total, whole = ok + right, total + n, whole + (right == n)
        result[case] = {"phrases_ok": ok, "phrases": total, "sentences_ok": whole, "sentences": len(sentences)}
    return result


def main() -> None:
    from voicevox_core.blocking import Onnxruntime, OpenJtalk, Synthesizer, VoiceModelFile

    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--core", type=Path, required=True, help="VOICEVOX core folder (onnxruntime/, dict/)")
    parser.add_argument("--vvm-dir", type=Path, required=True)
    parser.add_argument("--style", action="append", help="VVM:STYLE_ID (repeatable)")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    libs = sorted((args.core / "onnxruntime" / "lib").glob("libvoicevox_onnxruntime*"))
    dicts = sorted((args.core / "dict").glob("open_jtalk_dic_utf_8-*"))
    if not libs or not dicts:
        raise SystemExit(f"no ONNX Runtime or Open JTalk dictionary under {args.core}")
    ort = Onnxruntime.load_once(filename=str(libs[-1]))
    report = {}
    for spec in args.style or DEFAULT_STYLES:
        vvm, _, style = spec.partition(":")
        open_jtalk = OpenJtalk(str(dicts[-1]))  # fresh, so no user dictionary is left from before
        synth = Synthesizer(ort, open_jtalk)
        with VoiceModelFile.open(str(args.vvm_dir / vvm)) as model:
            synth.load_voice_model(model)
        style_id = int(style)
        report[spec] = {"words": make_vv_samples.accent_check(synth, style_id),
                        "sentences": sentence_scores(synth, open_jtalk, style_id)}
    text = json.dumps(report, ensure_ascii=False, indent=1)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
