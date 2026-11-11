#!/usr/bin/env python3
"""Make VOICEVOX samples for the voice survey (needs the engine; see README.md).

  python make_vv_samples.py --core DIR --vvm-dir DIR --out DIR --stats FILE [--full ID ...]

For every talk style of every voice model in --vvm-dir it reads one screening sentence
and records the engine's pitch and timing (--stats, JSON), writing the sound to
<out>/samples/vv-<style id>/screen.wav. Styles named with --full also get every item of
samples.tsv: a word as kana with its accent given (as the app does), a sentence as text.
Every sound is made at 0.85, the app's speed when the survey was made.
"""
from __future__ import annotations

import argparse
import dataclasses
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "tools"))

import voices  # noqa: E402

SURVEY_SPEED = 0.85  # the app's speed during the survey (it is 1.0 since the voice changed)
SCREEN_ITEM = "s02"
SCREEN_FILE = "screen"
PARTICLE = "が"  # as in the accent experiment: flat and final-accent words differ only before a particle
TALK_TYPES = ("talk", "streaming_talk")


def kana_for(item: voices.SampleItem) -> str:
    import engine_vv

    return engine_vv.aquestalk(engine_vv.pron_kana(item.reading), item.accent)


def query_numbers(query) -> dict:
    """Pitch and speed of a query at speed 1 (before the app's speed is applied)."""
    pitches = [m.pitch for ap in query.accent_phrases for m in ap.moras]
    seconds = sum((m.consonant_length or 0.0) + m.vowel_length
                  for ap in query.accent_phrases for m in ap.moras)
    stats = voices.pitch_stats(pitches)
    return {
        "mean_hz": stats.mean_hz if stats else None,
        "sd_semitones": stats.sd_semitones if stats else None,
        "range_semitones": stats.range_semitones if stats else None,
        "morae_per_second": voices.morae_per_second(len(pitches), seconds),
    }


def speak(synth, query, style_id: int, path: Path) -> float:
    path.parent.mkdir(parents=True, exist_ok=True)
    started = time.perf_counter()
    wav = synth.synthesis(dataclasses.replace(query, speed_scale=SURVEY_SPEED), style_id)
    path.write_bytes(wav)
    return time.perf_counter() - started


def query_for(synth, item: voices.SampleItem, style_id: int):
    if item.kind == "word":
        return synth.create_audio_query_from_kana(kana_for(item), style_id)
    return synth.create_audio_query(item.text, style_id)


def accent_check(synth, style_id: int) -> dict:
    """The accent experiment's word test for one style (research/tts/README.md 2.3):
    each word + が given as kana with its expected accent; the engine's accent value
    against the expected one, and the minimal-pair order checks on the mora pitch."""
    import engine_vv
    import make_report
    import words

    rows = []
    for w in words.load_words(HERE.parent / "words.tsv"):
        morae = engine_vv.pron_kana(w.reading) + [engine_vv.hira_to_kata(PARTICLE)]
        query = synth.create_audio_query_from_kana(engine_vv.aquestalk(morae, w.expected[0]), style_id)
        phrases = engine_vv.phrase_rows(query.accent_phrases)
        rows.append({"surface": w.surface, "reading": w.reading, "expected": list(w.expected),
                     "kana": phrases,
                     "accent_ok": len(phrases) == 1 and phrases[0]["nucleus"] in w.expected})
    contrasts = make_report.contrast_checks(rows, "kana")
    return {"accent_ok": sum(r["accent_ok"] for r in rows), "words": len(rows),
            "contrast_ok": sum(ok for _, ok in contrasts), "contrasts": len(contrasts),
            "contrast_failed": [name for name, ok in contrasts if not ok],
            "pitch_reading_ok": sum(make_report.pitch_ok(r, r["kana"]) for r in rows)}


def open_synth(core: Path):
    from voicevox_core.blocking import Onnxruntime, OpenJtalk, Synthesizer

    libs = sorted((core / "onnxruntime" / "lib").glob("libvoicevox_onnxruntime*"))
    dicts = sorted((core / "dict").glob("open_jtalk_dic_utf_8-*"))
    if not libs or not dicts:
        raise SystemExit(f"no ONNX Runtime or Open JTalk dictionary under {core}")
    ort = Onnxruntime.load_once(filename=str(libs[-1]))
    return Synthesizer(ort, OpenJtalk(str(dicts[-1])))


def model_files(vvm_dir: Path) -> list[Path]:
    """Talk models: numbered files and Nemo (n0); the song model (s0) is left out."""
    return sorted((p for p in vvm_dir.glob("*.vvm") if not p.name.startswith("s")),
                  key=lambda p: (p.name[0] == "n", int("".join(c for c in p.stem if c.isdigit()) or 0)))


def check_full(vvm_dir: Path, full: set[int]) -> None:
    """Stop before any sound is made when a --full style id is in no voice model."""
    from voicevox_core.blocking import VoiceModelFile

    known = set()
    for vvm in model_files(vvm_dir):
        with VoiceModelFile.open(str(vvm)) as model:
            known.update(style.id for character in model.metas for style in character.styles)
    missing = sorted(full - known)
    if missing:
        raise SystemExit(f"--full style ids not in any voice model: {missing}")


def run(args: argparse.Namespace) -> dict:
    from voicevox_core.blocking import VoiceModelFile

    items = {i.id: i for i in voices.read_samples(HERE / "samples.tsv")}
    screen = items[SCREEN_ITEM]
    full = set(args.full)
    check_full(args.vvm_dir, full)
    synth = open_synth(args.core)
    results = []
    for vvm in model_files(args.vvm_dir):
        with VoiceModelFile.open(str(vvm)) as model:
            synth.load_voice_model(model)
            for character in model.metas:
                for style in character.styles:
                    if style.type not in TALK_TYPES:
                        continue
                    cid = voices.voicevox_id(style.id)
                    out = args.out / voices.sample_path(cid, SCREEN_FILE)
                    query = query_for(synth, screen, style.id)
                    row = {"id": cid, "vvm": vvm.name, "speaker": character.name,
                           "style": style.name, "style_id": style.id, **query_numbers(query),
                           "seconds_to_make": round(speak(synth, query, style.id, out), 3)}
                    if style.id in full:
                        for item in items.values():
                            speak(synth, query_for(synth, item, style.id), style.id,
                                  args.out / voices.sample_path(cid, item.id))
                        row["full"] = True
                        row["accent"] = accent_check(synth, style.id)
                    results.append(row)
                    print(f"{vvm.name} {character.name} {style.name} ({style.id})", flush=True)
            synth.unload_voice_model(model.id)
    return {"screen_item": SCREEN_ITEM, "screen_text": screen.text, "speed": SURVEY_SPEED,
            "styles": results}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--core", type=Path, required=True, help="VOICEVOX core folder (onnxruntime/, dict/)")
    parser.add_argument("--vvm-dir", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True, help="the listening page folder")
    parser.add_argument("--stats", type=Path, required=True, help="JSON written here")
    parser.add_argument("--full", type=int, nargs="*", default=[], help="style ids that get every item")
    args = parser.parse_args()
    result = run(args)
    args.stats.parent.mkdir(parents=True, exist_ok=True)
    args.stats.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(result['styles'])} styles -> {args.stats}")


if __name__ == "__main__":
    main()
