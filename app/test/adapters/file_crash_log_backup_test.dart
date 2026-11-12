// The crash log stays out of device backups (iCloud, computer): it lives in a
// folder of its own that is marked excluded, while the learning database next
// to it is left in the backup.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/backup_exclusion.dart';
import 'package:shiori/adapters/file_crash_log.dart';
import 'package:shiori/app/crash_reporting.dart';

final _time = DateTime(2026, 11, 12, 22);

CrashReport _report(int i) => CrashReport(
  time: _time.add(Duration(minutes: 2 * i)),
  source: CrashSource.platform,
  error: 'StateError: error number $i',
);

final class _FakeExclusion implements BackupExclusion {
  final excluded = <String>[];
  Object? failure;

  @override
  Future<void> exclude(Directory directory) async {
    excluded.add(directory.path);
    if (failure case final error?) throw error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late _FakeExclusion exclusion;

  setUp(() {
    support = Directory.systemTemp.createTempSync('crash_backup');
    exclusion = _FakeExclusion();
  });
  tearDown(() => support.deleteSync(recursive: true));

  FileCrashLog logIn() => FileCrashLog.inSupportFolder(
    support: () async => support,
    exclusion: exclusion,
  );

  String inSupport(String name) => '${support.path}/$name';

  group('FileCrashLog.inSupportFolder', () {
    test('writes into its own folder and marks only that folder', () async {
      final log = logIn();
      await log.record(_report(1));

      final file = File(
        inSupport('${FileCrashLog.folderName}/${FileCrashLog.fileName}'),
      );
      expect(file.existsSync(), isTrue);
      expect(exclusion.excluded, [inSupport(FileCrashLog.folderName)]);
      // The support folder holds the learning database: never excluded.
      expect(exclusion.excluded, isNot(contains(support.path)));
      expect(await log.read(), hasLength(1));
    });

    test('marks the folder once, not on every write', () async {
      final log = logIn();
      for (var i = 0; i < 3; i++) {
        await log.record(_report(i));
      }
      await log.read();
      await log.clear();
      await log.record(_report(9));

      expect(exclusion.excluded, [inSupport(FileCrashLog.folderName)]);
    });

    test('moves a log kept by an earlier version into the folder', () async {
      final old = File(inSupport(FileCrashLog.fileName))
        ..writeAsStringSync('${jsonEncode(_report(1).toJson())}\n');

      final log = logIn();
      final records = await log.read();

      expect(records.map((r) => r.error), ['StateError: error number 1']);
      expect(old.existsSync(), isFalse);
      await log.record(_report(2));
      expect((await log.read()).map((r) => r.error), [
        'StateError: error number 1',
        'StateError: error number 2',
      ]);
    });

    test('still records when the folder cannot be marked', () async {
      exclusion.failure = PlatformException(code: 'exclude_failed');
      final log = logIn();
      await log.record(_report(1));

      expect(await log.read(), hasLength(1));
    });

    test('tries the mark again after a failure', () async {
      exclusion.failure = PlatformException(code: 'exclude_failed');
      final log = logIn();
      await log.record(_report(1));
      exclusion.failure = null;
      await log.record(_report(2));
      await log.record(_report(3));

      expect(exclusion.excluded, [
        inSupport(FileCrashLog.folderName),
        inSupport(FileCrashLog.folderName),
      ]);
    });
  });

  group('ChannelBackupExclusion', () {
    const channel = ChannelBackupExclusion.channel;
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'isExcluded' => true,
              _ => null,
            };
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('asks the platform to exclude the folder by its path', () async {
      await const ChannelBackupExclusion().exclude(Directory('/app/a'));

      expect(channel.name, 'shiori/backup');
      expect(calls.single.method, 'exclude');
      expect(calls.single.arguments, {'path': '/app/a'});
    });

    test('reads the mark back', () async {
      expect(await const ChannelBackupExclusion().isExcluded('/app/a'), isTrue);
      expect(calls.single.method, 'isExcluded');
      expect(calls.single.arguments, {'path': '/app/a'});
    });

    test('a platform error reaches the caller', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw PlatformException(code: 'outside_app'),
          );
      await expectLater(
        const ChannelBackupExclusion().exclude(Directory('/etc')),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  test('only iOS marks folders; Android keeps the app out of backups', () {
    expect(backupExclusionFor(isIOS: true), isA<ChannelBackupExclusion>());
    expect(backupExclusionFor(isIOS: false), isA<NoBackupExclusion>());
  });
}
