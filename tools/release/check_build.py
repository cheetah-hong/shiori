#!/usr/bin/env python3
"""Store settings of a built app and of the web pages (docs/release.md).

  python3 tools/release/check_build.py ios app/build/ios/iphoneos/Runner.app --flavor prod
  python3 tools/release/check_build.py apk app/build/app/outputs/flutter-apk/app-dev-debug.apk --flavor dev
  python3 tools/release/check_build.py site [--publish]

ios: home screen name of the flavor, iPhone only, the export compliance answer, the
     app's privacy manifest (present, a valid plist, the same as the source), and no
     framework without a privacy manifest beyond the known ones.
apk: the home screen label of the flavor and a target API level Google Play accepts
     (aapt from $ANDROID_HOME, or --aapt); with --release, no network permission.
site: the pages Pages publishes (site/): all there, no scripts, nothing loaded from
     other sites; with --publish, no contact placeholder left.

Prints each problem and exits 1, or prints ok.
"""
from __future__ import annotations

import argparse
import os
import plistlib
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SOURCE_MANIFEST = REPO / "app" / "ios" / "Runner" / "PrivacyInfo.xcprivacy"
SITE = REPO / "site"

NAMES = {"prod": "시오리", "dev": "시오리 dev"}

# Google Play: new apps and updates target API 36 or later from 2026-08-31.
MIN_TARGET_SDK = 36

# Frameworks that ship without a privacy manifest. Their required reason APIs
# are declared in the app's own manifest (sqlite3, voicevox_core,
# voicevox_onnxruntime), or they use none (App: Dart code, the runtime is in
# Flutter.framework; objective_c; integration_test). A new framework must be
# looked at (nm -u for stat, statfs, mach_absolute_time, ...) before it is added.
WITHOUT_MANIFEST = frozenset(
    {"App", "objective_c", "integration_test", "sqlite3", "voicevox_core", "voicevox_onnxruntime"}
)

SITE_PAGES = ("index.html", "privacy.html", "privacy-en.html", "support.html")
CONTACT_PLACEHOLDER = "{{CONTACT_EMAIL}}"


def _load_plist(path: Path) -> object:
    with path.open("rb") as f:
        return plistlib.load(f)


def _has_manifest(framework: Path) -> bool:
    return any(p.name == "PrivacyInfo.xcprivacy" for p in framework.rglob("PrivacyInfo.xcprivacy"))


def check_ios_app(app: Path, flavor: str, source_manifest: Path = SOURCE_MANIFEST) -> list[str]:
    """Problems of the built Runner.app for [flavor]; empty when it is fine."""
    info_path = app / "Info.plist"
    if not info_path.is_file():
        return [f"{app}: no Info.plist (is this a built Runner.app?)"]
    problems: list[str] = []
    info = _load_plist(info_path)
    assert isinstance(info, dict)
    name = NAMES[flavor]
    if info.get("CFBundleDisplayName") != name:
        problems.append(f"CFBundleDisplayName is {info.get('CFBundleDisplayName')!r}, not {name!r} ({flavor})")
    if info.get("UIDeviceFamily") != [1]:
        problems.append(f"UIDeviceFamily is {info.get('UIDeviceFamily')!r}, not [1] (iPhone only)")
    if info.get("ITSAppUsesNonExemptEncryption") is not False:
        problems.append("ITSAppUsesNonExemptEncryption is not false")

    manifest = app / "PrivacyInfo.xcprivacy"
    if not manifest.is_file():
        problems.append("PrivacyInfo.xcprivacy is not in the app (Runner target, Copy Bundle Resources)")
    else:
        try:
            built = _load_plist(manifest)
        except (plistlib.InvalidFileException, ValueError) as e:
            problems.append(f"PrivacyInfo.xcprivacy is not a valid plist: {e}")
        else:
            if built != _load_plist(source_manifest):
                problems.append("PrivacyInfo.xcprivacy in the app differs from app/ios/Runner/PrivacyInfo.xcprivacy")

    frameworks = app / "Frameworks"
    if frameworks.is_dir():
        for fw in sorted(frameworks.glob("*.framework")):
            if fw.stem not in WITHOUT_MANIFEST and not _has_manifest(fw):
                problems.append(
                    f"{fw.name} has no privacy manifest: check its required reason APIs, declare them "
                    "in app/ios/Runner/PrivacyInfo.xcprivacy, then add it to WITHOUT_MANIFEST"
                )
    return problems


def read_badging(badging: str) -> tuple[str | None, int | None]:
    """The default application label and the target API level in `aapt dump badging` output."""
    label = re.search(r"^application-label:'(.*)'$", badging, re.M)
    target = re.search(r"^targetSdkVersion:'(\d+)'$", badging, re.M)
    return (label.group(1) if label else None, int(target.group(1)) if target else None)


NETWORK_PERMISSIONS = ("android.permission.INTERNET", "android.permission.ACCESS_NETWORK_STATE")


def check_badging(badging: str, flavor: str, release: bool = False) -> list[str]:
    """[release]: a release APK must not ask for the network either, as the privacy
    policy says the app does not connect (docs/release.md 8.2: ML Kit brings these in)."""
    label, target = read_badging(badging)
    problems = []
    if release:
        for permission in NETWORK_PERMISSIONS:
            if f"uses-permission: name='{permission}'" in badging:
                problems.append(f"{permission} is in the release APK; remove it (docs/release.md 8.2) "
                                "or change the privacy policy")
    if label != NAMES[flavor]:
        problems.append(f"application label is {label!r}, not {NAMES[flavor]!r} ({flavor})")
    if target is None or target < MIN_TARGET_SDK:
        problems.append(f"targetSdkVersion is {target}, Google Play needs {MIN_TARGET_SDK} or later")
    return problems


def _aapt(given: str | None) -> str:
    if given:
        return given
    sdk = Path(os.environ.get("ANDROID_HOME") or Path.home() / "Library" / "Android" / "sdk")
    tools = sorted((sdk / "build-tools").glob("*/aapt"), key=lambda p: [int(x) for x in re.findall(r"\d+", p.parent.name)])
    if not tools:
        raise SystemExit(f"error: aapt not found under {sdk}/build-tools (set ANDROID_HOME or pass --aapt)")
    return str(tools[-1])


_SCRIPT = re.compile(r"<script\b", re.I)
_LOADED_FROM_OUTSIDE = re.compile(
    r"<(?:img|iframe|audio|video|source|embed|object)\b[^>]*\bsrc\s*=\s*[\"']?(?:https?:)?//"
    r"|<link\b[^>]*\bhref\s*=\s*[\"']?(?:https?:)?//"
    r"|url\(\s*[\"']?(?:https?:)?//",
    re.I,
)


def check_site(site: Path, publish: bool) -> list[str]:
    problems = []
    for name in SITE_PAGES:
        page = site / name
        if not page.is_file():
            problems.append(f"{name} is missing")
            continue
        text = page.read_text(encoding="utf-8")
        if _SCRIPT.search(text):
            problems.append(f"{name}: has a script (the pages run no code)")
        for m in _LOADED_FROM_OUTSIDE.finditer(text):
            problems.append(f"{name}: loads from another site: {m.group(0)}")
        if publish and CONTACT_PLACEHOLDER in text:
            problems.append(f"{name}: {CONTACT_PLACEHOLDER} is still there; fill in the contact first")
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="what", required=True)
    ios = sub.add_parser("ios", help="a built Runner.app")
    ios.add_argument("app", type=Path)
    ios.add_argument("--flavor", choices=sorted(NAMES), required=True)
    apk = sub.add_parser("apk", help="a built APK")
    apk.add_argument("apk", type=Path)
    apk.add_argument("--flavor", choices=sorted(NAMES), required=True)
    apk.add_argument("--aapt")
    apk.add_argument("--release", action="store_true", help="a release APK: no network permission")
    site = sub.add_parser("site", help="the web pages in site/")
    site.add_argument("--dir", type=Path, default=SITE)
    site.add_argument("--publish", action="store_true", help="also require the contact to be filled in")
    a = ap.parse_args(argv)

    if a.what == "ios":
        problems = check_ios_app(a.app, a.flavor)
    elif a.what == "apk":
        if not a.apk.is_file():
            problems = [f"{a.apk}: no such APK"]
        else:
            out = subprocess.run([_aapt(a.aapt), "dump", "badging", str(a.apk)],
                                 capture_output=True, text=True, check=False)
            problems = check_badging(out.stdout, a.flavor, a.release) if out.returncode == 0 else [
                f"aapt failed: {out.stderr.strip()}"]
    else:
        problems = check_site(a.dir, a.publish)

    for p in problems:
        print(f"error: {p}")
    if not problems:
        print("ok")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
