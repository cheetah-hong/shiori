// The dictionary check on a simulator, synthetic sample pages only: how long
// unpacking and checking the real assets takes (sizes and sha256, printed),
// the 정보 screen with both editions, and the notice on the capture, review
// and 정보 screens when a dictionary did not open.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/dictionary_check_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. Needs app/assets/dict/ (JMdict and
// the Korean glossary). In-memory database, and the timing run unpacks into a
// fresh temporary folder: the simulator's data is not touched.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/shared/dictionary_notice.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Widget appWith(ShioriDatabase database, {List<Override> extra = const []}) =>
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database), ...extra],
        child: const ShioriApp(),
      );

  testWidgets('unpacking and checking the real assets: time', (tester) async {
    final dir = Directory.systemTemp.createTempSync('shiori_check_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final logs = <String>[];
    for (final run in ['first run (unpack + check)', 'next run (size only)']) {
      final watch = Stopwatch()..start();
      final dictionary = await openBundledDictionary(
        bundle: rootBundle,
        supportDirectory: () async => dir,
        log: logs.add,
      );
      final dictionaryMs = watch.elapsedMilliseconds;
      watch.reset();
      final glossary = await openBundledGlossary(
        bundle: rootBundle,
        supportDirectory: () async => dir,
        log: logs.add,
      );
      final glossaryMs = watch.elapsedMilliseconds;
      expect(dictionary.isAvailable, isTrue, reason: dictionary.problem);
      expect(glossary.isAvailable, isTrue, reason: glossary.problem);
      debugPrint(
        '[timing] $run: JMdict $dictionaryMs ms, glossary $glossaryMs ms',
      );
      dictionary.close();
      glossary.close();
    }
    for (final line in logs) {
      debugPrint('[timing] $line');
    }
  });

  testWidgets('정보: both editions, the converted-copy line', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(appWith(database));
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('JMdict 날짜'));
    await tester.scrollUntilVisible(
      find.textContaining('변환(가공)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(tester, '70_about_dictionary_converted');
  });

  final damaged = [
    bundledDictionaryProvider.overrideWith(
      (ref) async => const BundledDictionary.unavailable(
        'UnpackedAssetMismatch: sqliteSha256',
        problemKind: DictionaryProblem.damaged,
      ),
    ),
  ];

  testWidgets('a damaged dictionary: capture, review, 정보', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(appWith(database, extra: damaged));
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text(DictionaryNoticeText.title));
    await shot(tester, '71_capture_dictionary_damaged');

    final sample = devSamples.first;
    final row = find.text('${sample.page}쪽 · ${sample.layout}');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));
    await shot(tester, '72_review_without_dictionary');

    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text(DictionaryNoticeText.damaged));
    await shot(tester, '73_about_dictionary_damaged');
  });
}
