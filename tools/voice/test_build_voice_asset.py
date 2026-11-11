"""build_voice_asset.py and voice_sources.py on small made-up sources (no network).

  cd tools/voice && python3 -m unittest discover -p 'test_*.py'
"""
from __future__ import annotations

import contextlib
import gzip
import hashlib
import io
import json
import os
import plistlib
import stat
import sys
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "dict"))

import asset_check  # noqa: E402
import build_voice_asset as bva  # noqa: E402
import voice_sources as vs  # noqa: E402

DICT_DIR = bva.DICTIONARY_DIR
ORT_ID = "jp.example.voicevox.voicevox_onnxruntime"
CORE_ID = "jp.example.voicevox.voicevox_core"


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def make_tgz(files: dict[str, bytes]) -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for name, data in files.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    return buf.getvalue()


def make_zip(files: dict[str, bytes], symlinks: dict[str, str] | None = None) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        for name, data in files.items():
            z.writestr(name, data)
        for name, target in (symlinks or {}).items():
            info = zipfile.ZipInfo(name)
            info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o755) << 16
            z.writestr(info, target)
    return buf.getvalue()


def _plist(identifier: str, fmt=plistlib.FMT_XML) -> bytes:
    return plistlib.dumps({"CFBundleIdentifier": identifier, "CFBundleName": "x"}, fmt=fmt)


def fake_contents() -> dict[str, bytes]:
    """Made-up stand-ins for the official files, laid out like them."""
    dictionary = {f"{DICT_DIR}/{name}": f"made-up {name}\n".encode() * 50
                  for name in asset_check.VOICE_DICTIONARY_FILES}
    core = "voicevox_core.xcframework"
    ort = "voicevox_onnxruntime.xcframework"
    return {
        "vvm": b"made-up voice model " * 400,
        "vvm_terms": "made-up terms\n".encode(),
        "dictionary": make_tgz(dictionary),
        "core_ios": make_zip(
            {f"{core}/Info.plist": plistlib.dumps({"AvailableLibraries": []}),
             f"{core}/ios-arm64/voicevox_core.framework/Info.plist": _plist(CORE_ID),
             f"{core}/ios-arm64/voicevox_core.framework/voicevox_core": b"core binary",
             f"{core}/macos-arm64_x86_64/voicevox_core.framework/Versions/A/voicevox_core": b"mac"},
            symlinks={f"{core}/macos-arm64_x86_64/voicevox_core.framework/voicevox_core":
                      "Versions/A/voicevox_core"}),
        "ort_ios": make_zip(
            {f"{ort}/Info.plist": plistlib.dumps({"AvailableLibraries": []}),
             f"{ort}/ios-arm64/voicevox_onnxruntime.framework/Info.plist": _plist(ORT_ID),
             f"{ort}/ios-arm64_x86_64-simulator/voicevox_onnxruntime.framework/Info.plist":
                 _plist(ORT_ID, plistlib.FMT_BINARY),
             f"{ort}/ios-arm64/voicevox_onnxruntime.framework/voicevox_onnxruntime": b"ort binary"}),
        "core_android_arm64": make_zip(
            {"voicevox_core-android-arm64-0.17.1/LICENSE": b"MIT",
             "voicevox_core-android-arm64-0.17.1/lib/libvoicevox_core.so": b"core so"}),
        "ort_android_arm64": make_tgz(
            {"voicevox_onnxruntime-android-arm64-1.23.2/TERMS.txt": b"terms",
             "voicevox_onnxruntime-android-arm64-1.23.2/lib/libvoicevox_onnxruntime.so": b"ort so"}),
    }


def make_fake_sources(work: Path, contents: dict[str, bytes] | None = None
                      ) -> tuple[dict[str, vs.Source], Path]:
    """The made-up files under their official names in work/src, and pins that match them."""
    src = work / "src"
    src.mkdir(parents=True, exist_ok=True)
    sources = {}
    for key, data in (contents or fake_contents()).items():
        real = bva.SOURCES[key]
        (src / real.name).write_bytes(data)
        sources[key] = vs.Source(name=real.name, url=(src / real.name).as_uri(), bytes=len(data),
                                 sha256=_sha(data), title=real.title, license=real.license)
    return sources, src


def build_fake_voice(out: Path, work: Path, *, built_on: str = "2026-11-06") -> dict:
    """The voice asset in [out], built from the made-up sources."""
    sources, src = make_fake_sources(work)
    paths = bva.obtain_sources(bva.ASSET_SOURCES, sources, cache=work / "cache", source_dirs=[src])
    return bva.build_voice_asset(paths, out, built_on=built_on, sources=sources)


def quiet(fn, *args, **kwargs):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        return fn(*args, **kwargs)


class Tmp(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()


class PinsTest(unittest.TestCase):
    def test_every_official_source_is_pinned_by_version_size_and_sha256(self) -> None:
        for key, source in bva.SOURCES.items():
            with self.subTest(key=key):
                self.assertTrue(source.url.startswith("https://github.com/VOICEVOX/")
                                or source.url.startswith("https://github.com/r9y9/"), source.url)
                self.assertIn("/releases/download/", source.url)
                self.assertTrue(source.url.endswith("/" + source.name))
                self.assertGreater(source.bytes, 0)
                self.assertRegex(source.sha256, r"^[0-9a-f]{64}$")
                self.assertTrue(source.title and source.license)

    def test_the_model_and_dictionary_pins(self) -> None:
        # VOICEVOX Nemo (n0.vvm) of the 0.17.1 release; 女声4 ノーマル is style 10003
        self.assertEqual(bva.SOURCES["vvm"].name, "n0.vvm")
        self.assertEqual(bva.SOURCES["vvm"].url,
                         "https://github.com/VOICEVOX/voicevox_vvm/releases/download/0.17.1/n0.vvm")
        self.assertEqual(bva.SOURCES["vvm"].sha256,
                         "f9793559a0ecad1622c15e68674860d7d00ce2736cf02b3f46b083e989c74ec7")
        self.assertEqual(bva.SOURCES["vvm"].bytes, 75_175_864)
        self.assertEqual(bva.SOURCES["dictionary"].sha256,
                         "fe6ba0e43542cef98339abdffd903e062008ea170b04e7e2a35da805902f382a")


class VoiceAssetTest(Tmp):
    def test_the_edition_describes_every_file(self) -> None:
        out = self.tmp / "voice"
        edition = build_fake_voice(out, self.tmp)
        saved = json.loads((out / bva.EDITION_NAME).read_text(encoding="utf-8"))
        self.assertEqual(saved, edition)
        self.assertEqual(edition["variant"], "voicevox-0.17.1-n0vvm-style10003")
        self.assertEqual(edition["built_on"], "2026-11-06")
        self.assertEqual(edition["core_version"], "0.17.1")
        self.assertEqual(edition["model_file"], "n0.vvm")
        self.assertEqual(edition["dictionary_dir"], "open_jtalk_dic_utf_8-1.11")
        self.assertEqual(edition["style_id"], 10003)
        self.assertEqual(edition["credit"], "VOICEVOX Nemo")

        want = ["n0.vvm"] + [f"{DICT_DIR}/{n}" for n in asset_check.VOICE_DICTIONARY_FILES]
        self.assertEqual([f["path"] for f in edition["files"]], want)
        self.assertEqual(edition["files"][0]["gzip"], "n0.vvm.gz")
        self.assertEqual(edition["files"][-1]["gzip"], "open_jtalk_dic.unk.dic.gz")
        contents = fake_contents()
        with tarfile.open(fileobj=io.BytesIO(contents["dictionary"])) as tar:
            originals = {m.name: tar.extractfile(m).read() for m in tar.getmembers()}
        originals["n0.vvm"] = contents["vvm"]
        for entry in edition["files"]:
            with self.subTest(path=entry["path"]):
                gz = out / entry["gzip"]
                self.assertEqual(entry["gzip_bytes"], gz.stat().st_size)
                raw = gzip.decompress(gz.read_bytes())
                self.assertEqual(raw, originals[entry["path"]])
                self.assertEqual(entry["bytes"], len(raw))
                self.assertEqual(entry["sha256"], _sha(raw))

        names = [s["name"] for s in edition["sources"]]
        self.assertEqual(len(names), 3)
        for source in edition["sources"]:
            self.assertEqual(set(source), {"name", "url", "sha256", "license"})
        self.assertEqual(edition["sources"][0]["license"], "VOICEVOX 音声モデル 利用規約")
        self.assertEqual(edition["sources"][-1]["license"], "Modified BSD")

    def test_the_built_asset_passes_the_asset_check(self) -> None:
        out = self.tmp / "voice"
        build_fake_voice(out, self.tmp)
        self.assertEqual(asset_check.check_voice(out), [])

    def test_the_same_input_gives_the_same_bytes(self) -> None:
        a, b = self.tmp / "a", self.tmp / "b"
        build_fake_voice(a, self.tmp / "w")
        (self.tmp / "w" / "cache").rename(self.tmp / "first-cache")  # the second build starts afresh
        build_fake_voice(b, self.tmp / "w")
        files_a = {p.name: p.read_bytes() for p in a.iterdir()}
        files_b = {p.name: p.read_bytes() for p in b.iterdir()}
        self.assertEqual(files_a, files_b)
        self.assertEqual(len(files_a), 11)
        for name, data in files_a.items():
            if name.endswith(".gz"):
                self.assertEqual(data[4:8], b"\0\0\0\0", f"{name}: gzip mtime is not 0")

    def test_a_rebuild_replaces_the_files(self) -> None:
        out = self.tmp / "voice"
        build_fake_voice(out, self.tmp / "w1", built_on="2026-11-01")
        build_fake_voice(out, self.tmp / "w2", built_on="2026-11-06")
        edition = json.loads((out / bva.EDITION_NAME).read_text(encoding="utf-8"))
        self.assertEqual(edition["built_on"], "2026-11-06")
        self.assertEqual(asset_check.check_voice(out), [])
        self.assertFalse([p for p in out.iterdir() if p.name.startswith(".")])

    def test_a_rebuild_removes_gzip_files_the_new_edition_does_not_list(self) -> None:
        # the app bundles the whole folder: an old model left there would ship too
        out = self.tmp / "voice"
        out.mkdir()
        (out / "0.vvm.gz").write_bytes(b"old model")
        (out / "notes.txt").write_text("kept")
        build_fake_voice(out, self.tmp / "w")
        self.assertFalse((out / "0.vvm.gz").exists())
        self.assertTrue((out / "notes.txt").exists())
        self.assertEqual(asset_check.check_voice(out), [])

    def test_a_bad_built_on_day_is_refused(self) -> None:
        sources, src = make_fake_sources(self.tmp)
        paths = bva.obtain_sources(bva.ASSET_SOURCES, sources, cache=self.tmp / "c", source_dirs=[src])
        with self.assertRaises(SystemExit):
            bva.build_voice_asset(paths, self.tmp / "out", built_on="6 Nov", sources=sources)

    def test_a_dictionary_without_one_of_its_files_is_refused(self) -> None:
        contents = fake_contents()
        files = {f"{DICT_DIR}/{n}": b"x" for n in asset_check.VOICE_DICTIONARY_FILES if n != "sys.dic"}
        contents["dictionary"] = make_tgz(files)
        sources, src = make_fake_sources(self.tmp, contents)
        paths = bva.obtain_sources(bva.ASSET_SOURCES, sources, cache=self.tmp / "c", source_dirs=[src])
        with self.assertRaises(vs.SourceError) as e:
            bva.build_voice_asset(paths, self.tmp / "out", built_on="2026-11-06", sources=sources)
        self.assertIn("sys.dic", str(e.exception))
        self.assertFalse((self.tmp / "out" / bva.EDITION_NAME).exists())


class ObtainTest(Tmp):
    def setUp(self) -> None:
        super().setUp()
        self.sources, self.src = make_fake_sources(self.tmp)
        self.vvm = self.sources["vvm"]
        self.cache = self.tmp / "cache"

    def test_a_source_dir_file_is_checked_and_copied_into_the_cache(self) -> None:
        path = vs.obtain(self.vvm, cache=self.cache, source_dirs=[self.tmp / "empty", self.src])
        self.assertEqual(path, self.cache / "n0.vvm")
        self.assertEqual(path.read_bytes(), (self.src / "n0.vvm").read_bytes())
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o644)
        # Then the cache alone is enough, even offline.
        self.assertEqual(vs.obtain(self.vvm, cache=self.cache, offline=True), path)

    def test_a_source_with_another_sha256_is_refused(self) -> None:
        (self.src / "n0.vvm").write_bytes(b"n" * self.vvm.bytes)  # same size, other content
        with self.assertRaises(vs.SourceError) as e:
            vs.obtain(self.vvm, cache=self.cache, source_dirs=[self.src])
        self.assertIn("sha256", str(e.exception))
        self.assertFalse((self.cache / "n0.vvm").exists())

    def test_a_source_with_another_size_is_refused(self) -> None:
        (self.src / "n0.vvm").write_bytes(b"short")
        with self.assertRaises(vs.SourceError):
            vs.obtain(self.vvm, cache=self.cache, source_dirs=[self.src])

    def test_offline_without_a_cached_file_fails_and_says_so(self) -> None:
        with self.assertRaises(vs.SourceError) as e:
            vs.obtain(self.vvm, cache=self.cache, offline=True)
        self.assertIn("--offline", str(e.exception))

    def test_a_missing_file_is_downloaded_into_the_cache(self) -> None:
        path = vs.obtain(self.vvm, cache=self.cache)
        self.assertEqual(path.read_bytes(), (self.src / "n0.vvm").read_bytes())
        self.assertFalse([p for p in self.cache.iterdir() if p.name.endswith(".part")])

    def test_a_good_cached_file_is_not_downloaded_again(self) -> None:
        vs.obtain(self.vvm, cache=self.cache)
        (self.src / "n0.vvm").unlink()  # the URL no longer answers
        self.assertTrue(vs.obtain(self.vvm, cache=self.cache).is_file())

    def test_a_damaged_cached_file_is_downloaded_again(self) -> None:
        vs.obtain(self.vvm, cache=self.cache)
        (self.cache / "n0.vvm").write_bytes(b"damaged")
        path = vs.obtain(self.vvm, cache=self.cache)
        self.assertEqual(vs.sha256_file(path), self.vvm.sha256)
        (self.cache / "n0.vvm").write_bytes(b"damaged")
        with self.assertRaises(vs.SourceError):
            vs.obtain(self.vvm, cache=self.cache, offline=True)

    def test_a_download_with_another_sha256_is_refused_and_not_kept(self) -> None:
        (self.src / "n0.vvm").write_bytes(b"x" * self.vvm.bytes)
        with self.assertRaises(vs.SourceError):
            vs.obtain(self.vvm, cache=self.cache)
        self.assertEqual(list(self.cache.iterdir()) if self.cache.exists() else [], [])


class NativeTest(Tmp):
    def setUp(self) -> None:
        super().setUp()
        sources, src = make_fake_sources(self.tmp)
        self.paths = bva.obtain_sources(bva.NATIVE_SOURCES, sources, cache=self.tmp / "c",
                                        source_dirs=[src])
        self.ios = self.tmp / "ios" / "voicevox"
        self.jni = self.tmp / "jniLibs"
        self.libcxx = self.tmp / "ndk-libc++_shared.so"
        self.libcxx.write_bytes(b"made-up libc++")

    def install(self) -> None:
        bva.install_native(self.paths, ios_dir=self.ios, jni_dir=self.jni, libcxx=self.libcxx)

    def test_the_ios_frameworks_are_unpacked_with_their_links(self) -> None:
        self.install()
        core = self.ios / "voicevox_core.xcframework"
        self.assertEqual((core / "ios-arm64/voicevox_core.framework/voicevox_core").read_bytes(),
                         b"core binary")
        link = core / "macos-arm64_x86_64/voicevox_core.framework/voicevox_core"
        self.assertTrue(link.is_symlink())
        self.assertEqual(os.readlink(link), "Versions/A/voicevox_core")
        self.assertTrue((self.ios / "voicevox_onnxruntime.xcframework/Info.plist").is_file())

    def test_onnxruntime_bundle_identifiers_lose_their_underscores(self) -> None:
        self.install()
        ort = self.ios / "voicevox_onnxruntime.xcframework"
        plists = sorted(ort.rglob("Info.plist"))
        self.assertEqual(len(plists), 3)
        for path in plists:
            data = path.read_bytes()
            ident = plistlib.loads(data).get("CFBundleIdentifier")
            if ident is not None:
                self.assertEqual(ident, "jp.example.voicevox.voicevox-onnxruntime")
        simulator = ort / "ios-arm64_x86_64-simulator/voicevox_onnxruntime.framework/Info.plist"
        self.assertTrue(simulator.read_bytes().startswith(b"bplist"), "binary plist stays binary")
        core_plist = self.ios / "voicevox_core.xcframework/ios-arm64/voicevox_core.framework/Info.plist"
        self.assertEqual(plistlib.loads(core_plist.read_bytes())["CFBundleIdentifier"], CORE_ID)

    def test_the_android_libraries_go_to_arm64_v8a(self) -> None:
        self.install()
        arm64 = self.jni / "arm64-v8a"
        self.assertEqual(sorted(p.name for p in arm64.iterdir()),
                         ["libc++_shared.so", "libvoicevox_core.so", "libvoicevox_onnxruntime.so"])
        self.assertEqual((arm64 / "libvoicevox_core.so").read_bytes(), b"core so")
        self.assertEqual((arm64 / "libvoicevox_onnxruntime.so").read_bytes(), b"ort so")
        self.assertEqual((arm64 / "libc++_shared.so").read_bytes(), b"made-up libc++")
        for library in arm64.iterdir():
            self.assertEqual(stat.S_IMODE(library.stat().st_mode), 0o644, library.name)

    def test_installing_again_replaces_the_old_frameworks(self) -> None:
        self.install()
        stale = self.ios / "voicevox_core.xcframework" / "stale.txt"
        stale.write_text("old", encoding="utf-8")
        self.install()
        self.assertFalse(stale.exists())
        self.assertTrue((self.ios / "voicevox_core.xcframework/Info.plist").is_file())
        self.assertEqual(sorted(p.name for p in self.ios.iterdir()),
                         ["voicevox_core.xcframework", "voicevox_onnxruntime.xcframework"])

    def test_an_archive_member_outside_its_folder_is_refused(self) -> None:
        contents = fake_contents()
        contents["core_ios"] = make_zip({"voicevox_core.xcframework/Info.plist": b"x",
                                         "voicevox_core.xcframework/../../escape.txt": b"x"})
        sources, src = make_fake_sources(self.tmp / "bad", contents)
        paths = bva.obtain_sources(bva.NATIVE_SOURCES, sources, cache=self.tmp / "bad" / "c",
                                   source_dirs=[src])
        with self.assertRaises(vs.SourceError):
            bva.install_native(paths, ios_dir=self.ios, jni_dir=self.jni, libcxx=self.libcxx)
        self.assertFalse((self.tmp / "escape.txt").exists())
        self.assertFalse((self.tmp / "ios" / "escape.txt").exists())

    def test_a_link_pointing_outside_its_framework_is_refused(self) -> None:
        contents = fake_contents()
        contents["core_ios"] = make_zip({"voicevox_core.xcframework/Info.plist": b"x"},
                                        symlinks={"voicevox_core.xcframework/a": "../../../etc"})
        sources, src = make_fake_sources(self.tmp / "bad", contents)
        paths = bva.obtain_sources(bva.NATIVE_SOURCES, sources, cache=self.tmp / "bad" / "c",
                                   source_dirs=[src])
        with self.assertRaises(vs.SourceError):
            bva.install_native(paths, ios_dir=self.ios, jni_dir=self.jni, libcxx=self.libcxx)


class LibcxxTest(Tmp):
    """libc++_shared.so comes from the NDK the app builds with (flutter.ndkVersion)."""

    VERSION = "99.1.12345"

    def make_tree(self, gradle_ndk: str = "flutter.ndkVersion") -> tuple[Path, Path]:
        android = self.tmp / "android"
        (android / "app").mkdir(parents=True)
        (android / "app" / "build.gradle.kts").write_text(
            f"android {{\n    ndkVersion = {gradle_ndk}\n}}\n", encoding="utf-8")
        sdk = self.tmp / "sdk"
        flutter = self.tmp / "flutter"
        (android / "local.properties").write_text(f"sdk.dir={sdk}\nflutter.sdk={flutter}\n",
                                                  encoding="utf-8")
        ext = flutter / "packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
        ext.parent.mkdir(parents=True)
        ext.write_text(f'    val ndkVersion: String = "{self.VERSION}"\n', encoding="utf-8")
        lib = (sdk / "ndk" / self.VERSION / "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib"
               / "aarch64-linux-android" / "libc++_shared.so")
        lib.parent.mkdir(parents=True)
        lib.write_bytes(b"libc++")
        return android, lib

    def test_the_flutter_ndk_version_is_followed(self) -> None:
        android, lib = self.make_tree()
        self.assertEqual(bva.find_libcxx(android, env={}), lib)

    def test_a_literal_ndk_version_wins(self) -> None:
        android, _ = self.make_tree(gradle_ndk='"98.0.1"')
        other = (self.tmp / "sdk/ndk/98.0.1/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib"
                 / "aarch64-linux-android/libc++_shared.so")
        other.parent.mkdir(parents=True)
        other.write_bytes(b"other")
        self.assertEqual(bva.find_libcxx(android, env={}), other)

    def test_android_home_wins_over_local_properties(self) -> None:
        android, lib = self.make_tree()
        moved = self.tmp / "sdk-env"
        (self.tmp / "sdk").rename(moved)
        found = bva.find_libcxx(android, env={"ANDROID_HOME": str(moved)})
        self.assertEqual(found, moved / lib.relative_to(self.tmp / "sdk"))

    def test_an_ndk_dir_given_by_hand_is_used(self) -> None:
        android, lib = self.make_tree()
        ndk = self.tmp / "sdk" / "ndk" / self.VERSION
        self.assertEqual(bva.find_libcxx(android, ndk=ndk, env={}), lib)

    def test_a_missing_ndk_fails_with_a_clear_message(self) -> None:
        android, lib = self.make_tree()
        lib.unlink()
        with self.assertRaises(SystemExit) as e:
            bva.find_libcxx(android, env={})
        message = str(e.exception.code)
        self.assertIn(self.VERSION, message)
        self.assertIn("--ndk", message)

    def test_an_unknown_ndk_version_fails_with_a_clear_message(self) -> None:
        android, _ = self.make_tree()
        (android / "local.properties").write_text(f"sdk.dir={self.tmp / 'sdk'}\n", encoding="utf-8")
        with self.assertRaises(SystemExit) as e:
            bva.find_libcxx(android, env={})
        self.assertIn("--ndk", str(e.exception.code))


class MainTest(Tmp):
    def test_main_builds_the_asset_and_the_engines(self) -> None:
        sources, src = make_fake_sources(self.tmp)
        out, ios, jni = self.tmp / "voice", self.tmp / "ios", self.tmp / "jni"
        ndk = self.tmp / "ndk"
        lib = ndk / "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android"
        lib.mkdir(parents=True)
        (lib / "libc++_shared.so").write_bytes(b"libc++")
        argv = ["--cache", str(self.tmp / "cache"), "--source-dir", str(src), "--out-dir", str(out),
                "--built-on", "2026-11-06", "--native", "--ios-dir", str(ios), "--jni-dir", str(jni),
                "--ndk", str(ndk)]
        with mock.patch.dict(bva.SOURCES, sources):
            self.assertEqual(quiet(bva.main, argv), 0)
            self.assertEqual(asset_check.check_voice(out), [])
            self.assertTrue((ios / "voicevox_onnxruntime.xcframework").is_dir())
            self.assertTrue((jni / "arm64-v8a" / "libc++_shared.so").is_file())
            # --check builds nothing and passes on the asset just built.
            self.assertEqual(quiet(bva.main, ["--check", "--out-dir", str(out)]), 0)
            # Offline with the cache filled works without the source dir.
            argv = ["--cache", str(self.tmp / "cache"), "--offline", "--out-dir", str(self.tmp / "v2"),
                    "--built-on", "2026-11-06"]
            self.assertEqual(quiet(bva.main, argv), 0)

    def test_main_stops_on_a_bad_source(self) -> None:
        sources, src = make_fake_sources(self.tmp)
        (src / "n0.vvm").write_bytes(b"not it")
        argv = ["--cache", str(self.tmp / "cache"), "--source-dir", str(src),
                "--out-dir", str(self.tmp / "voice"), "--offline"]
        with mock.patch.dict(bva.SOURCES, sources):
            with self.assertRaises(SystemExit) as e:
                quiet(bva.main, argv)
        self.assertNotEqual(e.exception.code, 0)
        self.assertFalse((self.tmp / "voice").exists())


if __name__ == "__main__":
    unittest.main()
