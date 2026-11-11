"""The speech assets' part of asset_check.py: the voice asset and the accent table.

  voice  (app/assets/voice/):  voice.edition.json and one gzip per file it lists, built by
                               tools/voice/build_voice_asset.py
  accent (app/assets/accent/): kanjium-accents.tsv.gz and kanjium-accents.edition.json,
                               built by tools/voice/build_accent_asset.py

For the voice asset: the edition has every field the app reads, every file entry has a
safe relative path (no absolute path, no `..`; the app refuses them too) and a plain
gzip file name, every dictionary file and the model are listed, and each gzip has the
size the edition gives and unpacks completely to the size and sha256 it gives. For the
accent table: the same for its one gzip, plus the number of lines (entries). Both are
pinned editions, so no age limit applies. One problem per line, each starting with the
asset name. Only the Python 3 standard library is used.
"""
from __future__ import annotations

import gzip
import hashlib
import json
import re
import zlib
from pathlib import Path

VOICE_EDITION = "voice.edition.json"
VOICE_DICTIONARY_FILES = ("char.bin", "COPYING", "left-id.def", "matrix.bin", "pos-id.def",
                          "rewrite.def", "right-id.def", "sys.dic", "unk.dic")
VOICE_FIELDS = ("variant", "built_on", "core_version", "model_file", "dictionary_dir", "style_id",
                "credit", "files", "sources")
VOICE_FILE_FIELDS = ("path", "gzip", "gzip_bytes", "bytes", "sha256")
# The voice this app ships: VOICEVOX Nemo 女声4 ノーマル of the 0.17.1 voice models.
# build_voice_asset.py builds this edition; an asset of any other voice fails the check.
VOICE_VARIANT = "voicevox-0.17.1-n0vvm-style10003"
VOICE_MODEL_FILE = "n0.vvm"
VOICE_STYLE_ID = 10003
VOICE_CREDIT = "VOICEVOX Nemo"  # also on the 정보 screen and the licences page (about_screen.dart)
SHIPPED_VOICE = {"variant": VOICE_VARIANT, "model_file": VOICE_MODEL_FILE, "style_id": VOICE_STYLE_ID,
                 "credit": VOICE_CREDIT}
VOICE_SOURCE_FIELDS = ("name", "url", "sha256", "license")
ACCENT_FILES = ("kanjium-accents.tsv.gz", "kanjium-accents.edition.json")
ACCENT_FIELDS = ("variant", "built_on", "gzip_bytes", "tsv_bytes", "tsv_sha256", "entries",
                 "source_url", "source_sha256", "license", "attribution")
ACCENT_COUNTS = ("gzip_bytes", "tsv_bytes", "entries")
REBUILD_COMMANDS = {
    "voice": "python3 tools/voice/build_voice_asset.py",
    "accent": "python3 tools/voice/build_accent_asset.py",
}

SHA256 = re.compile(r"[0-9a-f]{64}")
DRIVE = re.compile(r"[A-Za-z]:")
MAX_UNPACKED_BYTES = 512 * 1024 * 1024  # far above any file here; refuse to unpack more
CHUNK = 1024 * 1024


def _absent(value) -> bool:
    return value is None or value == "" or value == []


def _is_count(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def unsafe_path(value) -> bool:
    """True unless [value] is a relative path that stays inside its folder."""
    if not isinstance(value, str) or not value or "\\" in value or "\0" in value:
        return True
    if value.startswith("/") or DRIVE.match(value):
        return True
    return any(part in ("", ".", "..") for part in value.split("/"))


_GZIP_NAME = re.compile(r"[A-Za-z0-9._-]+\.gz")


def unsafe_file_name(value) -> bool:
    """True unless [value] is a plain gzip file name the app accepts: letters, digits,
    `.`, `_` or `-`, ending in `.gz`, not starting with `.` (app/lib/adapters/voice_assets.dart)."""
    return (unsafe_path(value) or "/" in value or not _GZIP_NAME.fullmatch(value)
            or value.startswith("."))


# The engine files a release build links (tools/voice/build_voice_asset.py --native), by
# platform: path from the repository root, and whether it is a folder.
ENGINE_FILES = {
    "android": [
        ("app/android/app/src/main/jniLibs/arm64-v8a/libvoicevox_core.so", False),
        ("app/android/app/src/main/jniLibs/arm64-v8a/libvoicevox_onnxruntime.so", False),
        ("app/android/app/src/main/jniLibs/arm64-v8a/libc++_shared.so", False),
    ],
    "ios": [
        ("app/ios/voicevox/voicevox_core.xcframework/Info.plist", False),
        ("app/ios/voicevox/voicevox_onnxruntime.xcframework/Info.plist", False),
    ],
}
ENGINE_COMMAND = "python3 tools/voice/build_voice_asset.py --native"


def check_engine(platform: str, root: Path) -> list[str]:
    """Problems with the speech engine files of [platform] under the repository [root]:
    each must be there and not empty (the assets alone make no sound)."""
    problems = []
    for rel, _ in ENGINE_FILES[platform]:
        path = root / rel
        if not path.is_file() or path.stat().st_size == 0:
            problems.append(f"engine ({platform}): {rel} is missing")
    return problems


def _load_edition(name: str, path: Path) -> tuple[dict | None, list[str]]:
    if not path.is_file():
        return None, [f"{name}: {path.name} is missing"]
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        return None, [f"{name}: {path.name} is not JSON ({e})"]
    if not isinstance(data, dict):
        return None, [f"{name}: {path.name} is not a JSON object"]
    return data, []


def _unpacked(gz: Path) -> tuple[int, str]:
    """(size, sha256) of the whole gzip stream; raises on a stream cut short or a bad CRC."""
    digest = hashlib.sha256()
    size = 0
    with gzip.open(gz, "rb") as f:
        for block in iter(lambda: f.read(CHUNK), b""):
            size += len(block)
            if size > MAX_UNPACKED_BYTES:
                raise ValueError(f"unpacks to more than {MAX_UNPACKED_BYTES} bytes")
            digest.update(block)
    return size, digest.hexdigest()


def _gzip_problems(name: str, gz: Path, entry: dict, size_field: str, sha_field: str) -> list[str]:
    """[gz] against the sizes and sha256 [entry] gives for it."""
    if not gz.is_file():
        return [f"{name}: {gz.name} is missing"]
    problems = []
    gzip_bytes = gz.stat().st_size
    if _is_count(entry.get("gzip_bytes")) and gzip_bytes != entry["gzip_bytes"]:
        problems.append(f"{name}: {gz.name} gzip_bytes differs (edition {entry['gzip_bytes']}, "
                        f"file {gzip_bytes})")
    try:
        size, digest = _unpacked(gz)
    except (OSError, EOFError, ValueError, zlib.error) as e:
        return problems + [f"{name}: {gz.name} does not unpack ({e})"]
    if _is_count(entry.get(size_field)) and size != entry[size_field]:
        problems.append(f"{name}: {gz.name} {size_field} differs (edition {entry[size_field]}, file {size})")
    want = entry.get(sha_field)
    if isinstance(want, str) and SHA256.fullmatch(want) and digest != want:
        problems.append(f"{name}: {gz.name} {sha_field} differs (edition {want[:16]}…, file {digest[:16]}…)")
    return problems


def _voice_field_problems(edition: dict) -> list[str]:
    problems = [f"voice: edition has no {field}" for field in VOICE_FIELDS if _absent(edition.get(field))]
    for field in ("variant", "built_on", "core_version", "model_file", "dictionary_dir", "credit"):
        value = edition.get(field)
        if not _absent(value) and not isinstance(value, str):
            problems.append(f"voice: edition {field} is not a string ({value!r})")
    style = edition.get("style_id")
    if style is not None and not _is_count(style):
        problems.append(f"voice: edition style_id is not a number ({style!r})")
    for field in ("model_file", "dictionary_dir"):
        value = edition.get(field)
        if not _absent(value) and unsafe_path(value):
            problems.append(f"voice: edition {field} {value!r} is not a safe relative path")
    for field in ("files", "sources"):
        if not _absent(edition.get(field)) and not isinstance(edition[field], list):
            problems.append(f"voice: edition {field} is not a list")
    sources = edition.get("sources")
    for i, source in enumerate(sources if isinstance(sources, list) else []):
        if not isinstance(source, dict):
            problems.append(f"voice: edition sources[{i}] is not an object")
            continue
        problems += [f"voice: edition sources[{i}] has no {field}"
                     for field in VOICE_SOURCE_FIELDS if _absent(source.get(field))]
    return problems


def _shipped_voice_problems(edition: dict) -> list[str]:
    """The edition is of another voice than the one this app ships."""
    return [f"voice: edition {field} is {edition[field]!r}, this app ships {want!r}"
            for field, want in SHIPPED_VOICE.items()
            if edition.get(field) is not None and edition[field] != want]


def _unlisted_gzip_problems(directory: Path, files: list) -> list[str]:
    """Gzip files the edition does not list: the app bundles the whole folder, so they would ship."""
    listed = {entry.get("gzip") for entry in files if isinstance(entry, dict)}
    return [f"voice: {gz.name} is not in the edition (it would ship in the app)"
            for gz in sorted(directory.glob("*.gz")) if gz.name not in listed]


def _voice_entry_problems(i: int, entry) -> list[str]:
    """Problems of files[i] on its own; any of them means its file is not opened."""
    if not isinstance(entry, dict):
        return [f"voice: edition files[{i}] is not an object"]
    problems = [f"voice: edition files[{i}] has no {field}"
                for field in VOICE_FILE_FIELDS if _absent(entry.get(field))]
    path, gz = entry.get("path"), entry.get("gzip")
    if not _absent(path) and unsafe_path(path):
        problems.append(f"voice: edition files[{i}] path {path!r} is not a safe relative path")
    if not _absent(gz) and unsafe_file_name(gz):
        problems.append(f"voice: edition files[{i}] gzip {gz!r} is not a plain file name")
    for field in ("gzip_bytes", "bytes"):
        if entry.get(field) is not None and not _is_count(entry[field]):
            problems.append(f"voice: edition files[{i}] {field} is not a size ({entry[field]!r})")
    sha = entry.get("sha256")
    if not _absent(sha) and not (isinstance(sha, str) and SHA256.fullmatch(sha)):
        problems.append(f"voice: edition files[{i}] sha256 is not a lowercase sha256 ({sha!r})")
    return problems


def check_voice(directory: Path) -> list[str]:
    """Problems of the voice asset in [directory], one line each (empty: it is good)."""
    edition, problems = _load_edition("voice", directory / VOICE_EDITION)
    if edition is None:
        return problems
    problems = _voice_field_problems(edition) + _shipped_voice_problems(edition)
    files = edition.get("files") if isinstance(edition.get("files"), list) else []
    paths: list[str] = []
    gzips: list[str] = []
    for i, entry in enumerate(files):
        found = _voice_entry_problems(i, entry)
        if found:
            problems += found
            continue
        if entry["path"] in paths or entry["gzip"] in gzips:
            problems.append(f"voice: edition files[{i}] repeats {entry['path']!r} or {entry['gzip']!r}")
            continue
        paths.append(entry["path"])
        gzips.append(entry["gzip"])
        problems += _gzip_problems("voice", directory / entry["gzip"], entry, "bytes", "sha256")
    model, dictionary = edition.get("model_file"), edition.get("dictionary_dir")
    wanted = [model] if isinstance(model, str) and model else []
    if isinstance(dictionary, str) and dictionary:
        wanted += [f"{dictionary}/{name}" for name in VOICE_DICTIONARY_FILES]
    problems += [f"voice: edition files has no {path}" for path in wanted if path not in paths]
    return problems + _unlisted_gzip_problems(directory, files)


def check_accent(directory: Path) -> list[str]:
    """Problems of the accent table in [directory], one line each (empty: it is good)."""
    gz_name, edition_name = ACCENT_FILES
    edition, problems = _load_edition("accent", directory / edition_name)
    if edition is None:
        return problems
    problems = [f"accent: edition has no {field}" for field in ACCENT_FIELDS if _absent(edition.get(field))]
    for field in ACCENT_COUNTS:
        if edition.get(field) is not None and not _is_count(edition[field]):
            problems.append(f"accent: edition {field} is not a count ({edition[field]!r})")
    for field in ("tsv_sha256", "source_sha256"):
        sha = edition.get(field)
        if not _absent(sha) and not (isinstance(sha, str) and SHA256.fullmatch(sha)):
            problems.append(f"accent: edition {field} is not a lowercase sha256 ({sha!r})")
    gz = directory / gz_name
    found = _gzip_problems("accent", gz, edition, "tsv_bytes", "tsv_sha256")
    problems += found
    if found or not _is_count(edition.get("entries")):
        return problems
    with gzip.open(gz, "rb") as f:
        lines = sum(block.count(b"\n") for block in iter(lambda: f.read(CHUNK), b""))
    if lines != edition["entries"]:
        problems.append(f"accent: entries differs (edition {edition['entries']}, file {lines} lines)")
    return problems


CHECKS = {"voice": check_voice, "accent": check_accent}


def check_speech(dirs: dict[str, Path | None]) -> tuple[list[str], list[str]]:
    """(problems, failed asset names) of the speech assets whose folder is given."""
    problems: list[str] = []
    failed: list[str] = []
    for name, directory in dirs.items():
        if directory is None:
            continue
        found = CHECKS[name](directory)
        problems += found
        if found:
            failed.append(name)
    return problems, failed
