// The four ways of studying on a simulator: the mode chips on home and on a
// playlist, the cards of 일본어 떠올리기, 듣고 맞히기 and 객관식 before and
// after an answer, the four memory meters of a word, and the reason a mode
// cannot be picked.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/study_modes_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. In-memory database, made-up words
// only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

/// Made-up words (headword, reading, meaning, part of speech); the first
/// has a made-up example.
const _words = [
  ('試語甲', 'しごこう', '시험 낱말 갑', PartOfSpeech.noun),
  ('試語乙', 'しごおつ', '시험 낱말 을', PartOfSpeech.noun),
  ('試語丙', 'しごへい', '시험 낱말 병', PartOfSpeech.noun),
  ('試語丁', 'しごてい', '시험 낱말 정', PartOfSpeech.verb),
  ('試語戊', 'しごぼ', '시험 낱말 무', PartOfSpeech.verb),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Future<ShioriDatabase> seeded() async {
    final database = ShioriDatabase.memory();
    await LibraryService(
      library: DriftLibraryRepository(database),
      clock: const SystemClock(),
    ).addDraft(
      CaptureDraft(
        entries: [
          for (final (i, (head, kana, meaning, pos)) in _words.indexed)
            CapturedEntry(
              headword: head,
              readings: [kana],
              pos: pos,
              meaning: meaning,
              example: i == 0
                  ? const Example(ja: '試語甲を三回書く。', ko: '시험 낱말 갑을 세 번 쓴다.')
                  : null,
            ),
        ],
      ),
      to: const NewPlaylist('시험 목록'),
    );
    return database;
  }

  Future<void> start(WidgetTester tester) async {
    await tap(tester, find.textContaining('오늘 학습 시작'));
  }

  Future<void> stop(WidgetTester tester) async {
    await tap(tester, find.byTooltip('학습 그만하기'));
  }

  /// The option of the word with headword [head]'s meaning.
  Finder option(String meaning) => find.ancestor(
    of: find.text(meaning),
    matching: find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('option-'),
    ),
  );

  testWidgets('study modes', (tester) async {
    final database = await seeded();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('객관식'));
    await shot(tester, '95_home_mode_chips');

    // 일본어 떠올리기: the meaning first, the Japanese on 일본어 보기.
    await tap(tester, find.text('일본어 떠올리기'));
    await start(tester);
    await waitFor(tester, find.text('일본어 보기'));
    await shot(tester, '97_recall_front');
    await tap(tester, find.text('일본어 보기'));
    await shot(tester, '98_recall_shown');
    await tap(tester, find.text('알고있음'));
    await stop(tester);

    // 듣고 맞히기: the word plays by itself; a pick shows it.
    await tap(tester, find.text('듣고 맞히기'));
    await waitFor(tester, find.text('오늘 학습 시작 · 5장'));
    await shot(tester, '96_home_listening');
    await start(tester);
    await waitFor(tester, find.byTooltip('다시 듣기'));
    await tester.pump(const Duration(seconds: 2));
    await shot(tester, '99_listening_front');
    await tap(tester, option('시험 낱말 갑'));
    await waitFor(tester, find.text('맞았어요'));
    await shot(tester, '100_listening_answered');
    await tap(tester, find.text('다음'));
    await stop(tester);

    // 객관식: a wrong pick marks the answer.
    await tap(tester, find.text('객관식'));
    await start(tester);
    await waitFor(tester, find.text('試語甲'));
    await shot(tester, '101_choice_front');
    final wrong = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('option-') &&
          find
              .descendant(
                of: find.byKey(w.key!),
                matching: find.text('시험 낱말 갑'),
              )
              .evaluate()
              .isEmpty,
    );
    await tap(tester, wrong);
    await waitFor(tester, find.text('틀렸어요'));
    await shot(tester, '102_choice_wrong');
    await tap(tester, find.text('다음'));
    await stop(tester);

    // The playlist: the same chips and four meters per word.
    await tap(tester, find.text('시험 목록'));
    await waitFor(tester, find.text('試語甲'));
    await shot(tester, '103_playlist_mode_meters');
  });

  testWidgets('without speech, 듣고 맞히기 says why', (tester) async {
    final database = await seeded();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          speechProvider.overrideWithValue(const SilentSpeech()),
        ],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('듣고 맞히기'));
    await tap(tester, find.text('듣고 맞히기'));
    await waitFor(tester, find.text('발음을 들을 수 없어 고를 수 없어요'));
    await shot(tester, '104_listening_unavailable');
  });
}
