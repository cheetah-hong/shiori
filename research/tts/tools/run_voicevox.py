#!/usr/bin/env python3
"""VOICEVOX core experiment: default accent estimate vs. accent given explicitly.

Per word (text = word + が so that flat and final-fall differ):
  base  : create_audio_query(text) — the engine guesses reading and accent
  kana  : create_audio_query_from_kana — reading and accent both given (AquesTalk-like)
  udict : user dictionary entry (pronunciation + accent_type), then text as in base
Per sentence:
  base, udict (all nouns/verbs of words.tsv in one dictionary) and edit (base phrases
  with each phrase's accent replaced by the expected one when the phrasing matches).

For every case the phrases' accent field and the H/L pattern read from mora pitch
are stored. For the base and kana cases of the main voice, a WAV is written and its
F0 is measured again per mora (Praat via parselmouth).

usage (from research/tts):
  .cache/venv/bin/python tools/run_voicevox.py --core .cache/voicevox_core \
      --audio-dir ../../.private/tts/wav --out .cache/results/voicevox.json
"""
from __future__ import annotations

import argparse
import dataclasses
import json
import sys
import time
from pathlib import Path

import accent
import engine_vv
import pitch
import words

MAIN_STYLE = 2            # 四国めたん ノーマル
# 0.vvm voices whose terms come with the model (credit only, no prior approval);
# 雨晴はう (style 10) is in the same file but its terms are not in the bundled text.
STYLES = (2, 3, 8)        # 四国めたん, ずんだもん, 春日部つむぎ (all ノーマル)
PARTICLE = "が"
SENTENCES_HEADER = ("문장", "기대 악센트구", "메모")


@dataclasses.dataclass(frozen=True)
class Sentence:
    text: str
    phrases: tuple[tuple[str, int], ...]   # (reading, nucleus)
    note: str


def load_sentences(path: Path) -> list[Sentence]:
    lines = [ln for ln in path.read_text(encoding="utf-8").splitlines() if ln.strip()]
    if not lines or tuple(lines[0].split("\t")) != SENTENCES_HEADER:
        raise ValueError(f"sentences.tsv header must be {SENTENCES_HEADER}")
    out = []
    for n, line in enumerate(lines[1:], start=2):
        cols = line.split("\t")
        if len(cols) != 3:
            raise ValueError(f"sentences line {n}: expected 3 columns")
        phrases = []
        for item in cols[1].split():
            kana, _, nuc = item.partition(":")
            if not nuc.isdigit() or int(nuc) > accent.count_morae(kana):
                raise ValueError(f"sentences line {n}: bad phrase {item!r}")
            phrases.append((kana, int(nuc)))
        out.append(Sentence(cols[0], tuple(phrases), cols[2]))
    return out


def audio_check(engine, query, wav_path: Path) -> dict:
    t0 = time.perf_counter()
    wav = engine.synth.synthesis(query, MAIN_STYLE)
    elapsed = time.perf_counter() - t0
    wav_path.parent.mkdir(parents=True, exist_ok=True)
    wav_path.write_bytes(wav)
    measured = engine_vv.measure_f0(wav_path, engine_vv.mora_spans(query))
    patterns = [pitch.pitch_pattern(p) if any(x > 0 for x in p) else "?" * len(p)
                for p in measured]
    steps = []   # (query step, audio step) where both morae are voiced in both
    for ap, f0 in zip(query.accent_phrases, measured, strict=True):
        q = [m.pitch for m in ap.moras]
        for i in range(len(q) - 1):
            if min(q[i], q[i + 1], f0[i], f0[i + 1]) > 0:
                steps.append((round(q[i + 1] - q[i], 3), round(f0[i + 1] - f0[i], 3)))
    return {"wav": wav_path.name, "synth_sec": round(elapsed, 3),
            "audio_seconds": round((len(wav) - 44) / 2 / 24000, 3),
            "f0": measured, "f0_patterns": patterns, "steps": steps}


def user_dict_for(entries):
    from voicevox_core import UserDictWord
    from voicevox_core.blocking import UserDict

    d = UserDict()
    for surface, morae, acc, word_type in entries:
        d.add_word(UserDictWord(surface=surface, pronunciation="".join(morae),
                                accent_type=acc, word_type=word_type, priority=10))
    return d


def word_type(w: words.Word) -> str:
    if w.surface.endswith("い") and w.group != "최소쌍":
        return "ADJECTIVE"
    if w.surface.endswith(("る", "た")):
        return "VERB"
    return "COMMON_NOUN"


def run_word(engine, w: words.Word, audio_dir: Path) -> dict:
    s = engine.synth
    text = w.surface + PARTICLE
    row = {"surface": w.surface, "reading": w.reading, "expected": list(w.expected)}

    t0 = time.perf_counter()
    base = s.create_audio_query(text, MAIN_STYLE)
    row["query_sec"] = round(time.perf_counter() - t0, 4)
    row["base"] = engine_vv.phrase_rows(base.accent_phrases)
    row["base_styles"] = {st: engine_vv.phrase_rows(s.create_accent_phrases(text, st))
                          for st in STYLES}
    row["base_audio"] = audio_check(engine, base, audio_dir / f"{w.surface}_{w.reading}_base.wav")

    morae = engine_vv.pron_kana(w.reading) + [engine_vv.hira_to_kata(PARTICLE)]
    kana = engine_vv.aquestalk(morae, w.expected[0])
    row["kana_input"] = kana
    kq = s.create_audio_query_from_kana(kana, MAIN_STYLE)
    row["kana"] = engine_vv.phrase_rows(kq.accent_phrases)
    row["kana_styles"] = {st: engine_vv.phrase_rows(s.create_accent_phrases_from_kana(kana, st))
                          for st in STYLES}
    row["kana_audio"] = audio_check(engine, kq, audio_dir / f"{w.surface}_{w.reading}_given.wav")

    entry = (w.surface, engine_vv.pron_kana(w.reading), w.expected[0], word_type(w))
    engine.open_jtalk.use_user_dict(user_dict_for([entry]))
    try:
        row["udict"] = engine_vv.phrase_rows(s.create_accent_phrases(text, MAIN_STYLE))
        row["udict_type"] = entry[3]
    finally:
        engine.open_jtalk.use_user_dict(user_dict_for([]))
    return row


def run_sentence(engine, sent: Sentence, dict_entries, audio_dir: Path, idx: int) -> dict:
    s = engine.synth
    row = {"text": sent.text, "expected": [list(p) for p in sent.phrases], "note": sent.note}
    t0 = time.perf_counter()
    base = s.create_audio_query(sent.text, MAIN_STYLE)
    row["query_sec"] = round(time.perf_counter() - t0, 4)
    row["base"] = engine_vv.phrase_rows(base.accent_phrases)
    row["base_audio"] = audio_check(engine, base, audio_dir / f"sentence{idx}_base.wav")

    want_morae = [accent.count_morae(k) for k, _ in sent.phrases]
    got_morae = [len(ap.moras) for ap in base.accent_phrases]
    row["aligned"] = want_morae == got_morae
    if row["aligned"]:
        edited = [dataclasses.replace(ap, accent=(len(ap.moras) if nuc == 0 else nuc))
                  for ap, (_, nuc) in zip(base.accent_phrases, sent.phrases, strict=True)]
        edited = s.replace_mora_pitch(edited, MAIN_STYLE)
        row["edit"] = engine_vv.phrase_rows(edited)
        eq = dataclasses.replace(base, accent_phrases=edited)
        row["edit_audio"] = audio_check(engine, eq, audio_dir / f"sentence{idx}_given.wav")

    engine.open_jtalk.use_user_dict(user_dict_for(dict_entries))
    try:
        row["udict"] = engine_vv.phrase_rows(s.create_accent_phrases(sent.text, MAIN_STYLE))
    finally:
        engine.open_jtalk.use_user_dict(user_dict_for([]))
    return row


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--core", type=Path, required=True)
    ap.add_argument("--words", type=Path, default=Path("words.tsv"))
    ap.add_argument("--sentences", type=Path, default=Path("sentences.tsv"))
    ap.add_argument("--audio-dir", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    t0 = time.perf_counter()
    engine = engine_vv.load_engine(args.core)
    load_sec = time.perf_counter() - t0
    word_list = words.load_words(args.words)
    sentences = load_sentences(args.sentences)

    word_rows = [run_word(engine, w, args.audio_dir) for w in word_list]
    # One dictionary for sentences: every word except the second reading of 一日
    seen = set()
    entries = []
    for w in word_list:
        if w.surface in seen:
            continue
        seen.add(w.surface)
        entries.append((w.surface, engine_vv.pron_kana(w.reading), w.expected[0], word_type(w)))
    sentence_rows = [run_sentence(engine, st, entries, args.audio_dir, i + 1)
                     for i, st in enumerate(sentences)]

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({
        "versions": engine.versions, "main_style": MAIN_STYLE, "styles": list(STYLES),
        "load_sec": round(load_sec, 3), "words": word_rows, "sentences": sentence_rows,
    }, ensure_ascii=False, indent=1))
    print(f"wrote {args.out}: {len(word_rows)} words, {len(sentence_rows)} sentences")
    return 0


if __name__ == "__main__":
    sys.exit(main())
