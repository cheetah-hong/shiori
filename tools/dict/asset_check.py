#!/usr/bin/env python3
"""Check the app's dictionary and speech assets against their edition files, before an app build.

  python3 tools/dict/asset_check.py [--dir app/assets/dict] [--voice-dir app/assets/voice]
                                    [--accent-dir app/assets/accent] [--max-age-days N | --release]

For each asset (JMdict full-lean, the Korean glossary and its Wiktionary fallback): the
edition file has every
field the app reads, the gzip has the size the edition gives, it unpacks completely,
the SQLite file inside has the size and sha256 the edition gives, and the database's
own meta agrees with the edition. Prints one line per problem and exits 1, or one
`ok` line per asset and exits 0. --max-age-days N also fails an asset built more than
N days ago (off by default). --release is the check a release build runs (Xcode and
Gradle): every asset must match its edition (the Wiktionary fallback too, cut against the
Korean glossary next to it; a plain run checks it only when it is built), and JMdict must be at most
RELEASE_MAX_AGE_DAYS old; on failure it also prints the command that fixes it. Only
the Python 3 standard library is used.

The speech assets (the voice asset and the accent table, speech_check.py) are checked
too, in their own folders, both in a plain run and with --release; a failing one
prints the command that rebuilds it. They are pinned editions, so --max-age-days and
the release age limit do not apply to them.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import gzip
import hashlib
import json
import re
import sqlite3
import sys
import tempfile
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import speech_check  # noqa: E402
from speech_check import (  # noqa: E402,F401  (the speech checks, under this module's name too)
    ACCENT_FILES,
    VOICE_DICTIONARY_FILES,
    VOICE_EDITION,
    check_accent,
    check_voice,
)

DEFAULT_DIR = HERE.parent.parent / "app" / "assets" / "dict"
REPO_VOICE_DIR = HERE.parent.parent / "app" / "assets" / "voice"
REPO_ACCENT_DIR = HERE.parent.parent / "app" / "assets" / "accent"
# What main() checks when --voice-dir / --accent-dir are not given (read when main runs).
DEFAULT_VOICE_DIR = REPO_VOICE_DIR
DEFAULT_ACCENT_DIR = REPO_ACCENT_DIR

# Asset name -> (gzip file, edition file).
ASSETS = {
    "jmdict-full-lean": ("jmdict-full-lean.sqlite.gz", "jmdict-full-lean.edition.json"),
    "ko-glossary": ("ko-glossary.sqlite.gz", "ko-glossary.edition.json"),
}

# The Wiktionary fallback glossary (build_wikt_glossary.py): a release needs it, a plain
# check reports it when it is there (debug builds run without it). It is cut against the
# Basic Korean Dictionary asset next to it (its edition names that asset's sqlite_sha256).
FALLBACK_ASSETS = {
    "wikt-glossary": ("wikt-glossary.sqlite.gz", "wikt-glossary.edition.json"),
}
ALL_ASSETS = {**ASSETS, **FALLBACK_ASSETS}


# Fields the app or this check reads from each edition file.
COMMON_FIELDS = ("variant", "built_on", "gzip_bytes", "sqlite_bytes", "sqlite_sha256")
EDITION_FIELDS = {
    "jmdict-full-lean": COMMON_FIELDS + ("source_sha256", "jmdict_created", "license"),
    "ko-glossary": COMMON_FIELDS + ("sources", "attribution"),
    "wikt-glossary": COMMON_FIELDS + ("sources", "attribution", "krdict_sqlite_sha256"),
}
SOURCE_FIELDS = ("source", "name", "publisher", "edition", "license", "license_url", "source_sha256")
SIZE_FIELDS = ("gzip_bytes", "sqlite_bytes")
SHA256 = re.compile(r"[0-9a-f]{64}")
DAY = re.compile(r"\d{4}-\d{2}-\d{2}")
MAX_SQLITE_BYTES = 512 * 1024 * 1024  # far above either asset; refuse to unpack more

# A release refuses a JMdict built longer ago than this: its licence asks for regular
# updates, and the update is run monthly (docs/dictionary.md, 12.4). The Korean glossary
# changes edition rarely, so a release only checks that it matches its edition.
RELEASE_MAX_AGE_DAYS = 35
RELEASE_AGE_LIMITED = ("jmdict-full-lean",)
REFRESH_COMMAND = "python3 tools/dict/refresh.py"
REBUILD_COMMANDS = {
    "jmdict-full-lean": "python3 tools/dict/build_app_asset.py",
    "ko-glossary": "python3 tools/dict/build_ko_glossary.py --source <krdict JSON zip>",
    "wikt-glossary": "python3 tools/dict/build_wikt_glossary.py --kowikt <kowiktionary gzip> "
                     "--kowikt-dump <day> --en-rows <rows>",
}


def _missing_fields(name: str, edition: dict) -> list[str]:
    problems = []
    for field in EDITION_FIELDS[name]:
        value = edition.get(field)
        if value is None or value == "" or value == []:
            problems.append(f"{name}: edition has no {field}")
    for field in SIZE_FIELDS:
        value = edition.get(field)
        if value is not None and (not isinstance(value, int) or isinstance(value, bool) or value < 0):
            problems.append(f"{name}: edition {field} is not a size ({value!r})")
    sha = edition.get("sqlite_sha256")
    if isinstance(sha, str) and sha and not SHA256.fullmatch(sha):
        problems.append(f"{name}: edition sqlite_sha256 is not a lowercase sha256 ({sha!r})")
    for i, source in enumerate(edition.get("sources") or []):
        if not isinstance(source, dict):
            problems.append(f"{name}: edition sources[{i}] is not an object")
            continue
        for field in SOURCE_FIELDS:
            if not source.get(field):
                problems.append(f"{name}: edition sources[{i}] has no {field}")
    return problems


def _unpack(gz: Path) -> bytes:
    """The whole gzip stream; raises on a stream cut short or a bad CRC."""
    with gzip.open(gz, "rb") as f:
        data = f.read(MAX_SQLITE_BYTES + 1)
    if len(data) > MAX_SQLITE_BYTES:
        raise ValueError(f"unpacks to more than {MAX_SQLITE_BYTES} bytes")
    return data


def _meta(raw: bytes) -> dict[str, str]:
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "check.sqlite"
        path.write_bytes(raw)
        with contextlib.closing(sqlite3.connect(f"file:{path}?mode=ro", uri=True)) as db:
            return dict(db.execute("SELECT key, value FROM meta"))


def _meta_problems(name: str, edition: dict, meta: dict[str, str]) -> list[str]:
    """The database must say it is the data the edition names."""
    if name == "jmdict-full-lean":
        pairs = [("source_sha256", edition.get("source_sha256"), meta.get("source_sha256")),
                 ("jmdict_created", edition.get("jmdict_created"), meta.get("jmdict_created"))]
    else:
        sources = edition.get("sources") or [{}]
        first = sources[0] if isinstance(sources[0], dict) else {}
        prefix = "wiktionary" if name == "wikt-glossary" else "krdict"
        pairs = [("sources[0].edition", first.get("edition"), meta.get(f"{prefix}.edition")),
                 ("variant", edition.get("variant"), meta.get("variant"))]
        if name == "wikt-glossary":
            pairs.append(("krdict_sqlite_sha256", edition.get("krdict_sqlite_sha256"),
                          meta.get("krdict_sqlite_sha256")))
    return [f"{name}: edition {field} is {want!r}, the database inside says {got!r}"
            for field, want, got in pairs if want is not None and want != got]


def _age_problem(name: str, edition: dict, max_age_days: int, today: dt.date) -> list[str]:
    built_on = edition.get("built_on")
    if not isinstance(built_on, str) or not DAY.fullmatch(built_on):
        return [f"{name}: edition built_on is not a day ({built_on!r})"]
    try:
        age = (today - dt.date.fromisoformat(built_on)).days
    except ValueError:
        return [f"{name}: edition built_on is not a day ({built_on!r})"]
    if age > max_age_days:
        return [f"{name}: built_on {built_on} is {age} days old (limit {max_age_days})"]
    return []


def check_asset(name: str, gz: Path, edition: Path, *, max_age_days: int | None = None,
                today: dt.date | None = None) -> list[str]:
    """Problems of one asset, one line each (empty: the asset is good)."""
    if name not in EDITION_FIELDS:
        return [f"{name}: not a known asset ({', '.join(EDITION_FIELDS)})"]
    for path in (gz, edition):
        if not path.is_file():
            return [f"{name}: {path.name} is missing"]
    try:
        data = json.loads(edition.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        return [f"{name}: {edition.name} is not JSON ({e})"]
    if not isinstance(data, dict):
        return [f"{name}: {edition.name} is not a JSON object"]
    problems = _missing_fields(name, data)
    if max_age_days is not None:
        problems += _age_problem(name, data, max_age_days, today or dt.date.today())

    gzip_bytes = gz.stat().st_size
    if isinstance(data.get("gzip_bytes"), int) and gzip_bytes != data["gzip_bytes"]:
        problems.append(f"{name}: gzip_bytes differs (edition {data['gzip_bytes']}, file {gzip_bytes})")
    try:
        raw = _unpack(gz)
    except (OSError, EOFError, ValueError, zlib.error) as e:
        return problems + [f"{name}: {gz.name} does not unpack ({e})"]
    if isinstance(data.get("sqlite_bytes"), int) and len(raw) != data["sqlite_bytes"]:
        problems.append(f"{name}: sqlite_bytes differs (edition {data['sqlite_bytes']}, file {len(raw)})")
    digest = hashlib.sha256(raw).hexdigest()
    if isinstance(data.get("sqlite_sha256"), str) and digest != data["sqlite_sha256"]:
        problems.append(f"{name}: sqlite_sha256 differs (edition {data['sqlite_sha256'][:16]}…, "
                        f"file {digest[:16]}…)")
    try:
        meta = _meta(raw)
    except sqlite3.Error as e:
        return problems + [f"{name}: the unpacked file is not a dictionary database ({e})"]
    return problems + _meta_problems(name, data, meta)


def check_dir(directory: Path, *, max_age_days: int | None = None, today: dt.date | None = None,
              names: tuple[str, ...] = tuple(ASSETS)) -> list[str]:
    """Problems of the assets [names] in [directory], one line each."""
    problems = []
    for name in names:
        gz_name, edition_name = ALL_ASSETS[name]
        problems += check_asset(name, directory / gz_name, directory / edition_name,
                                max_age_days=max_age_days, today=today)
    return problems


def _is_built(directory: Path, name: str) -> bool:
    """Either file of asset [name] is in [directory]."""
    return any((directory / f).exists() for f in ALL_ASSETS[name])


def fallback_cut_problems(directory: Path) -> list[str]:
    """The fallback glossary must be cut against the Basic Korean Dictionary asset next to it
    (checked only when both match their editions)."""
    gz, edition = (directory / f for f in ALL_ASSETS["wikt-glossary"])
    ko_gz, ko_edition = (directory / f for f in ASSETS["ko-glossary"])
    if check_asset("wikt-glossary", gz, edition) or check_asset("ko-glossary", ko_gz, ko_edition):
        return []
    want = json.loads(ko_edition.read_text(encoding="utf-8")).get("sqlite_sha256")
    got = json.loads(edition.read_text(encoding="utf-8")).get("krdict_sqlite_sha256")
    if want == got:
        return []
    return [f"wikt-glossary: edition krdict_sqlite_sha256 is {str(got)[:16]}…, the ko-glossary asset "
            f"next to it is {str(want)[:16]}… (rebuild the fallback after the glossary)"]


def _speech_dirs(voice_dir: Path | None, accent_dir: Path | None) -> dict[str, Path | None]:
    return {"voice": voice_dir, "accent": accent_dir}


def report(directory: Path, *, max_age_days: int | None = None, names: tuple[str, ...] = tuple(ASSETS),
           voice_dir: Path | None = None, accent_dir: Path | None = None) -> int:
    """Print the check of [names] in [directory] and of the speech assets whose folder is
    given; 0 when all are good, else 1."""
    problems = check_dir(directory, max_age_days=max_age_days, names=names)
    # With every dictionary asked for, the fallback glossary too when it is built.
    fallback = names == tuple(ASSETS) and _is_built(directory, "wikt-glossary")
    if fallback:
        problems += check_dir(directory, max_age_days=max_age_days, names=("wikt-glossary",))
        problems += fallback_cut_problems(directory)
        names = names + ("wikt-glossary",)
    elif names == tuple(ASSETS):
        print("wikt-glossary: not built (a release needs it: "
              f"{REBUILD_COMMANDS['wikt-glossary']})")
    elif "wikt-glossary" in names:
        problems += fallback_cut_problems(directory)
    dirs = _speech_dirs(voice_dir, accent_dir)
    speech_problems, speech_failed = speech_check.check_speech(dirs)
    for p in problems + speech_problems:
        print(p)
    for name in names:
        if not any(p.startswith(f"{name}:") for p in problems):
            print(f"{name}: ok")
    for name, directory_given in dirs.items():
        if directory_given is not None and name not in speech_failed:
            print(f"{name}: ok")
    for name in speech_failed:
        print(f"  {name}: rebuild with: {speech_check.REBUILD_COMMANDS[name]}")
    return 1 if problems or speech_problems else 0


def _release_split(directory: Path, today: dt.date | None) -> tuple[list[str], list[str], list[str]]:
    """(problems, assets not matching their edition, assets too old) for a release."""
    problems: list[str] = []
    mismatched: list[str] = []
    too_old: list[str] = []
    for name, (gz_name, edition_name) in ALL_ASSETS.items():
        found = check_asset(name, directory / gz_name, directory / edition_name)
        if name in FALLBACK_ASSETS and not found:
            found = fallback_cut_problems(directory)
        if found:
            problems += found
            mismatched.append(name)
            continue
        if name in RELEASE_AGE_LIMITED:
            edition = json.loads((directory / edition_name).read_text(encoding="utf-8"))
            old = _age_problem(name, edition, RELEASE_MAX_AGE_DAYS, today or dt.date.today())
            if old:
                problems += old
                too_old.append(name)
    return problems, mismatched, too_old


def release_problems(directory: Path, *, today: dt.date | None = None) -> list[str]:
    """Why the assets in [directory] cannot ship in a release, one line each (empty: they can)."""
    return _release_split(directory, today)[0]


def release_report(directory: Path, *, voice_dir: Path | None = None, accent_dir: Path | None = None,
                   engine: str | None = None) -> int:
    """Print the release check of [directory] and of the speech assets whose folder is
    given (and, with [engine], of that platform's speech engine files), and how to fix it;
    0 when it passes, else 1."""
    problems, mismatched, too_old = _release_split(directory, None)
    dirs = _speech_dirs(voice_dir, accent_dir)
    speech_problems, speech_failed = speech_check.check_speech(dirs)
    engine_problems = speech_check.check_engine(engine, HERE.parent.parent) if engine else []
    if engine and not engine_problems:
        print(f"engine ({engine}): ok")
    for p in problems + speech_problems + engine_problems:
        print(p)
    for name in ALL_ASSETS:
        if name not in mismatched and name not in too_old:
            print(f"{name}: ok")
    for name, directory_given in dirs.items():
        if directory_given is not None and name not in speech_failed:
            print(f"{name}: ok")
    if problems:
        print("error: The dictionary assets cannot ship in a release "
              "(python3 tools/dict/asset_check.py --release).")
        if mismatched:
            rebuild = " / ".join(REBUILD_COMMANDS[name] for name in mismatched)
            print(f"  Not matching their edition: rebuild with: {rebuild}")
        if too_old:
            print(f"  Too old (JMdict, limit {RELEASE_MAX_AGE_DAYS} days): refresh with: {REFRESH_COMMAND}")
    if speech_failed:
        print("error: The speech assets cannot ship in a release "
              "(python3 tools/dict/asset_check.py --release).")
        rebuild = " / ".join(speech_check.REBUILD_COMMANDS[name] for name in speech_failed)
        print(f"  Not matching their edition: rebuild with: {rebuild}")
    if engine_problems:
        print(f"error: The speech engine is not in this build: {speech_check.ENGINE_COMMAND}")
    return 1 if problems or speech_problems or engine_problems else 0


def add_arguments(ap: argparse.ArgumentParser) -> None:
    ap.add_argument("--max-age-days", type=int,
                    help="also fail an asset built more than this many days ago (off by default)")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", type=Path, default=DEFAULT_DIR, help="default: app/assets/dict")
    ap.add_argument("--voice-dir", type=Path, help="default: app/assets/voice")
    ap.add_argument("--accent-dir", type=Path, help="default: app/assets/accent")
    add_arguments(ap)
    ap.add_argument("--release", action="store_true",
                    help=f"the release build check: every asset matches its edition and JMdict is at "
                         f"most {RELEASE_MAX_AGE_DAYS} days old")
    ap.add_argument("--engine", choices=sorted(speech_check.ENGINE_FILES),
                    help="with --release: also require that platform's speech engine files")
    a = ap.parse_args(argv)
    if a.engine and not a.release:
        ap.error("--engine goes with --release")
    if a.release and a.max_age_days is not None:
        ap.error("--release has its own age limit; do not give --max-age-days with it")
    voice_dir = a.voice_dir or DEFAULT_VOICE_DIR
    accent_dir = a.accent_dir or DEFAULT_ACCENT_DIR
    if a.release:
        return release_report(a.dir, voice_dir=voice_dir, accent_dir=accent_dir, engine=a.engine)
    return report(a.dir, max_age_days=a.max_age_days, voice_dir=voice_dir, accent_dir=accent_dir)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
