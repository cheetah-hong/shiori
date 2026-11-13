// 단어 고치기·직접 추가·단어 찾기 on iPhone 17 Pro: the playlist with its
// magnifier and 「단어 추가」, the word sheet, the editor with the
// dictionary's suggestions, the dialog for a headword another word has, the
// adder (filled from the dictionary, kanji spellings for kana, a stored
// word), the search (results; no match in dark) and the editor in large
// text. Made-up words and made-up dictionary data only.
//
//   cd app && flutter drive -d <iPhone 17 Pro simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/word_edit_screenshots_test.dart
//
// Screenshots land in docs/screenshots/ (190–199). In-memory database.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/onboarding/onboarding_store.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/features/playlists/playlists_screen.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

final _lexicon = InMemoryLexicon(const [
  LexiconWord(id: 9300001, kanji: ['試語甲'], readings: ['しごこう'], pos: ['n']),
  LexiconWord(id: 9300002, kanji: ['試語乙'], readings: ['しごおつ'], pos: ['n']),
  LexiconWord(id: 9300003, kanji: ['試語丁'], readings: ['しごてい'], pos: ['n']),
  LexiconWord(
    id: 9300010,
    kanji: ['試語花'],
    readings: ['しごか'],
    pos: ['n'],
    priority: lexiconCommonMask,
  ),
  LexiconWord(id: 9300011, kanji: ['支語華'], readings: ['しごか'], pos: ['n']),
]);

const _senses = {
  '試語甲': ['시험 낱말', '시험어'],
  '試語乙': ['시험 낱말 둘'],
  '試語丁': ['시험 낱말 넷', '시험어 넷째'],
  '試語花': ['시험 꽃'],
  '支語華': ['지어 화'],
};

final class _Glossary implements KoreanGlossary {
  const _Glossary();

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => [
    for (final (i, text) in (_senses[headword] ?? const <String>[]).indexed)
      KoreanSense(words: [text], source: GlossarySource.krdict, senseNo: i + 1),
  ];

  @override
  List<GlossarySourceInfo> get sources => const [];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 400 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await waitFor(tester, finder);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Finder field(String name) => find.byKey(ValueKey('word-$name'));

  /// Types into a word field, then waits out the dictionary lookup.
  Future<void> type(WidgetTester tester, String name, String text) async {
    await tester.enterText(field(name), text);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  /// 試語帳 (甲·乙·丙, two of them studied) and 試語帳 2 (甲·丁).
  Future<String> seed(ShioriDatabase db) async {
    final library = DriftLibraryRepository(db);
    final service = LibraryService(
      library: library,
      clock: FixedClock(DateTime(2026, 11, 14, 9)),
    );
    CapturedEntry e(String h, String r, String m) => CapturedEntry(
      headword: h,
      readings: [r],
      pos: PartOfSpeech.noun,
      meaning: m,
    );
    final a = await service.addDraft(
      CaptureDraft(
        entries: [
          e('試語甲', 'しごこう', '시험 낱말 하나'),
          e('試語乙', 'しごおつ', '시험 낱말 둘'),
          e('試語丙', 'しごへい', '시험 낱말 셋'),
        ],
      ),
      to: const NewPlaylist('試語帳'),
    );
    await service.addDraft(
      CaptureDraft(
        entries: [e('試語甲', 'しごこう', '-'), e('試語丁', 'しごてい', '시험 낱말 넷')],
      ),
      to: const NewPlaylist('試語帳 2'),
    );
    final reviews = DriftReviewRepository(db);
    final words = await library.words(playlistId: a.playlist.id);
    for (final (w, level, mode) in [
      (words[0], 2, StudyMode.meaning),
      (words[0], 1, StudyMode.choice),
      (words[1], 3, StudyMode.meaning),
    ]) {
      await reviews.saveCard(
        ReviewCard(
          wordId: w.id,
          mode: mode,
          level: level,
          dueAt: DateTime.now().add(const Duration(days: 3)),
          lastReviewedAt: DateTime.now(),
          reviewCount: 1,
        ),
      );
    }
    return a.playlist.id;
  }

  Future<(ShioriDatabase, String)> start(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    final database = ShioriDatabase.memory();
    final listId = await seed(database);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          onboardingStoreProvider.overrideWithValue(InMemoryOnboardingStore()),
          lexiconProvider.overrideWithValue(_lexicon),
          koreanGlossaryProvider.overrideWithValue(const _Glossary()),
          wiktionaryGlossaryProvider.overrideWithValue(null),
        ],
        child: const ShioriApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await waitFor(tester, find.text('오늘'));
    return (database, listId);
  }

  Future<void> reset(WidgetTester tester, ShioriDatabase database) async {
    await tester.pumpWidget(const SizedBox());
    await database.close();
    tester.platformDispatcher.clearAllTestValues();
  }

  BuildContext homeContext(WidgetTester tester) =>
      tester.element(find.byType(Navigator).first);

  Future<void> openList(WidgetTester tester, String listId) async {
    unawaited(
      pushScreen<void>(homeContext(tester), PlaylistScreen(playlistId: listId)),
    );
    await waitFor(tester, find.text('試語丙'));
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester, String headword) async {
    await tester.tap(find.byTooltip('$headword 메뉴'));
    await tester.pumpAndSettle();
    await tapText(tester, '고치기');
  }

  testWidgets('단어 고치기·추가·찾기', (tester) async {
    // The playlist, the word sheet, the editor with suggestions.
    var (db, listId) = await start(tester);
    await openList(tester, listId);
    await shot(tester, '190_playlist_search_add');
    await tester.tap(find.text('試語甲'));
    await tester.pumpAndSettle();
    await shot(tester, '191_word_sheet');
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(TextButton, '고치기'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(field('meaning'), '내가 쓴 뜻');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 600));
    await tapText(tester, '사전에서 다시 찾기');
    await waitFor(tester, find.text('시험어'));
    await shot(tester, '192_word_editor_suggestions');
    await tester.tap(find.widgetWithText(TextButton, '취소').first);
    await tester.pumpAndSettle();

    // A headword another word has.
    await openEditor(tester, '試語丙');
    await tester.enterText(field('headword'), '試語乙');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await waitFor(tester, find.text('이미 저장한 단어예요'));
    await shot(tester, '193_word_taken_dialog');
    await tester.tap(find.text('취소').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '취소').first);
    await tester.pumpAndSettle();

    // 단어 추가: filled from the dictionary, kana, a stored word.
    await tapText(tester, '단어 추가');
    await tapText(tester, '직접 입력');
    await type(tester, 'headword', '試語花');
    await shot(tester, '194_word_add_filled');
    await type(tester, 'headword', 'しごか');
    await shot(tester, '195_word_add_kana');
    await type(tester, 'headword', '試語丁');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '196_word_add_stored');
    await tester.tap(find.widgetWithText(TextButton, '취소').first);
    await tester.pumpAndSettle();

    // 단어 찾기.
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), 'しご');
    await tester.pumpAndSettle();
    await tapText(tester, '모든 단어');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '197_word_search');
    await reset(tester, db);

    // No match, dark: from 재생목록 편집.
    (db, listId) = await start(tester, brightness: Brightness.dark);
    unawaited(pushScreen<void>(homeContext(tester), const PlaylistsScreen()));
    await waitFor(tester, find.text('재생목록 편집'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), '試語己');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '198_word_search_none_dark');
    await reset(tester, db);

    // The editor in large text.
    (db, listId) = await start(tester, textScale: 2);
    await openList(tester, listId);
    await tester.ensureVisible(find.byTooltip('試語甲 메뉴'));
    await tester.pumpAndSettle();
    await openEditor(tester, '試語甲');
    await tester.enterText(field('headword'), '試語戊');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '199_word_editor_large_text');
    await reset(tester, db);
  });
}
