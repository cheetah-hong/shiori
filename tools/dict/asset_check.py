#!/usr/bin/env python3
"""Check the app's dictionary assets against their edition files, before an app build.

  python3 tools/dict/asset_check.py [--dir app/assets/dict] [--max-age-days N]

For each asset (JMdict full-lean and the Korean glossary): the edition file has every
field the app reads, the gzip has the size the edition gives, it unpacks completely,
the SQLite file inside has the size and sha256 the edition gives, and the database's
own meta agrees with the edition. Prints one line per problem and exits 1, or one
`ok` line per asset and exits 0. --max-age-days N also fails an asset built more than
N days ago (off by default). Only the Python 3 standard library is used.
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
DEFAULT_DIR = HERE.parent.parent / "app" / "assets" / "dict"

# Asset name -> (gzip file, edition file).
ASSETS = {
    "jmdict-full-lean": ("jmdict-full-lean.sqlite.gz", "jmdict-full-lean.edition.json"),
    "ko-glossary": ("ko-glossary.sqlite.gz", "ko-glossary.edition.json"),
}


# Fields the app or this check reads from each edition file.
COMMON_FIELDS = ("variant", "built_on", "gzip_bytes", "sqlite_bytes", "sqlite_sha256")
EDITION_FIELDS = {
    "jmdict-full-lean": COMMON_FIELDS + ("source_sha256", "jmdict_created", "license"),
    "ko-glossary": COMMON_FIELDS + ("sources", "attribution"),
}
SOURCE_FIELDS = ("source", "name", "publisher", "edition", "license", "license_url", "source_sha256")
SIZE_FIELDS = ("gzip_bytes", "sqlite_bytes")
SHA256 = re.compile(r"[0-9a-f]{64}")
DAY = re.compile(r"\d{4}-\d{2}-\d{2}")
MAX_SQLITE_BYTES = 512 * 1024 * 1024  # far above either asset; refuse to unpack more


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
        pairs = [("sources[0].edition", first.get("edition"), meta.get("krdict.edition")),
                 ("variant", edition.get("variant"), meta.get("variant"))]
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
        gz_name, edition_name = ASSETS[name]
        problems += check_asset(name, directory / gz_name, directory / edition_name,
                                max_age_days=max_age_days, today=today)
    return problems


def report(directory: Path, *, max_age_days: int | None = None, names: tuple[str, ...] = tuple(ASSETS)) -> int:
    """Print the check of [names] in [directory]; 0 when all are good, else 1."""
    problems = check_dir(directory, max_age_days=max_age_days, names=names)
    for p in problems:
        print(p)
    for name in names:
        if not any(p.startswith(f"{name}:") for p in problems):
            print(f"{name}: ok")
    return 1 if problems else 0


def add_arguments(ap: argparse.ArgumentParser) -> None:
    ap.add_argument("--max-age-days", type=int,
                    help="also fail an asset built more than this many days ago (off by default)")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", type=Path, default=DEFAULT_DIR, help="default: app/assets/dict")
    add_arguments(ap)
    a = ap.parse_args(argv)
    return report(a.dir, max_age_days=a.max_age_days)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
