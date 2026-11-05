// 정보 → 오류 기록: the learner reads and copies the device's crash log.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/crash_reporting.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/about/about_screen.dart';

import '../support/harness.dart';

final class _MemoryLog implements CrashLog {
  _MemoryLog([List<CrashReport> records = const []]) : _records = [...records];

  final List<CrashReport> _records;
  Object? readError;

  @override
  Future<void> record(CrashReport report) async => _records.add(report);

  @override
  Future<List<CrashReport>> read() async {
    if (readError case final error?) throw error;
    return List.unmodifiable(_records);
  }

  @override
  Future<void> clear() async => _records.clear();
}

final _older = CrashReport(
  time: DateTime(2026, 11, 5, 20, 59),
  source: CrashSource.flutter,
  error: 'StateError: the older error',
  stack: '#0 OldWidget.build (package:shiori/old.dart:1:1)',
  context: 'while building OldWidget',
);

final _newer = CrashReport(
  time: DateTime(2026, 11, 5, 21),
  source: CrashSource.platform,
  error: 'StateError: the newest error',
  stack: '#0 save (package:shiori/save.dart:2:2)',
);

Future<void> _openLog(WidgetTester tester, _MemoryLog log) async {
  usePhoneSize(tester);
  final blocks = TestBlocks();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...blocks.overrides, crashLogProvider.overrideWithValue(log)],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const AboutScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('오류 기록 보기'), 200);
  await tester.tap(find.text('오류 기록 보기'));
  await tester.pumpAndSettle();
}

/// Captures what the app puts on the clipboard.
List<String> _captureClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add(
          (call.arguments as Map<Object?, Object?>)['text']! as String,
        );
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

void main() {
  testWidgets('no records: says so, and says what would be kept', (
    tester,
  ) async {
    await _openLog(tester, _MemoryLog());

    expect(find.text('기록된 오류가 없어요'), findsOneWidget);
    expect(find.textContaining('개인 정보'), findsOneWidget);
    expect(find.textContaining('이 기기에만'), findsWidgets);
  });

  testWidgets(
    'records: the newest comes first, copy puts them on the clipboard',
    (tester) async {
      final copied = _captureClipboard(tester);
      await _openLog(tester, _MemoryLog([_older, _newer]));

      expect(find.text('기록된 오류가 없어요'), findsNothing);
      final newest = find.textContaining('the newest error');
      final older = find.textContaining('the older error');
      expect(newest, findsOneWidget);
      expect(older, findsOneWidget);
      expect(
        tester.getTopLeft(newest).dy,
        lessThan(tester.getTopLeft(older).dy),
      );

      await tester.tap(find.byTooltip('복사'));
      await tester.pumpAndSettle();

      expect(copied, hasLength(1));
      final text = copied.single;
      expect(text, contains('the newest error'));
      expect(text, contains('the older error'));
      expect(text, contains('package:shiori/save.dart'));
      expect(
        text.indexOf('the newest error'),
        lessThan(text.indexOf('the older error')),
      );
      expect(find.text('오류 기록을 복사했어요'), findsOneWidget);
    },
  );

  testWidgets('clear empties the log on screen and on the device', (
    tester,
  ) async {
    final log = _MemoryLog([_newer]);
    await _openLog(tester, log);

    await tester.tap(find.byTooltip('지우기'));
    await tester.pumpAndSettle();

    expect(find.text('기록된 오류가 없어요'), findsOneWidget);
    expect(await log.read(), isEmpty);
  });

  testWidgets('a log that cannot be read says so', (tester) async {
    await _openLog(
      tester,
      _MemoryLog()..readError = const FileSystemException('locked'),
    );
    expect(find.text('오류 기록을 읽지 못했어요'), findsOneWidget);
  });
}
