// The Korean glossary on a simulator: its credit line on the 정보 screen, and
// a meaning the page did not give filled from it on the review screen, with
// the glossary asset unpacked on the device.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/glossary_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. Needs app/assets/dict/ko-glossary.*
// (tools/dict/build_ko_glossary.py). Uses the synthetic sample pages only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

  testWidgets('정보 screen credit line and a filled meaning', (tester) async {
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
    final credit = find.textContaining('한국어기초사전, 국립국어원, CC BY-SA 2.0 KR');
    await waitFor(tester, find.text('한국어 뜻 사전'));
    await tester.scrollUntilVisible(credit, 200);
    await waitFor(tester, credit);
    // The card from its section label down, credit line whole.
    await tester.ensureVisible(find.text('한국어 뜻 사전'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -40));
    await shot(tester, '22_about_glossary');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Page 11: OCR read the row of 鼻 without its meaning cell.
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    final page11 = find.text('DAY 01 자연, 몸').last;
    await tester.ensureVisible(page11);
    await tester.pumpAndSettle();
    await tester.tap(page11);
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));
    await tester.scrollUntilVisible(find.text('鼻'), 200);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.text('코'), findsOneWidget);
    expect(find.byKey(const ValueKey('mark-meaning-inferred')), findsOneWidget);
    await shot(tester, '23_review_glossary_meaning');
  });
}
