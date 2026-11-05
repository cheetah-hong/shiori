// A word-book page read with the row template, on a simulator: the review
// screen shows each cell's source and pairing confidence, "높음 N" in the
// summary, the piece of the page behind a cell, and "높음 전체 승인".
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/template_evidence_screenshots_test.dart
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

  testWidgets('template route: evidence, high count, approve', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 교재 페이지를 등록해 주세요'));

    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    final sample = find.text(devSamples.first.detail).first;
    await tester.scrollUntilVisible(sample, 200);
    await tester.pumpAndSettle();
    await tester.tap(sample);
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const ValueKey('high-count')));
    await shot(tester, '34_review_template_evidence');

    await tester.tap(find.byKey(const ValueKey('cell-0-meaning')));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('근거 조각'));
    await shot(tester, '35_review_template_evidence_piece');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('높음 전체 승인'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('확인됨'));
    await shot(tester, '36_review_template_approved');
  });
}
