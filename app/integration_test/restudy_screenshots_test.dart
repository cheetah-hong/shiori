// Studying learned words again on a simulator: 더 학습하기 on home and on the
// playlist screen, a word's 처음부터 다시 학습 and its 되돌리기 line, and the
// settings confirmation before every word is made new.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/restudy_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. In-memory database, synthetic
// sample pages only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/study/restudy_labels.dart';
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

  /// Presses 알고있음 on every card until 오늘 학습 끝. A press while the
  /// last answer is still being written is ignored, so each press waits for
  /// the progress line to move on.
  Future<void> knowAll(WidgetTester tester) async {
    await waitFor(tester, find.text('알고있음'));
    for (var i = 0; i < 20; i++) {
      if (find.text('오늘 학습 끝').evaluate().isNotEmpty) return;
      final progress = find.textContaining(RegExp(r'^\d+ / \d+$'));
      final before = tester.widget<Text>(progress).data;
      await tap(tester, find.text('알고있음'));
      for (var j = 0; j < 100; j++) {
        if (find.text('오늘 학습 끝').evaluate().isNotEmpty) break;
        if (progress.evaluate().isNotEmpty &&
            tester.widget<Text>(progress).data != before) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    await waitFor(tester, find.text('오늘 학습 끝'));
  }

  testWidgets('더 학습하기, 처음부터 다시 학습 and the reset confirmation', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));

    // A sample page, every word known at first sight (as many sessions as
    // it takes).
    await tap(tester, find.text('페이지 등록'));
    await tap(tester, find.text('DAY 20 여행·교통').first);
    await waitFor(tester, find.textContaining('개 추가'));
    await tap(tester, find.textContaining('개 추가').first);
    await waitFor(tester, find.text('만들고 추가'));
    await tap(tester, find.text('만들고 추가'));
    await waitFor(tester, find.textContaining('오늘 학습 시작'));
    while (find.textContaining('오늘 학습 시작').evaluate().isNotEmpty) {
      await tap(tester, find.textContaining('오늘 학습 시작'));
      await knowAll(tester);
      expect(find.text(RestudyLabels.more), findsOneWidget);
      await tap(tester, find.text('확인'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    // Nothing due and no new word: home offers 더 학습하기.
    await waitFor(tester, find.text(RestudyLabels.more));
    await shot(tester, '88_home_study_more');

    await tap(tester, find.text('내 단어장').first);
    await waitFor(tester, find.text(RestudyLabels.more));
    await shot(tester, '87_playlist_study_more');

    final library = DriftLibraryRepository(database);
    final playlist = (await library.playlists()).single;
    final words = await library.words(playlistId: playlist.id);
    final first = words.first;
    await tap(tester, find.byTooltip('${first.headword} 메뉴'));
    await shot(tester, '85_playlist_word_reset_menu');

    await tap(tester, find.text(RestudyLabels.resetWord));
    await waitFor(tester, find.text(RestudyLabels.wordReset(first.headword)));
    await shot(tester, '86_playlist_word_reset');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('설정'));
    await tap(tester, find.text(RestudyLabels.resetAll));
    await waitFor(tester, find.text(RestudyLabels.resetAllQuestion));
    await shot(tester, '89_settings_reset_all_confirm');

    await tap(tester, find.text('취소'));
    // 취소: only the one word made new above has no card.
    expect(
      await DriftReviewRepository(database).cards(),
      hasLength(words.length - 1),
    );
  });
}
