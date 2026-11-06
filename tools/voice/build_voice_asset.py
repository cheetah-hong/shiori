#!/usr/bin/env python3
"""Build the app's voice asset (and, with --native, put the speech engine in place).

  python3 tools/voice/build_voice_asset.py [--native] [--cache DIR] [--source-dir DIR ...]
                                           [--offline] [--out-dir app/assets/voice]

Writes into app/assets/voice/ (not committed):
  0.vvm.gz                           the VOICEVOX voice model 0.vvm (style 2 is used)
  open_jtalk_dic.<file>.gz           each of the 9 Open JTalk dictionary files
  voice.edition.json                 path, gzip name, sizes and sha256 of every file, sources
The gzip files have mtime 0, so the same sources and build day give the same bytes.

--native also installs the prebuilt engine (voice_native.py): the VOICEVOX core and
ONNX Runtime xcframeworks into app/ios/voicevox/, and the arm64 Android libraries, with
libc++_shared.so from the NDK the app builds with, into
app/android/app/src/main/jniLibs/arm64-v8a/.

Every official file is pinned by URL, size and sha256 (SOURCES). It is taken from the
cache (default research/tts/.cache/voice-src, not committed) when it matches, else from a
--source-dir holding it under its official name, else downloaded (not with --offline).
A file that does not match its pin is refused. --check builds nothing and checks the
asset in --out-dir (tools/dict/asset_check.py). Only the Python 3 standard library is used.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
import tarfile
import tempfile
from pathlib import Path
from typing import Iterable, Mapping

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO / "tools" / "dict"))

import asset_check  # noqa: E402
from voice_native import find_libcxx, install_native  # noqa: E402,F401
from voice_sources import Source, SourceError, gzip_to, obtain  # noqa: E402

CORE_VERSION = "0.17.1"
VARIANT = f"voicevox-{CORE_VERSION}-0vvm-style2"
MODEL_FILE = "0.vvm"
DICTIONARY_DIR = "open_jtalk_dic_utf_8-1.11"
STYLE_ID = 2
CREDIT = "VOICEVOX:四国めたん"
EDITION_NAME = asset_check.VOICE_EDITION
MODEL_GZIP = f"{MODEL_FILE}.gz"
DICTIONARY_GZIP = "open_jtalk_dic.{}.gz"
DAY = re.compile(r"\d{4}-\d{2}-\d{2}")

DEFAULT_OUT = REPO / "app" / "assets" / "voice"
DEFAULT_CACHE = REPO / "research" / "tts" / ".cache" / "voice-src"
DEFAULT_IOS_DIR = REPO / "app" / "ios" / "voicevox"
DEFAULT_ANDROID_DIR = REPO / "app" / "android"
DEFAULT_JNI_DIR = DEFAULT_ANDROID_DIR / "app" / "src" / "main" / "jniLibs"

_CORE = f"https://github.com/VOICEVOX/voicevox_core/releases/download/{CORE_VERSION}"
_ORT = "https://github.com/VOICEVOX/onnxruntime-builder/releases/download"
_VVM = f"https://github.com/VOICEVOX/voicevox_vvm/releases/download/{CORE_VERSION}"
_VVM_TERMS = "VOICEVOX 音声モデル 利用規約"
_ORT_TERMS = "VOICEVOX ONNX Runtime 利用規約"
SOURCES: dict[str, Source] = {
    "vvm": Source(
        "0.vvm", f"{_VVM}/0.vvm", 59_308_488,
        "ecd35374d4182cd883cba5040376f7f888cc6ba248b1c2f4cea07cdb34bb1318",
        "VOICEVOX voice model 0.vvm", _VVM_TERMS),
    "vvm_terms": Source(
        "TERMS.txt", f"{_VVM}/TERMS.txt", 15_990,
        "9c0caf98b31ef82e3686e8fca39d53c85965059d2206be3c83efc3751d32c83a",
        f"VOICEVOX voice model terms {CORE_VERSION}", _VVM_TERMS),
    "dictionary": Source(
        "open_jtalk_dic_utf_8-1.11.tar.gz",
        "https://github.com/r9y9/open_jtalk/releases/download/v1.11.1/open_jtalk_dic_utf_8-1.11.tar.gz",
        23_646_843, "fe6ba0e43542cef98339abdffd903e062008ea170b04e7e2a35da805902f382a",
        "Open JTalk dictionary 1.11", "Modified BSD"),
    "core_ios": Source(
        f"voicevox_core-xcframework-{CORE_VERSION}.zip",
        f"{_CORE}/voicevox_core-xcframework-{CORE_VERSION}.zip", 5_916_727,
        "d01e1d511895944a86857d736bc0e0a1a079a4ed68f985477f4f327bdb22ec61",
        f"VOICEVOX core {CORE_VERSION} (iOS xcframework)", "MIT"),
    "core_android_arm64": Source(
        f"voicevox_core-android-arm64-{CORE_VERSION}.zip",
        f"{_CORE}/voicevox_core-android-arm64-{CORE_VERSION}.zip", 1_306_346,
        "069f29018ea27d939e3198ef34592a489181ba3d0287819f80c518963c639d37",
        f"VOICEVOX core {CORE_VERSION} (Android arm64)", "MIT"),
    "ort_ios": Source(
        "voicevox_onnxruntime-ios-xcframework-1.17.3.zip",
        f"{_ORT}/voicevox_onnxruntime-1.17.3/voicevox_onnxruntime-ios-xcframework-1.17.3.zip",
        14_028_727, "5b0138f25e68c3fb99771d37978837d5038a67b0720f96d912c900887164494b",
        "VOICEVOX ONNX Runtime 1.17.3 (iOS xcframework)", _ORT_TERMS),
    "ort_android_arm64": Source(
        "voicevox_onnxruntime-android-arm64-1.23.2.tgz",
        f"{_ORT}/voicevox_onnxruntime-1.23.2/voicevox_onnxruntime-android-arm64-1.23.2.tgz",
        6_459_115, "43e6fc2a89ea6412d4cc20215042a3b34da22fdf05c1bb76256a686f82378d46",
        "VOICEVOX ONNX Runtime 1.23.2 (Android arm64)", _ORT_TERMS),
}
ASSET_SOURCES = ("vvm", "vvm_terms", "dictionary")
EDITION_SOURCES = ASSET_SOURCES
NATIVE_SOURCES = ("core_ios", "ort_ios", "core_android_arm64", "ort_android_arm64")


def obtain_sources(keys: Iterable[str], sources: Mapping[str, Source], *, cache: Path,
                   source_dirs: Iterable[Path] = (), offline: bool = False) -> dict[str, Path]:
    """The checked cache copy of each source in [keys]. Raises SourceError."""
    dirs = list(source_dirs)
    return {key: obtain(sources[key], cache=cache, source_dirs=dirs, offline=offline) for key in keys}


def _dictionary_members(tar: tarfile.TarFile) -> dict[str, tarfile.TarInfo]:
    """The 9 dictionary files of the archive by name; raises when one is missing."""
    by_name = {m.name: m for m in tar.getmembers() if m.isfile()}
    found = {}
    for name in asset_check.VOICE_DICTIONARY_FILES:
        member = by_name.get(f"{DICTIONARY_DIR}/{name}")
        if member is None:
            raise SourceError(f"the dictionary archive has no {DICTIONARY_DIR}/{name}")
        found[name] = member
    return found


def _pack(path: str, gzip_name: str, data: bytes, tmp: Path) -> dict:
    gzip_bytes = gzip_to(data, tmp / gzip_name)
    return {"path": path, "gzip": gzip_name, "gzip_bytes": gzip_bytes, "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}


def build_voice_asset(paths: Mapping[str, Path], out_dir: Path, *, built_on: str,
                      sources: Mapping[str, Source] | None = None) -> dict:
    """Write the gzip files and the edition into [out_dir]; returns the edition."""
    sources = SOURCES if sources is None else sources
    if not DAY.fullmatch(built_on):
        sys.exit(f"--built-on must be YYYY-MM-DD, got {built_on!r}")
    with tarfile.open(paths["dictionary"], "r:gz") as tar:
        members = _dictionary_members(tar)
        out_dir.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=out_dir, prefix=".build-") as tmp_name:
            tmp = Path(tmp_name)
            files = [_pack(MODEL_FILE, MODEL_GZIP, paths["vvm"].read_bytes(), tmp)]
            for name, member in members.items():
                data = tar.extractfile(member).read()
                files.append(_pack(f"{DICTIONARY_DIR}/{name}", DICTIONARY_GZIP.format(name), data, tmp))
            edition = {
                "variant": VARIANT,
                "built_on": built_on,
                "core_version": CORE_VERSION,
                "model_file": MODEL_FILE,
                "dictionary_dir": DICTIONARY_DIR,
                "style_id": STYLE_ID,
                "credit": CREDIT,
                "files": files,
                "sources": [{"name": sources[k].title, "url": sources[k].url, "sha256": sources[k].sha256,
                             "license": sources[k].license} for k in EDITION_SOURCES],
            }
            edition_part = tmp / EDITION_NAME
            edition_part.write_text(json.dumps(edition, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                                    encoding="utf-8")
            # The app unpacks again only when the edition file changes: the old edition
            # goes first and the new one last, so a build cut short leaves no edition
            # (no voice) rather than an old edition next to new files.
            (out_dir / EDITION_NAME).unlink(missing_ok=True)
            for entry in files:
                os.replace(tmp / entry["gzip"], out_dir / entry["gzip"])
            os.replace(edition_part, out_dir / EDITION_NAME)
    return edition


def _parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache", type=Path, default=DEFAULT_CACHE,
                    help="where the official files are kept (default: research/tts/.cache/voice-src)")
    ap.add_argument("--source-dir", type=Path, action="append", default=[],
                    help="a folder holding official files under their official names (repeatable)")
    ap.add_argument("--offline", action="store_true", help="never download; fail when a file is not at hand")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT, help="default: app/assets/voice")
    ap.add_argument("--built-on", default=dt.datetime.now(dt.timezone.utc).date().isoformat(),
                    help="build day written to the edition file (default: today, UTC)")
    ap.add_argument("--native", action="store_true",
                    help="also install the iOS frameworks and Android libraries of the engine")
    ap.add_argument("--ios-dir", type=Path, default=DEFAULT_IOS_DIR, help="default: app/ios/voicevox")
    ap.add_argument("--jni-dir", type=Path, default=DEFAULT_JNI_DIR,
                    help="default: app/android/app/src/main/jniLibs")
    ap.add_argument("--android-dir", type=Path, default=DEFAULT_ANDROID_DIR,
                    help="the Android project whose NDK version is used (default: app/android)")
    ap.add_argument("--ndk", type=Path, help="the NDK folder to take libc++_shared.so from")
    ap.add_argument("--check", action="store_true",
                    help="build nothing: check the asset in --out-dir against its edition (asset_check.py)")
    return ap


def main(argv: list[str]) -> int:
    a = _parser().parse_args(argv)
    if a.check:
        return asset_check.report(a.out_dir, names=(), voice_dir=a.out_dir)
    if not DAY.fullmatch(a.built_on):
        sys.exit(f"--built-on must be YYYY-MM-DD, got {a.built_on!r}")
    libcxx = find_libcxx(a.android_dir, ndk=a.ndk) if a.native else None
    keys = ASSET_SOURCES + (NATIVE_SOURCES if a.native else ())
    try:
        paths = obtain_sources(keys, SOURCES, cache=a.cache, source_dirs=a.source_dir, offline=a.offline)
        edition = build_voice_asset(paths, a.out_dir, built_on=a.built_on)
        installed = install_native(paths, ios_dir=a.ios_dir, jni_dir=a.jni_dir, libcxx=libcxx) if a.native else []
    except SourceError as e:
        sys.exit(f"error: {e}")
    total = sum(entry["gzip_bytes"] for entry in edition["files"])
    print(f"wrote {len(edition['files'])} gzip files ({total:,} bytes) and {EDITION_NAME} to {a.out_dir}",
          file=sys.stderr)
    for path in installed:
        print(f"installed {path}", file=sys.stderr)
    print(json.dumps(edition, ensure_ascii=False, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
