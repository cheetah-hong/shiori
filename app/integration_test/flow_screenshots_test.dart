// Drives the whole flow on a simulator and saves a screenshot per step.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/flow_screenshots_test.dart
//
// Screenshots land in docs/screenshots/ (see test_driver/integration_test.dart).
// Uses the synthetic sample pages (assets/dev_samples/), so no camera is needed,
// and an in-memory database (see persistence_test.dart for the real file).
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

  /// Pumps until [finder] shows up (providers load asynchronously on device).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tapText(
    WidgetTester tester,
    String text, {
    bool last = false,
  }) async {
    final finder = last ? find.text(text).last : find.text(text).first;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('sample page → review → save → study', (tester) async {
    // A fresh in-memory database, so every run starts from an empty home.
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));
    await shot(tester, '01_home_empty');

    // Entry-layout page with examples (layout B).
    await tapText(tester, '페이지 등록');
    await shot(tester, '02_capture');
    await tapText(tester, 'DAY 20 여행·교통');
    expect(find.text('검토'), findsOneWidget);
    await shot(tester, '03_review_examples');
    await tapText(tester, '단어 6개 추가');
    // A fresh database has no playlist yet: the new-playlist form is already
    // open with 내 단어장 filled in.
    await waitFor(tester, find.text('만들고 추가'));
    await tapText(tester, '만들고 추가');
    await shot(tester, '04_home_after_save');

    // Study: covered card, revealed card, retry, then finish.
    await tapText(tester, '오늘 학습 시작 · 6장');
    await shot(tester, '05_study_card_covered');
    await tapText(tester, '뜻 보기');
    await tapText(tester, '읽기 보기');
    await shot(tester, '06_study_card_revealed');
    await tapText(tester, '다시 학습');
    for (var i = 0; i < 5; i++) {
      await tapText(tester, '알고있음');
    }
    expect(find.text('다시 1'), findsOneWidget);
    await shot(tester, '07_study_retried_card');
    await tapText(tester, '알고있음');
    expect(find.text('오늘 학습 끝'), findsOneWidget);
    await shot(tester, '08_session_done');
    await tapText(tester, '확인');
    await shot(tester, '09_home_after_study');

    // Word-list page where OCR skipped two simple kanji.
    await tapText(tester, '페이지 등록');
    await tapText(tester, 'DAY 01 자연, 몸');
    expect(find.byKey(const ValueKey('review-heading')), findsOneWidget);
    await shot(tester, '10_review_flags');
    await tester.tap(find.byTooltip('고치기').first);
    await tester.pumpAndSettle();
    await shot(tester, '11_entry_editor');
    await tapText(tester, '고치기', last: true);
    await shot(tester, '12_review_fixed');
    await tester.tap(find.textContaining('개 추가').last);
    await tester.pumpAndSettle();
    // 내 단어장 already exists: pick its row (the one on top; the home tile
    // underneath shares its name).
    await waitFor(tester, find.text('내 단어장').last);
    await tapText(tester, '내 단어장', last: true);
    await shot(tester, '13_home_two_pages');

    // Library: playlist words with memory levels.
    await tapText(tester, '내 단어장');
    await shot(tester, '14_textbook_days');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await shot(tester, '15_textbook_memory_levels');
  });
}
