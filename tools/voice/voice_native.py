"""Put the prebuilt speech engine where the app build finds it (build_voice_asset.py --native).

  iOS:     app/ios/voicevox/voicevox_core.xcframework, voicevox_onnxruntime.xcframework
           (the ONNX Runtime bundle identifiers get `-` for `_`: Xcode refuses `_` in them)
  Android: app/android/app/src/main/jniLibs/arm64-v8a/libvoicevox_core.so,
           libvoicevox_onnxruntime.so, and libc++_shared.so from the NDK the app builds with

Archives are unpacked member by member: a member or link that would land outside its
folder is refused. Only the Python 3 standard library is used.
"""
from __future__ import annotations

import os
import plistlib
import re
import shutil
import stat
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path, PurePosixPath
from typing import Mapping

from voice_sources import FILE_MODE, SourceError

IOS_FRAMEWORKS = {"core_ios": "voicevox_core.xcframework", "ort_ios": "voicevox_onnxruntime.xcframework"}
BUNDLE_ID_FIXED = ("ort_ios",)
ANDROID_ABI = "arm64-v8a"
ANDROID_LIBRARIES = {"core_android_arm64": "libvoicevox_core.so",
                     "ort_android_arm64": "libvoicevox_onnxruntime.so"}
LIBCXX = "libc++_shared.so"
LIBCXX_GLOB = f"toolchains/llvm/prebuilt/*/sysroot/usr/lib/aarch64-linux-android/{LIBCXX}"
NDK_LITERAL = re.compile(r'^\s*ndkVersion\s*=\s*"([^"]+)"', re.M)
NDK_FROM_FLUTTER = re.compile(r"^\s*ndkVersion\s*=\s*flutter\.ndkVersion\b", re.M)
FLUTTER_NDK = re.compile(r'val\s+ndkVersion\s*:\s*String\s*=\s*"([^"]+)"')
FLUTTER_EXTENSION = "packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"


# ------------------------------------------------------------------ unpacking

def _inside(root: Path, path: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def _member_target(root: Path, top: str, name: str) -> Path | None:
    """Where member [name] goes under [root] (None: a folder entry); refuses escapes."""
    parts = PurePosixPath(name).parts
    if not parts or parts[0] != top or name.startswith("/") or any(p in ("..", "") for p in parts):
        raise SourceError(f"archive member {name!r} is not inside {top}/")
    target = root.joinpath(*parts)
    if not _inside(root.resolve(), target.parent.resolve()):
        raise SourceError(f"archive member {name!r} would land outside {top}/")
    return target


def _link_ok(root: Path, link: Path, target: str) -> bool:
    if target.startswith("/") or "\\" in target:
        return False
    resolved = Path(os.path.normpath(link.parent / target))
    return _inside(Path(os.path.normpath(root)), resolved)


def _unzip_folder(archive: Path, top: str, into: Path) -> Path:
    """Unpack the folder [top] of zip [archive] into [into]; returns into/top."""
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            if info.filename.rstrip("/") == top:
                continue
            target = _member_target(into, top, info.filename.rstrip("/"))
            mode = info.external_attr >> 16
            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.is_symlink() or target.exists():
                # A second member of the same name would write through a link made
                # before it (or replace a file): neither happens in the official archives.
                raise SourceError(f"archive member {info.filename!r} is there twice")
            if stat.S_ISLNK(mode):
                link = z.read(info).decode("utf-8")
                if not _link_ok(into / top, target, link):
                    raise SourceError(f"archive link {info.filename!r} -> {link!r} leaves {top}/")
                os.symlink(link, target)
                continue
            with z.open(info) as src, target.open("xb") as out:
                shutil.copyfileobj(src, out, 1024 * 1024)
            if mode & 0o777:
                target.chmod(mode & 0o777)
    if not (into / top).is_dir():
        raise SourceError(f"{archive.name} has no {top}/")
    # Links can chain (a link through another link): check where each one really goes
    # once all are made, not only its text.
    root = (into / top).resolve()
    for path in (into / top).rglob("*"):
        if path.is_symlink() and not _inside(root, Path(os.path.realpath(path))):
            raise SourceError(f"archive link {path.relative_to(into)} leaves {top}/")
    return into / top


def _fix_bundle_ids(framework: Path) -> int:
    """`_` -> `-` in every CFBundleIdentifier under [framework]; how many changed."""
    changed = 0
    for path in sorted(framework.rglob("Info.plist")):
        if path.is_symlink():
            continue
        data = path.read_bytes()
        fmt = plistlib.FMT_BINARY if data.startswith(b"bplist") else plistlib.FMT_XML
        plist = plistlib.loads(data)
        ident = plist.get("CFBundleIdentifier") if isinstance(plist, dict) else None
        if not isinstance(ident, str) or "_" not in ident:
            continue
        path.write_bytes(plistlib.dumps({**plist, "CFBundleIdentifier": ident.replace("_", "-")}, fmt=fmt))
        changed += 1
    return changed


def _replace_dir(new: Path, target: Path) -> None:
    """Move [new] to [target], removing an earlier [target] only once [new] is complete."""
    if target.is_symlink() or target.is_file():
        raise SourceError(f"{target} exists and is not a folder; move it away first")
    old = None
    if target.exists():
        old = target.with_name(f".{target.name}.old")
        if old.exists():
            shutil.rmtree(old)
        os.replace(target, old)
    os.replace(new, target)
    if old is not None:
        shutil.rmtree(old)


def install_ios(paths: Mapping[str, Path], ios_dir: Path) -> list[Path]:
    ios_dir.mkdir(parents=True, exist_ok=True)
    installed = []
    for key, top in IOS_FRAMEWORKS.items():
        with tempfile.TemporaryDirectory(dir=ios_dir, prefix=".unpack-") as tmp:
            framework = _unzip_folder(paths[key], top, Path(tmp))
            if key in BUNDLE_ID_FIXED:
                _fix_bundle_ids(framework)
            _replace_dir(framework, ios_dir / top)
        installed.append(ios_dir / top)
    return installed


# -------------------------------------------------------------------- Android

def _read_library(archive: Path, library: str) -> bytes:
    suffix = f"/lib/{library}"
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as z:
            names = [n for n in z.namelist() if n.endswith(suffix)]
            if len(names) == 1:
                return z.read(names[0])
    else:
        with tarfile.open(archive, "r:*") as tar:
            members = [m for m in tar.getmembers() if m.isfile() and m.name.endswith(suffix)]
            if len(members) == 1:
                return tar.extractfile(members[0]).read()
    raise SourceError(f"{archive.name} does not hold exactly one */lib/{library}")


def _write_file(data: bytes, target: Path) -> None:
    fd, part = tempfile.mkstemp(dir=target.parent, prefix=f".{target.name}.", suffix=".part")
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(data)
        os.chmod(part, FILE_MODE)
        os.replace(part, target)
    finally:
        Path(part).unlink(missing_ok=True)


def install_android(paths: Mapping[str, Path], jni_dir: Path, libcxx: Path) -> list[Path]:
    abi = jni_dir / ANDROID_ABI
    abi.mkdir(parents=True, exist_ok=True)
    libraries = {name: _read_library(paths[key], name) for key, name in ANDROID_LIBRARIES.items()}
    libraries[LIBCXX] = libcxx.read_bytes()
    for name, data in libraries.items():
        _write_file(data, abi / name)
    return [abi / name for name in libraries]


def install_native(paths: Mapping[str, Path], *, ios_dir: Path, jni_dir: Path, libcxx: Path) -> list[Path]:
    """Install the iOS frameworks and Android libraries; returns what was written."""
    return install_ios(paths, ios_dir) + install_android(paths, jni_dir, libcxx)


# ------------------------------------------------------------ NDK libc++

def _properties(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    pairs = (line.split("=", 1) for line in path.read_text(encoding="utf-8").splitlines()
             if "=" in line and not line.lstrip().startswith("#"))
    return {key.strip(): value.strip() for key, value in pairs}


def _flutter_ndk_version(local: dict[str, str], env: Mapping[str, str]) -> str | None:
    flutter = local.get("flutter.sdk") or env.get("FLUTTER_ROOT")
    if not flutter:
        return None
    extension = Path(flutter) / FLUTTER_EXTENSION
    if not extension.is_file():
        return None
    found = FLUTTER_NDK.search(extension.read_text(encoding="utf-8"))
    return found.group(1) if found else None


def ndk_version(android_dir: Path, env: Mapping[str, str]) -> str | None:
    """The NDK version app/android builds with: a literal ndkVersion, or flutter.ndkVersion."""
    gradle = android_dir / "app" / "build.gradle.kts"
    text = gradle.read_text(encoding="utf-8") if gradle.is_file() else ""
    literal = NDK_LITERAL.search(text)
    if literal:
        return literal.group(1)
    if NDK_FROM_FLUTTER.search(text) or not text:
        return _flutter_ndk_version(_properties(android_dir / "local.properties"), env)
    return None


def find_libcxx(android_dir: Path, *, ndk: Path | None = None, env: Mapping[str, str] | None = None) -> Path:
    """libc++_shared.so (arm64) of the NDK the app builds with. Exits with how to fix it."""
    env = os.environ if env is None else env
    if ndk is None:
        version = ndk_version(android_dir, env)
        local = _properties(android_dir / "local.properties")
        sdk = env.get("ANDROID_HOME") or env.get("ANDROID_SDK_ROOT") or local.get("sdk.dir")
        if not version or not sdk:
            sys.exit("error: cannot tell which Android NDK the app builds with "
                     f"(NDK version: {version or 'unknown'}, Android SDK: {sdk or 'unknown'}; "
                     "app/android/app/build.gradle.kts ndkVersion, flutter.sdk and sdk.dir in "
                     "app/android/local.properties, ANDROID_HOME). Give the NDK folder with --ndk.")
        ndk = Path(sdk) / "ndk" / version
    found = sorted(ndk.glob(LIBCXX_GLOB))
    if not found:
        sys.exit(f"error: {LIBCXX} (aarch64) not found in the NDK {ndk} ({LIBCXX_GLOB}). "
                 "Install that NDK version (Android Studio: SDK Manager, SDK Tools, NDK) or give "
                 "another NDK folder with --ndk.")
    return found[0]
