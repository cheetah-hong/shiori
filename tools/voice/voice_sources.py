"""Pinned source files for the voice tools: fetch once into a cache, check size and sha256.

Shared by build_voice_asset.py and build_accent_asset.py. A source file is looked up,
in order, in the cache (used when its size and sha256 match the pin), in each
--source-dir under its official file name (copied into the cache when it matches,
refused when it does not), and finally downloaded from its pinned URL (not with
--offline). Nothing that fails the pin is ever used or kept. Only the Python 3
standard library is used.
"""
from __future__ import annotations

import gzip
import hashlib
import os
import shutil
import tempfile
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

CHUNK = 1024 * 1024
DOWNLOAD_TIMEOUT_SECONDS = 120
FILE_MODE = 0o644  # temporary files start as 0600; what is kept is an ordinary file


class SourceError(Exception):
    """A source file is missing, differs from its pin, or holds something unexpected."""


@dataclass(frozen=True)
class Source:
    name: str  # official file name: the name in the cache and in a --source-dir
    url: str
    bytes: int
    sha256: str
    title: str  # what the edition file calls it
    license: str


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(CHUNK), b""):
            digest.update(block)
    return digest.hexdigest()


def mismatch(source: Source, path: Path) -> str | None:
    """Why [path] is not [source] (None: it is)."""
    size = path.stat().st_size
    if size != source.bytes:
        return f"{path} is {size:,} bytes, the pinned {source.name} is {source.bytes:,}"
    digest = sha256_file(path)
    if digest != source.sha256:
        return f"{path} has sha256 {digest}, the pinned {source.name} has {source.sha256}"
    return None


def _copy_in(source: Source, from_path: Path, cache: Path) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / source.name
    fd, part = tempfile.mkstemp(dir=cache, prefix=f".{source.name}.", suffix=".part")
    os.close(fd)
    try:
        shutil.copyfile(from_path, part)
        os.chmod(part, FILE_MODE)
        os.replace(part, target)
    finally:
        Path(part).unlink(missing_ok=True)
    return target


def _download(source: Source, cache: Path) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    fd, part_name = tempfile.mkstemp(dir=cache, prefix=f".{source.name}.", suffix=".part")
    part = Path(part_name)
    try:
        with os.fdopen(fd, "wb") as out:
            try:
                with urllib.request.urlopen(source.url, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response:
                    shutil.copyfileobj(response, out, CHUNK)
            except OSError as e:  # URLError and HTTPError are OSErrors
                raise SourceError(f"could not download {source.url} ({e})") from e
        problem = mismatch(source, part)
        if problem:
            raise SourceError(f"the download from {source.url} is not the pinned file: {problem}")
        target = cache / source.name
        os.chmod(part, FILE_MODE)
        os.replace(part, target)
        return target
    finally:
        part.unlink(missing_ok=True)


def obtain(source: Source, *, cache: Path, source_dirs: Iterable[Path] = (), offline: bool = False) -> Path:
    """The cached copy of [source], checked against its pin. Raises SourceError."""
    cached = cache / source.name
    if cached.is_file() and mismatch(source, cached) is None:
        return cached
    for directory in source_dirs:
        candidate = Path(directory) / source.name
        if not candidate.is_file():
            continue
        problem = mismatch(source, candidate)
        if problem:
            raise SourceError(f"refusing {candidate}: {problem}")
        return _copy_in(source, candidate, cache)
    if offline:
        state = "differs from its pin" if cached.is_file() else "is not there"
        raise SourceError(f"{source.name} {state} in {cache} and --offline forbids downloading it "
                          f"({source.url})")
    return _download(source, cache)


def gzip_to(data: bytes, path: Path) -> int:
    """Write [data] gzipped to [path] with mtime 0 and no file name (same data, same bytes)."""
    with path.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", compresslevel=9,
                                               fileobj=raw, mtime=0) as f:
        f.write(data)
    return path.stat().st_size
