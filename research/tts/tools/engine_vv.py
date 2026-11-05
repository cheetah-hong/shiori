"""Thin helpers around the VOICEVOX core Python binding (needs the engine installed).

Kept apart from the pure modules so that the unit tests never import the engine.
"""
from __future__ import annotations

import dataclasses
import math
import os
from pathlib import Path
from typing import Any

import accent
import pitch

O_ROW = set("オコソトノホモヨロゴゾドボポョォ")
E_ROW = set("エケセテネヘメレゲゼデベペェ")


def hira_to_kata(text: str) -> str:
    return "".join(chr(ord(c) + 0x60) if "ぁ" <= c <= "ゖ" else c for c in text)


def pron_kana(reading: str) -> list[str]:
    """Reading (hiragana) -> katakana morae as pronounced: おう→オオ, えい→エエ.

    Simplified rule good enough for the word list here; it would be wrong across a
    morpheme boundary (思う おもう is not オモオ)."""
    morae = accent.split_morae(hira_to_kata(reading))
    out: list[str] = []
    for m in morae:
        prev = out[-1][-1] if out else ""
        if m == "ウ" and prev in O_ROW:
            m = "オ"
        elif m == "イ" and prev in E_ROW:
            m = "エ"
        out.append(m)
    return out


def aquestalk(morae: list[str], nucleus: int) -> str:
    """VOICEVOX kana notation: an apostrophe after the accented mora.
    Flat (0) is written as an apostrophe after the last mora."""
    pos = len(morae) if nucleus == 0 else nucleus
    return "".join(morae[:pos]) + "'" + "".join(morae[pos:])


def heavy_start(moras: list[Any]) -> bool:
    """Mora 2 is ン, ッ or a long vowel (no consonant, same vowel as mora 1)."""
    if len(moras) < 2:
        return False
    m2 = moras[1]
    if m2.text in ("ン", "ッ") or m2.vowel in ("N", "cl"):
        return True
    return m2.consonant is None and m2.vowel.lower() == moras[0].vowel.lower()


def phrase_rows(phrases: list[Any]) -> list[dict]:
    rows = []
    for ap in phrases:
        pitches = [float(m.pitch) for m in ap.moras]
        rows.append({
            "kana": "".join(m.text for m in ap.moras),
            "morae": len(ap.moras),
            "engine_accent": ap.accent,
            "nucleus": pitch.phrase_nucleus(ap.accent, len(ap.moras)),
            "pitches": [round(p, 3) for p in pitches],
            "pitch_pattern": pitch.pitch_pattern(pitches) if any(p > 0 for p in pitches) else "?" * len(pitches),
            "heavy_start": heavy_start(ap.moras),
            "pause_after": ap.pause_mora is not None,
        })
    return rows


def mora_spans(query: Any) -> list[list[tuple[float, float]]]:
    """(start, end) in seconds of each mora's vowel, per phrase, at speed 1."""
    if not math.isclose(query.speed_scale, 1.0):
        raise ValueError("timing assumes speed_scale 1.0")
    t = query.pre_phoneme_length
    spans = []
    for ap in query.accent_phrases:
        cur = []
        for m in ap.moras:
            t += m.consonant_length or 0.0
            cur.append((t, t + m.vowel_length))
            t += m.vowel_length
        pause = ap.pause_mora
        if pause is not None:
            # the binding returns this mora as a dict in some queries
            t += pause["vowel_length"] if isinstance(pause, dict) else pause.vowel_length
        spans.append(cur)
    return spans


def measure_f0(wav_path: Path, spans: list[list[tuple[float, float]]],
               floor: float = 75.0, ceiling: float = 600.0) -> list[list[float]]:
    """Median log-F0 of the voiced frames in each span (0.0 when none is voiced)."""
    import numpy as np
    import parselmouth

    snd = parselmouth.Sound(str(wav_path))
    track = snd.to_pitch(time_step=0.005, pitch_floor=floor, pitch_ceiling=ceiling)
    times = track.xs()
    values = track.selected_array["frequency"]
    out = []
    for phrase in spans:
        cur = []
        for start, end in phrase:
            sel = values[(times >= start) & (times < end) & (values > 0)]
            cur.append(round(float(np.log(np.median(sel))), 3) if len(sel) else 0.0)
        out.append(cur)
    return out


@dataclasses.dataclass
class Engine:
    synth: Any
    open_jtalk: Any
    versions: dict


def load_engine(core_dir: Path, vvm: str = "0.vvm") -> Engine:
    import voicevox_core
    from voicevox_core.blocking import Onnxruntime, OpenJtalk, Synthesizer, VoiceModelFile

    libs = sorted((core_dir / "onnxruntime" / "lib").glob("libvoicevox_onnxruntime*"))
    if not libs:
        raise FileNotFoundError(f"no ONNX Runtime under {core_dir}/onnxruntime/lib")
    dict_dirs = sorted((core_dir / "dict").glob("open_jtalk_dic_utf_8-*"))
    if not dict_dirs:
        raise FileNotFoundError(f"no Open JTalk dictionary under {core_dir}/dict")
    ort = Onnxruntime.load_once(filename=str(libs[-1]))
    oj = OpenJtalk(str(dict_dirs[-1]))
    synth = Synthesizer(ort, oj, cpu_num_threads=int(os.environ.get("VV_THREADS", "0")))
    with VoiceModelFile.open(str(core_dir / "models" / "vvms" / vvm)) as model:
        synth.load_voice_model(model)
    versions = {
        "voicevox_core": getattr(voicevox_core, "__version__", "?"),
        "onnxruntime": libs[-1].name,
        "dict": dict_dirs[-1].name,
        "vvm": vvm,
    }
    return Engine(synth, oj, versions)
