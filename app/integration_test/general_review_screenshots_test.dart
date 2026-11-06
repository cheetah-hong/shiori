// The word extractor on a simulator: a synthetic page laid out unlike a
// word book; the review screen shows where each
// cell came from, how sure its pairing is, the piece of the page behind a
// cell, the tray of unpaired fragments; then the words are saved.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/general_review_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. Needs app/assets/dict/ (JMdict and
// the Korean glossary). Uses the synthetic sample pages only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  /// Pumps until [finder] shows up (unpacking takes a few seconds).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  testWidgets('review evidence, tray, save', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 교재 페이지를 등록해 주세요'));
    // The dictionaries unpack in the background (a page waits for them).
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    final credits = find.text('단어 추출 데이터');
    await tester.scrollUntilVisible(credits, 200);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await shot(tester, '32_about_extract_credits');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    final sample = find.text(generalDevSamples[1].detail);
    await tester.scrollUntilVisible(sample, 200);
    await tester.pumpAndSettle();
    await shot(tester, '28_capture_general_samples');
    await tester.tap(sample);
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));
    await shot(tester, '29_review_general');

    await tester.tap(find.byKey(const ValueKey('cell-0-meaning')));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('근거 조각'));
    await shot(tester, '30_review_general_evidence');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    final tray = find.textContaining('짝 없는 조각');
    await tester.scrollUntilVisible(tray, 300);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await shot(tester, '31_review_general_tray');

    await tester.tap(find.textContaining(RegExp(r'^단어 \d+개 저장$')));
    await tester.pumpAndSettle();
    await waitFor(tester, find.textContaining('저장했어요'));
    await shot(tester, '33_home_after_general_save');
  });
}
