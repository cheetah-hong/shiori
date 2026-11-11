"""Pure helpers for the voice survey: sample texts, candidate table, file names, pitch numbers.

No engine, model or network is needed here, so the unit tests import only this file.
"""
from __future__ import annotations

import csv
import html
import math
import re
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Iterable, Mapping, Sequence

ID_PATTERN = re.compile(r"[a-z0-9][a-z0-9-]*")
SAMPLE_KINDS = ("word", "sentence")
SEMITONES_PER_OCTAVE = 12.0
AUDIO_DIR = "samples"
AUDIO_SUFFIX = ".wav"
VOICEVOX_ENGINE = "VOICEVOX"  # a candidate of this engine is named vv-<style id>
# a mora pitch at or below log(50 Hz) is a whisper or a glitch, not speech pitch
MIN_VOICED_LOG_F0 = math.log(50.0)


class TableError(ValueError):
    """A TSV row is missing a column or holds a value of the wrong shape."""


@dataclass(frozen=True)
class SampleItem:
    id: str
    kind: str  # "word" or "sentence"
    text: str
    reading: str = ""
    accent: int | None = None  # nucleus position, 0 = flat; words only


@dataclass(frozen=True)
class Candidate:
    id: str
    engine: str
    voice: str  # speaker and style as the engine names them
    style_id: int | None  # VOICEVOX style id; None for other engines
    model: str  # model file or package
    app: str  # 가능 / 조건부 / 불가 / 확인 못 함
    license: str  # one line
    added_mb: float | None  # device size added compared with the current app (None: unknown)
    accent: str  # how accent can be given, or the measured score
    note: str = ""
    shortlist: bool = False  # True: a full sample set is made and shown first


def _rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def _require(row: Mapping[str, str | None], column: str, where: str) -> str:
    value = row.get(column)
    if value is None:
        raise TableError(f"{where}: no column {column!r}")
    return value.strip()


def check_id(value: str, where: str) -> str:
    if not ID_PATTERN.fullmatch(value):
        raise TableError(f"{where}: id {value!r} must be lower-case letters, digits and hyphens")
    return value


def parse_sample(row: Mapping[str, str | None], where: str) -> SampleItem:
    item_id = check_id(_require(row, "id", where), where)
    kind = _require(row, "kind", where)
    if kind not in SAMPLE_KINDS:
        raise TableError(f"{where}: kind {kind!r} is not one of {SAMPLE_KINDS}")
    text = _require(row, "text", where)
    if not text:
        raise TableError(f"{where}: empty text")
    # trailing empty columns may be missing from a sentence row
    reading = (row.get("reading") or "").strip()
    accent_text = (row.get("accent") or "").strip()
    if kind == "sentence":
        return SampleItem(item_id, kind, text)
    if not reading or not accent_text.isdigit():
        raise TableError(f"{where}: a word needs a reading and a whole-number accent")
    return SampleItem(item_id, kind, text, reading, int(accent_text))


def read_samples(path: Path) -> list[SampleItem]:
    items = [parse_sample(row, f"{path.name}:{n}") for n, row in enumerate(_rows(path), start=2)]
    seen: set[str] = set()
    for item in items:
        if item.id in seen:
            raise TableError(f"{path.name}: id {item.id!r} appears twice")
        seen.add(item.id)
    return items


def _optional_number(text: str, where: str, kind: type) -> float | int | None:
    if text in ("", "-"):
        return None
    try:
        return kind(text)
    except ValueError as e:
        raise TableError(f"{where}: {text!r} is not a number") from e


def parse_candidate(row: Mapping[str, str | None], where: str) -> Candidate:
    shortlist = _require(row, "shortlist", where)
    if shortlist not in ("", "y"):
        raise TableError(f"{where}: shortlist must be empty or 'y'")
    return Candidate(
        id=check_id(_require(row, "id", where), where),
        engine=_require(row, "engine", where),
        voice=_require(row, "voice", where),
        style_id=_optional_number(_require(row, "style_id", where), where, int),
        model=_require(row, "model", where),
        app=_require(row, "app", where),
        license=_require(row, "license", where),
        added_mb=_optional_number(_require(row, "added_mb", where), where, float),
        accent=_require(row, "accent", where),
        note=_require(row, "note", where),
        shortlist=shortlist == "y",
    )


def voicevox_id(style_id: int) -> str:
    return f"vv-{style_id}"


def read_candidates(path: Path) -> list[Candidate]:
    rows = [parse_candidate(row, f"{path.name}:{n}") for n, row in enumerate(_rows(path), start=2)]
    for c in rows:
        if c.engine.startswith(VOICEVOX_ENGINE) and (c.style_id is None or c.id != voicevox_id(c.style_id)):
            raise TableError(f"{path.name}: {c.id!r} must be named after its style id ({c.style_id})")
    ids = [c.id for c in rows]
    duplicates = sorted({i for i in ids if ids.count(i) > 1})
    if duplicates:
        raise TableError(f"{path.name}: ids appear twice: {', '.join(duplicates)}")
    return rows


def sample_path(candidate_id: str, item_id: str) -> PurePosixPath:
    """Where a sample sits, relative to the listening page."""
    check_id(candidate_id, "candidate")
    check_id(item_id, "item")
    return PurePosixPath(AUDIO_DIR) / candidate_id / f"{item_id}{AUDIO_SUFFIX}"


def semitones(hz_from: float, hz_to: float) -> float:
    return SEMITONES_PER_OCTAVE * math.log2(hz_to / hz_from)


@dataclass(frozen=True)
class PitchStats:
    mean_hz: float
    sd_semitones: float  # spread of the voiced morae around their mean
    range_semitones: float  # highest voiced mora above the lowest


def pitch_stats(log_f0: Iterable[float]) -> PitchStats | None:
    """Numbers for the voiced morae of a query (pitch is natural-log Hz, 0 = unvoiced;
    values at or below MIN_VOICED_LOG_F0 count as unvoiced).

    None when no mora is voiced."""
    voiced = [p for p in log_f0 if p > MIN_VOICED_LOG_F0]
    if not voiced:
        return None
    hz = [math.exp(p) for p in voiced]
    mean_log = sum(voiced) / len(voiced)
    mean_hz = math.exp(mean_log)
    spread = [semitones(mean_hz, h) for h in hz]
    sd = math.sqrt(sum(s * s for s in spread) / len(spread))
    return PitchStats(round(mean_hz, 1), round(sd, 2), round(semitones(min(hz), max(hz)), 2))


def morae_per_second(mora_count: int, seconds: float) -> float:
    if mora_count <= 0 or seconds <= 0:
        raise ValueError("needs at least one mora and a positive length")
    return round(mora_count / seconds, 2)


def escape(value: object) -> str:
    """Text for an HTML cell (None is empty)."""
    return html.escape("" if value is None else str(value))


def html_table(header: Sequence[str], rows: Iterable[Sequence[str]], classes: Iterable[str] = ()) -> str:
    """A scrollable table. Header text is escaped; row cells are HTML already."""
    head = "".join(f"<th>{escape(h)}</th>" for h in header)
    marks = list(classes)
    body = "".join(
        (f'<tr class="{escape(marks[n])}">' if n < len(marks) and marks[n] else "<tr>")
        + "".join(f"<td>{cell}</td>" for cell in row) + "</tr>"
        for n, row in enumerate(rows))
    return f'<div class="wrap"><table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></div>'


def audio_tag(path: PurePosixPath) -> str:
    return f'<audio controls preload="none" src="{html.escape(str(path), quote=True)}"></audio>'
