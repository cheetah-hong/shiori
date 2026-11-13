// N8: reminders are local notifications only. No push, no background mode,
// no network permission; the notification package is pinned and brings its
// own privacy manifest; Android asks only to post notifications.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/plist.dart';

/// Paths from app/.
const _infoPlist = 'ios/Runner/Info.plist';
const _entitlements = [
  'ios/Runner/Runner.entitlements',
  'ios/Runner/RunnerDebug.entitlements',
  'ios/Runner/RunnerProfile.entitlements',
  'ios/Runner/RunnerRelease.entitlements',
];
const _appDelegate = 'ios/Runner/AppDelegate.swift';
const _systemChannel = 'ios/Runner/SystemChannel.swift';
const _androidManifest = 'android/app/src/main/AndroidManifest.xml';
const _gradle = 'android/app/build.gradle.kts';

String _read(String path) => File(path).readAsStringSync();

/// Where package [name] lives, from the resolved package config.
Directory _packageDir(String name) {
  final config =
      jsonDecode(_read('.dart_tool/package_config.json'))
          as Map<String, Object?>;
  final entry = (config['packages']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .singleWhere((p) => p['name'] == name);
  final root = Uri.parse(entry['rootUri']! as String);
  final base = Uri.file('${Directory.current.path}/.dart_tool/');
  return Directory.fromUri(base.resolveUri(root));
}

void main() {
  group('iOS', () {
    test('Info.plist: no background mode and no push', () {
      final plist = readPlist(_read(_infoPlist));
      expect(plist.containsKey('UIBackgroundModes'), isFalse);
      expect(plist.keys.where((k) => k.contains('Notification')), isEmpty);
    });

    test('no push entitlement', () {
      for (final path in _entitlements) {
        final file = File(path);
        if (!file.existsSync()) continue;
        expect(file.readAsStringSync(), isNot(contains('aps-environment')));
      }
    });

    test('the app delegate sets up the plugin and the system channel', () {
      final delegate = _read(_appDelegate);
      expect(delegate, contains('UNUserNotificationCenter'));
      expect(delegate, contains('SystemChannel.register'));
      expect(delegate, isNot(contains('registerForRemoteNotifications')));
      final channel = _read(_systemChannel);
      expect(channel, contains('"shiori/system"'));
      expect(channel, contains('notificationStatus'));
      expect(channel, contains('openNotificationSettings'));
    });

    test('the package is pinned and carries its own privacy manifest', () {
      final pubspec = _read('pubspec.yaml');
      expect(
        RegExp(
          r'^  flutter_local_notifications: 22\.3\.3$',
          multiLine: true,
        ).hasMatch(pubspec),
        isTrue,
      );
      final dir = _packageDir('flutter_local_notifications');
      final manifests = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('PrivacyInfo.xcprivacy') &&
                f.path.contains('/ios/'),
          )
          .toList();
      expect(manifests, hasLength(1));
      final manifest = readPlist(manifests.single.readAsStringSync());
      expect(manifest['NSPrivacyTracking'], isFalse);
      expect(manifest['NSPrivacyCollectedDataTypes'], isEmpty);
    });
  });

  group('Android', () {
    final manifest = _read(_androidManifest);

    test('asks to post notifications, nothing more', () {
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      for (final p in [
        'android.permission.INTERNET',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.USE_EXACT_ALARM',
        'android.permission.USE_FULL_SCREEN_INTENT',
        'android.permission.FOREGROUND_SERVICE',
      ]) {
        expect(manifest, isNot(contains(p)), reason: p);
      }
    });

    test('the receivers are not exported', () {
      final receivers = RegExp(
        r'<receiver[\s\S]*?(?:/>|</receiver>)',
      ).allMatches(manifest).map((m) => m.group(0)!).toList();
      expect(receivers, isNotEmpty);
      for (final r in receivers) {
        expect(r, contains('android:exported="false"'), reason: r);
        expect(r, contains('com.dexterous.flutterlocalnotifications'));
      }
    });

    test('desugaring is on (the package needs it)', () {
      final gradle = _read(_gradle);
      expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
      expect(gradle, contains('coreLibraryDesugaring('));
    });
  });
}
