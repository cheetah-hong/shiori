// 이미 알아요 on a simulator: the study card's hide button and 되돌리기, the
// textbook list with its hidden words opened, and the home shelf count.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/known_hide_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. In-memory database, synthetic
// sample pages only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/shared/hide_labels.dart';
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

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('hide from the study card and the textbook list', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 교재 페이지를 등록해 주세요'));

    // Page 10 of the samples: DAY 01, 12 words.
    await tap(tester, find.text('페이지 등록'));
    await tap(tester, find.text('DAY 01 자연, 몸').first);
    await waitFor(tester, find.textContaining('개 저장'));
    await tap(tester, find.textContaining('개 저장').first);
    await waitFor(tester, find.textContaining('오늘 학습 시작'));

    await tap(tester, find.textContaining('오늘 학습 시작'));
    await waitFor(tester, find.text(HideLabels.button));
    await shot(tester, '24_study_hide_button');

    final first = DriftLibraryRepository(database);
    final headword = (await first.words()).first.headword;
    await tap(tester, find.text(HideLabels.button));
    expect(find.text(HideLabels.hidden(headword)), findsOneWidget);
    await shot(tester, '25_study_hidden_undo');

    await tap(tester, find.text(HideLabels.undo));
    expect(find.text(headword), findsOneWidget);
    await tap(tester, find.text(HideLabels.button));

    // Back home, then the textbook: hide one more word from the list.
    await tap(tester, find.byTooltip('학습 그만하기'));
    await waitFor(tester, find.textContaining(HideLabels.hiddenCount(1)));
    await tap(tester, find.text('JLPT 단어장').first);
    final second = (await first.words())[2].headword;
    await tap(tester, find.byTooltip(HideLabels.hideWord(second)));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final toggle = find.text(HideLabels.showHidden(2));
    await tester.scrollUntilVisible(toggle, 300);
    await tap(tester, toggle);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await shot(tester, '26_textbook_hidden_open');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await waitFor(tester, find.textContaining(HideLabels.hiddenCount(2)));
    await shot(tester, '27_home_hidden_count');
  });
}
