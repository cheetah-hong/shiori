// App Store and Play settings kept in the project files (docs/release.md):
// the export compliance answer, the privacy manifest, iPhone only, and the
// development build's own name. The built app is checked by
// tools/release/check_build.py.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/plist.dart';

/// Paths from app/.
const _infoPlist = 'ios/Runner/Info.plist';
const _privacyManifest = 'ios/Runner/PrivacyInfo.xcprivacy';
const _pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
const _gradle = 'android/app/build.gradle.kts';
const _androidManifest = 'android/app/src/main/AndroidManifest.xml';

const _prodName = '시오리';
const _devName = '시오리 dev';

/// The required reason APIs the app's own manifest declares for the
/// libraries that ship without one (docs/release.md): SQLite (file
/// timestamps, statfs) and the speech engine (file timestamps).
const _declaredReasons = {
  'NSPrivacyAccessedAPICategoryFileTimestamp': ['C617.1'],
  'NSPrivacyAccessedAPICategoryDiskSpace': ['E174.1'],
};

String _read(String path) => File(path).readAsStringSync();

/// The value of [setting] in an xcconfig file, or null.
String? _xcconfigValue(String text, String setting) {
  for (final line in text.split('\n')) {
    final m = RegExp(
      '^\\s*${RegExp.escape(setting)}\\s*=\\s*(.*?)\\s*\$',
    ).firstMatch(line);
    if (m != null) return m.group(1);
  }
  return null;
}

/// The block of the pbxproj object with [id] (from `id /* … */ = {` to its
/// closing `};` at the same indentation).
String _pbxObject(String pbx, String id) {
  final start = RegExp(
    '^(\\s*)${RegExp.escape(id)} /\\*[^*]*\\*/ = \\{',
    multiLine: true,
  ).firstMatch(pbx);
  if (start == null) throw StateError('no object $id in $_pbxproj');
  final end = pbx.indexOf('\n${start.group(1)}};', start.end);
  return pbx.substring(start.start, end);
}

void main() {
  group('Info.plist', () {
    final plist = readPlist(_read(_infoPlist));

    test('declares no non-exempt encryption', () {
      expect(plist['ITSAppUsesNonExemptEncryption'], isFalse);
    });

    test('says why it asks for the camera and the photo library', () {
      for (final key in [
        'NSCameraUsageDescription',
        'NSPhotoLibraryUsageDescription',
      ]) {
        final text = plist[key];
        expect(text, isA<String>(), reason: key);
        expect((text! as String).trim(), isNotEmpty, reason: key);
      }
    });

    test('does not open the app folder to the Files app', () {
      expect(plist.containsKey('UIFileSharingEnabled'), isFalse);
      expect(plist.containsKey('LSSupportsOpeningDocumentsInPlace'), isFalse);
    });

    test('takes its home screen name from the build configuration', () {
      expect(plist['CFBundleDisplayName'], r'$(APP_DISPLAY_NAME)');
    });

    test('has no iPad settings (iPhone only)', () {
      expect(
        plist.containsKey('UISupportedInterfaceOrientations~ipad'),
        isFalse,
      );
    });
  });

  group('privacy manifest', () {
    test('no tracking, no collected data, the declared reasons', () {
      final manifest = readPlist(_read(_privacyManifest));
      expect(manifest['NSPrivacyTracking'], isFalse);
      expect(manifest['NSPrivacyTrackingDomains'], isEmpty);
      expect(manifest['NSPrivacyCollectedDataTypes'], isEmpty);

      final types = manifest['NSPrivacyAccessedAPITypes']! as List<Object?>;
      final declared = <String, List<Object?>>{};
      for (final entry in types.cast<Map<String, Object?>>()) {
        final type = entry['NSPrivacyAccessedAPIType']! as String;
        expect(declared.containsKey(type), isFalse, reason: 'twice: $type');
        declared[type] =
            entry['NSPrivacyAccessedAPITypeReasons']! as List<Object?>;
      }
      expect(declared, _declaredReasons);
    });

    test('is copied into the app by the Runner target', () {
      final pbx = _read(_pbxproj);
      final file = RegExp(
        r'(\w{24}) /\* PrivacyInfo\.xcprivacy \*/ = \{isa = PBXFileReference;[^}]*path = PrivacyInfo\.xcprivacy;',
      ).firstMatch(pbx);
      expect(file, isNotNull, reason: 'file reference');
      final build = RegExp(
        '(\\w{24}) /\\* PrivacyInfo\\.xcprivacy in Resources \\*/ = '
        '\\{isa = PBXBuildFile; fileRef = ${file!.group(1)} ',
      ).firstMatch(pbx);
      expect(build, isNotNull, reason: 'build file');

      final runner = _pbxObject(
        pbx,
        RegExp(
          r'(\w{24}) /\* Runner \*/ = \{\s*isa = PBXNativeTarget;',
        ).firstMatch(pbx)!.group(1)!,
      );
      final resourcesId = RegExp(
        r'(\w{24}) /\* Resources \*/',
      ).firstMatch(runner)!.group(1)!;
      expect(_pbxObject(pbx, resourcesId), contains(build!.group(1)));
    });
  });

  test('every build configuration is iPhone only', () {
    final families = RegExp(
      r'TARGETED_DEVICE_FAMILY = ([^;]+);',
    ).allMatches(_read(_pbxproj)).map((m) => m.group(1)).toList();
    expect(families, isNotEmpty);
    expect(families, everyElement('"1"'));
  });

  group('home screen name', () {
    test('iOS: the dev configurations are named apart from prod', () {
      for (final mode in ['Debug', 'Profile', 'Release']) {
        expect(
          _xcconfigValue(
            _read('ios/Flutter/$mode-dev.xcconfig'),
            'APP_DISPLAY_NAME',
          ),
          _devName,
          reason: '$mode-dev',
        );
        expect(
          _xcconfigValue(
            _read('ios/Flutter/$mode-prod.xcconfig'),
            'APP_DISPLAY_NAME',
          ),
          _prodName,
          reason: '$mode-prod',
        );
      }
    });

    test('Android: each flavor sets the label the manifest uses', () {
      final gradle = _read(_gradle);
      String flavor(String name) {
        final m = RegExp(
          'create\\("$name"\\) \\{([^}]*)\\}',
        ).firstMatch(gradle);
        expect(m, isNotNull, reason: 'flavor $name');
        return m!.group(1)!;
      }

      expect(
        flavor('dev'),
        contains('manifestPlaceholders["appLabel"] = "$_devName"'),
      );
      expect(
        flavor('prod'),
        contains('manifestPlaceholders["appLabel"] = "$_prodName"'),
      );
      expect(_read(_androidManifest), contains(r'android:label="${appLabel}"'));
    });
  });

  test('Android targets the API level Flutter sets (36 or later)', () {
    // Flutter 3.41 sets 36; Google Play asks for 36 from 2026-08-31. The
    // built APK's level is checked by tools/release/check_build.py apk.
    expect(_read(_gradle), contains('targetSdk = flutter.targetSdkVersion'));
  });
}
