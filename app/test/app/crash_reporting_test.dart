// Uncaught errors go to a log on the device; recording never breaks the app.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/file_crash_log.dart';
import 'package:shiori/app/crash_reporting.dart';

final _time = DateTime(2026, 11, 5, 21);

CrashReport _report(int i, {String? stack}) => CrashReport(
  time: _time.add(Duration(seconds: i)),
  source: CrashSource.platform,
  error: 'StateError: error number $i',
  stack: stack,
);

/// Installs the handlers for one test body and puts the previous ones back.
Future<T> _withHandlers<T>(
  CrashReporter reporter,
  Future<T> Function(PlatformDispatcher dispatcher) body, {
  FlutterExceptionHandler? present,
}) async {
  final dispatcher = PlatformDispatcher.instance;
  final previousFlutter = FlutterError.onError;
  final previousPlatform = dispatcher.onError;
  try {
    installCrashHandlers(
      reporter,
      dispatcher: dispatcher,
      now: () => _time,
      present: present,
    );
    return await body(dispatcher);
  } finally {
    FlutterError.onError = previousFlutter;
    dispatcher.onError = previousPlatform;
  }
}

FlutterErrorDetails _buildError() => FlutterErrorDetails(
  exception: StateError('broken widget'),
  stack: StackTrace.current,
  library: 'widgets library',
  context: ErrorDescription('while building TestWidget'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('crash_log_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  FileCrashLog logIn(Directory d, {int? maxBytes}) => FileCrashLog(
    directory: () async => d,
    maxBytes: maxBytes ?? FileCrashLog.defaultMaxBytes,
  );

  File logFile() => File('${dir.path}/${FileCrashLog.fileName}');

  group('global handlers', () {
    test(
      'a framework error and an async error are both recorded, and the app goes on',
      () async {
        final log = logIn(dir);
        final presented = <FlutterErrorDetails>[];

        final handled = await _withHandlers(log, (dispatcher) async {
          FlutterError.reportError(_buildError());
          final result = dispatcher.onError!(
            StateError('nobody awaited this'),
            StackTrace.current,
          );
          return result;
        }, present: presented.add);

        // Usual handling stays: the framework error is still presented, the
        // platform error is left to the engine.
        expect(presented, hasLength(1));
        expect(handled, isFalse);

        final records = await log.read();
        expect(records.map((r) => r.source), [
          CrashSource.flutter,
          CrashSource.platform,
        ]);
        expect(records[0].error, contains('broken widget'));
        expect(records[0].context, contains('while building TestWidget'));
        expect(records[0].stack, isNotEmpty);
        expect(records[0].time, _time);
        expect(records[1].error, contains('nobody awaited this'));
        expect(records[1].stack, isNotEmpty);
      },
    );

    test('records survive a new log on the same file (app restart)', () async {
      await logIn(dir).record(_report(1));
      final again = await logIn(dir).read();
      expect(again.single.error, 'StateError: error number 1');
      expect(again.single.time, _time.add(const Duration(seconds: 1)));
    });

    test('clear empties the log', () async {
      final log = logIn(dir);
      await log.record(_report(1));
      await log.clear();
      expect(await log.read(), isEmpty);
    });

    test('no file yet reads as no records', () async {
      expect(await logIn(dir).read(), isEmpty);
    });

    test('lines that are not records are skipped', () async {
      logFile().writeAsStringSync(
        '${jsonEncode(_report(1).toJson())}\nnot json\n{"half": \n',
      );
      final records = await logIn(dir).read();
      expect(records.single.error, 'StateError: error number 1');
    });
  });

  group('size limit', () {
    test(
      'the oldest records go first and the file stays under the limit',
      () async {
        const limit = 2000;
        final log = logIn(dir, maxBytes: limit);
        for (var i = 0; i < 40; i++) {
          await log.record(_report(i, stack: '#0 main (file.dart:$i)'));
        }

        expect(logFile().lengthSync(), lessThanOrEqualTo(limit));
        final records = await log.read();
        expect(records, isNotEmpty);
        expect(records.length, lessThan(40));
        // The newest is kept, the oldest are gone, the order is unchanged.
        expect(records.last.error, 'StateError: error number 39');
        expect(records.first.error, isNot('StateError: error number 0'));
        final numbers = [
          for (final r in records) int.parse(r.error.split(' ').last),
        ];
        expect(numbers, [for (var n = numbers.first; n < 40; n++) n]);
      },
    );

    test('one record larger than the limit is cut, not dropped', () async {
      const limit = 1000;
      final log = logIn(dir, maxBytes: limit);
      await log.record(_report(1));
      await log.record(
        CrashReport(
          time: _time,
          source: CrashSource.flutter,
          error: 'E' * 5000,
          stack: List.filled(500, '#1 frame (file.dart:1)').join('\n'),
        ),
      );

      expect(logFile().lengthSync(), lessThanOrEqualTo(limit));
      final records = await log.read();
      expect(records.last.source, CrashSource.flutter);
      expect(records.last.error, startsWith('EEEE'));
    });
  });

  group('when the log cannot be written', () {
    test('record completes quietly', () async {
      final log = FileCrashLog(
        directory: () async => throw const FileSystemException('no folder'),
      );
      await expectLater(log.record(_report(1)), completes);
    });

    test('a folder that is really a file: record completes quietly', () async {
      final notADir = File('${dir.path}/plain-file')..writeAsStringSync('x');
      final log = FileCrashLog(directory: () async => Directory(notADir.path));
      await expectLater(log.record(_report(1)), completes);
    });

    test('the usual error handling still runs and nothing escapes', () async {
      final log = FileCrashLog(
        directory: () async => throw const FileSystemException('no folder'),
      );
      final presented = <FlutterErrorDetails>[];

      final handled = await _withHandlers(log, (dispatcher) async {
        FlutterError.reportError(_buildError());
        final result = dispatcher.onError!(
          StateError('async'),
          StackTrace.current,
        );
        // Let the failed writes finish inside the test.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return result;
      }, present: presented.add);

      expect(presented, hasLength(1));
      expect(handled, isFalse);
    });
  });
}
