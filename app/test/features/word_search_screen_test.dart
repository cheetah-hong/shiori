// E7 단어 찾기: the magnifier on the playlist screen and on 재생목록 편집
// opens it. Kana finds kanji headwords by reading, Korean finds by meaning;
// from a playlist the segment narrows to it (이 목록) or not (모든 단어);
// hidden words say 숨김; no match offers 직접 추가 with the query; a result
// opens the word sheet, and a change shows in the results. Made-up words.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/features/playlists/playlists_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';
import '../support/word_dictionary.dart';

void main() {
  late TestBlocks blocks;
  late Playlist listA;

  Future<void> pumpScreen(WidgetTester tester, Widget child) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      screen(blocks, child, extra: wordDictionaryOverrides),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(CupertinoSearchTextField), query);
    await tester.pumpAndSettle();
  }

  /// Result rows' headwords, top to bottom.
  List<String> results(WidgetTester tester) {
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('found-'),
    );
    final words = [
      for (final e in rows.evaluate())
        (
          (e.widget.key! as ValueKey<String>).value.substring(6),
          tester.getTopLeft(find.byWidget(e.widget)).dy,
        ),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final (head, _) in words) head];
  }

  /// Seeded inside each test body (the widget test's own zone).
  Future<void> seed() async {
    blocks = TestBlocks();
    (listA, _) = await seedWordLists(blocks);
  }

  testWidgets('from a playlist: 이 목록 first, then 모든 단어', (tester) async {
    await seed();
    await pumpScreen(tester, PlaylistScreen(playlistId: listA.id));
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '단어 찾기'), findsOneWidget);
    expect(find.text('이 목록'), findsOneWidget);
    expect(find.text('모든 단어'), findsOneWidget);
    await search(tester, 'しご');
    expect(results(tester), ['試語甲', '試語乙', '試語丙']);
    expect(find.text('3개'), findsOneWidget);

    await tester.tap(find.text('모든 단어'));
    await tester.pumpAndSettle();
    expect(results(tester), ['試語甲', '試語乙', '試語丙', '試語丁']);
    expect(find.text('4개'), findsOneWidget);
  });

  testWidgets('from 재생목록 편집: every word, no segment', (tester) async {
    await seed();
    await pumpScreen(tester, const PlaylistsScreen());
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();

    expect(find.text('이 목록'), findsNothing);
    await search(tester, '試語丁');
    expect(results(tester), ['試語丁']);
  });

  testWidgets('kanji, katakana and a Korean meaning', (tester) async {
    await seed();
    await pumpScreen(tester, const PlaylistsScreen());
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();

    await search(tester, '試語乙');
    expect(results(tester), ['試語乙']);
    await search(tester, 'シゴヘイ');
    expect(results(tester), ['試語丙']);
    await search(tester, '낱말 넷');
    expect(results(tester), ['試語丁']);
  });

  testWidgets('a hidden word is found and says 숨김', (tester) async {
    await seed();
    final w = await storedWord(blocks, '試語乙');
    await (blocks.library as HiddenWordRepository).hideWords([
      w.id,
    ], at: testNow);
    await pumpScreen(tester, const PlaylistsScreen());
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();
    await search(tester, '試語乙');

    expect(results(tester), ['試語乙']);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('found-試語乙')),
        matching: find.text('숨김'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no match: 직접 추가 opens the adder with the query', (tester) async {
    await seed();
    await pumpScreen(tester, PlaylistScreen(playlistId: listA.id));
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();
    await search(tester, '試語己');

    expect(results(tester), isEmpty);
    expect(find.text('저장한 단어 중에 없어요'), findsOneWidget);
    await tester.tap(find.text('직접 추가'));
    await tester.pumpAndSettle();

    expect(find.text('단어 추가'), findsWidgets);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('word-headword')))
          .controller!
          .text,
      '試語己',
    );
  });

  testWidgets('a blank query lists nothing', (tester) async {
    await seed();
    await pumpScreen(tester, const PlaylistsScreen());
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();
    expect(results(tester), isEmpty);
    expect(find.text('저장한 단어 중에 없어요'), findsNothing);
  });

  testWidgets('a result opens the word sheet; a change shows in the results', (
    tester,
  ) async {
    await seed();
    await pumpScreen(tester, const PlaylistsScreen());
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();
    await search(tester, '試語丙');
    await tester.tap(find.byKey(const ValueKey('found-試語丙')));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    await tester.tap(
      find.descendant(
        of: sheet,
        matching: find.widgetWithText(TextButton, '고치기'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('word-meaning')),
      '찾아서 고침',
    );
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('found-試語丙')),
        matching: find.text('찾아서 고침'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('large text: results and the segment fit', (tester) async {
    await seed();
    usePhoneSize(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      screen(
        blocks,
        PlaylistScreen(playlistId: listA.id),
        extra: wordDictionaryOverrides,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();
    await search(tester, 'しご');
    expect(tester.takeException(), isNull);
    expect(results(tester), isNotEmpty);
  });

  testWidgets('VoiceOver: the magnifier and the segment are labelled', (
    tester,
  ) async {
    await seed();
    final handle = tester.ensureSemantics();
    await pumpScreen(tester, PlaylistScreen(playlistId: listA.id));
    expect(find.bySemanticsLabel('단어 찾기'), findsOneWidget);
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('이 목록')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('모든 단어')), findsWidgets);
    handle.dispose();
  });
}
