"""The store settings check of a built app (check_build.py), on made-up builds."""
from __future__ import annotations

import plistlib
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import check_build  # noqa: E402

MANIFEST = {
    "NSPrivacyTracking": False,
    "NSPrivacyTrackingDomains": [],
    "NSPrivacyCollectedDataTypes": [],
    "NSPrivacyAccessedAPITypes": [
        {
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryFileTimestamp",
            "NSPrivacyAccessedAPITypeReasons": ["C617.1"],
        },
    ],
}

BADGING = """package: name='com.nihongoapp.shiori.dev' versionCode='1' versionName='1.0.0'
sdkVersion:'24'
targetSdkVersion:'36'
uses-permission: name='android.permission.INTERNET'
application-label:'시오리 dev'
application-label-ko:'시오리 dev'
native-code: 'arm64-v8a'
"""


class IosAppTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.source = self.root / "PrivacyInfo.xcprivacy"
        self.source.write_bytes(plistlib.dumps(MANIFEST))
        self.app = self.root / "Runner.app"
        self.app.mkdir()
        self._info(
            CFBundleDisplayName="시오리",
            UIDeviceFamily=[1],
            ITSAppUsesNonExemptEncryption=False,
        )
        (self.app / "PrivacyInfo.xcprivacy").write_bytes(
            plistlib.dumps(MANIFEST, fmt=plistlib.FMT_BINARY)
        )
        self._framework("Flutter", manifest=True)
        self._framework("sqlite3")
        self._framework("share_plus", bundled_manifest=True)

    def _info(self, **values: object) -> None:
        (self.app / "Info.plist").write_bytes(plistlib.dumps(values, fmt=plistlib.FMT_BINARY))

    def _framework(self, name: str, manifest: bool = False, bundled_manifest: bool = False) -> None:
        path = self.app / "Frameworks" / f"{name}.framework"
        path.mkdir(parents=True)
        (path / name).write_bytes(b"binary")
        if manifest:
            (path / "PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps(MANIFEST))
        if bundled_manifest:
            bundle = path / f"{name}_privacy.bundle"
            bundle.mkdir()
            (bundle / "PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps({}))

    def _check(self, flavor: str = "prod") -> list[str]:
        return check_build.check_ios_app(self.app, flavor, source_manifest=self.source)

    def test_a_good_prod_build_passes(self) -> None:
        self.assertEqual(self._check(), [])

    def test_the_dev_build_needs_its_own_name(self) -> None:
        problems = self._check("dev")
        self.assertEqual(len(problems), 1)
        self.assertIn("시오리 dev", problems[0])
        self._info(CFBundleDisplayName="시오리 dev", UIDeviceFamily=[1],
                   ITSAppUsesNonExemptEncryption=False)
        self.assertEqual(self._check("dev"), [])

    def test_ipad_and_missing_encryption_answer_fail(self) -> None:
        self._info(CFBundleDisplayName="시오리", UIDeviceFamily=[1, 2])
        problems = self._check()
        self.assertEqual(len(problems), 2)
        self.assertTrue(any("UIDeviceFamily" in p for p in problems))
        self.assertTrue(any("ITSAppUsesNonExemptEncryption" in p for p in problems))

    def test_the_app_manifest_must_be_there_and_match_the_source(self) -> None:
        (self.app / "PrivacyInfo.xcprivacy").unlink()
        self.assertIn("PrivacyInfo.xcprivacy", self._check()[0])
        (self.app / "PrivacyInfo.xcprivacy").write_bytes(
            plistlib.dumps({**MANIFEST, "NSPrivacyAccessedAPITypes": []})
        )
        self.assertIn("differs", self._check()[0])

    def test_a_broken_manifest_fails(self) -> None:
        (self.app / "PrivacyInfo.xcprivacy").write_bytes(b"not a plist")
        self.assertEqual(len(self._check()), 1)

    def test_a_new_framework_without_a_manifest_fails(self) -> None:
        self._framework("analytics_kit")
        problems = self._check()
        self.assertEqual(len(problems), 1)
        self.assertIn("analytics_kit", problems[0])

    def test_no_app_fails(self) -> None:
        problems = check_build.check_ios_app(self.root / "missing.app", "prod",
                                             source_manifest=self.source)
        self.assertEqual(len(problems), 1)


class ApkTest(unittest.TestCase):
    def test_reads_label_and_target_level(self) -> None:
        self.assertEqual(check_build.read_badging(BADGING), ("시오리 dev", 36))

    def test_the_label_and_level_are_checked(self) -> None:
        self.assertEqual(check_build.check_badging(BADGING, "dev"), [])
        prod = check_build.check_badging(BADGING, "prod")
        self.assertEqual(len(prod), 1)
        self.assertIn("시오리", prod[0])
        old = BADGING.replace("targetSdkVersion:'36'", "targetSdkVersion:'35'")
        self.assertTrue(any("36" in p for p in check_build.check_badging(old, "dev")))

    def test_a_release_apk_must_not_ask_for_the_network(self) -> None:
        problems = check_build.check_badging(BADGING, "dev", release=True)
        self.assertEqual(len(problems), 1)
        self.assertIn("INTERNET", problems[0])
        clean = BADGING.replace("uses-permission: name='android.permission.INTERNET'\n", "")
        self.assertEqual(check_build.check_badging(clean, "dev", release=True), [])

    def test_unreadable_badging_fails(self) -> None:
        self.assertEqual(len(check_build.check_badging("nothing here", "dev")), 2)


class SiteTest(unittest.TestCase):
    def setUp(self) -> None:
        self.site = Path(tempfile.mkdtemp())
        for name in check_build.SITE_PAGES:
            (self.site / name).write_text(
                f"<!doctype html><title>{name}</title>"
                f'<a href="https://example.org/issues">문의</a>'
                f"<p>{check_build.CONTACT_PLACEHOLDER}</p>",
                encoding="utf-8",
            )

    def test_drafts_pass_with_the_placeholder(self) -> None:
        self.assertEqual(check_build.check_site(self.site, publish=False), [])

    def test_publishing_needs_the_contact_filled_in(self) -> None:
        problems = check_build.check_site(self.site, publish=True)
        self.assertEqual(len(problems), len(check_build.SITE_PAGES))
        self.assertIn(check_build.CONTACT_PLACEHOLDER, problems[0])

    def test_a_missing_page_fails(self) -> None:
        (self.site / "support.html").unlink()
        problems = check_build.check_site(self.site, publish=False)
        self.assertEqual(len(problems), 1)
        self.assertIn("support.html", problems[0])

    def test_scripts_and_outside_resources_fail(self) -> None:
        (self.site / "index.html").write_text(
            '<script src="x.js"></script><img src="https://tracker.example/p.gif">'
            '<link rel="stylesheet" href="https://fonts.example/a.css">',
            encoding="utf-8",
        )
        problems = check_build.check_site(self.site, publish=False)
        self.assertEqual(len(problems), 3)


if __name__ == "__main__":
    unittest.main()
