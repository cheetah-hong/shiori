// The dictionary on a simulator: the 정보 screen and the review screen's
// candidate chips, with the dictionary asset unpacked on the device.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/dictionary_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. Without the asset (a fresh clone),
// add --dart-define=EXPECT_DICTIONARY=false: the app must still start and say
// it has no dictionary; no screenshots are taken then.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

const _expectDictionary = bool.fromEnvironment(
  'EXPECT_DICTIONARY',
  defaultValue: true,
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    if (_expectDictionary) await binding.takeScreenshot(name);
  }

  /// Pumps until [finder] shows up (unpacking takes a few seconds).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).first;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('정보 screen and dictionary candidates', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 교재 페이지를 등록해 주세요'));

    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    if (!_expectDictionary) {
      await waitFor(tester, find.textContaining('사전 데이터가 들어 있지 않아요'));
      return;
    }
    await waitFor(tester, find.text('JMdict 날짜'));
    await shot(tester, '18_about_dictionary');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // List-layout page where OCR skipped two simple kanji.
    await tapText(tester, '페이지 등록');
    await tapText(tester, 'DAY 01 자연, 몸');
    await waitFor(tester, find.widgetWithText(ActionChip, '空'));
    await shot(tester, '19_review_candidates');
    await tester.tap(find.widgetWithText(ActionChip, '日'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mark-headword-corrected')), findsWidgets);
    await shot(tester, '20_review_candidate_picked');
  });
}
