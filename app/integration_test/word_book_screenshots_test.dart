// A synthetic word-book page read by the word extractor on a simulator: the
// review head without page info, a headword read back from its kana and
// meaning, the example page, the save and the playlist with the new words.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/word_book_screenshots_test.dart
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

  Future<void> openSample(WidgetTester tester, DevSample sample) async {
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    final row = find.text('${sample.page}쪽 · ${sample.layout}');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));
  }

  testWidgets('word-book sample: review, save, playlist', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));
    // The dictionaries unpack in the background; the 정보 screen waits.
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('JMdict 날짜'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    await shot(tester, '48_capture_word_book_samples');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await openSample(tester, devSamples.first);
    await shot(tester, '49_review_word_book');

    // 口 was read as a box glyph: read back from くち and 입 (사전 역조회).
    final readBack = find.text('口');
    await tester.scrollUntilVisible(readBack, 200);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await shot(tester, '50_review_word_book_read_back');

    await tester.tap(find.textContaining(RegExp(r'^단어 \d+개 추가$')));
    await tester.pumpAndSettle();
    // A fresh database has no playlist yet: the new-playlist form is already
    // open with 내 단어장 filled in.
    await waitFor(tester, find.text('만들고 추가'));
    await tester.tap(find.text('만들고 추가'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.textContaining('에 단어'));

    await openSample(tester, devSamples[2]);
    await shot(tester, '51_review_word_book_examples');
    await tester.tap(find.textContaining(RegExp(r'^단어 \d+개 추가$')));
    await tester.pumpAndSettle();
    // 내 단어장 exists now: add to it from the picker's list (its row is the
    // one on top, the home tile underneath shares its name).
    await waitFor(tester, find.text('내 단어장').last);
    await tester.tap(find.text('내 단어장').last);
    await tester.pumpAndSettle();
    await waitFor(tester, find.textContaining('에 단어'));
    await shot(tester, '52_home_after_word_book_save');

    await tester.tap(find.text('내 단어장').first);
    await tester.pumpAndSettle();
    await shot(tester, '53_textbook_new_words');
  });
}
