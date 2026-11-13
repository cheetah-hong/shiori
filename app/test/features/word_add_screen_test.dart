// E7 단어 추가: the playlist's bottom bar offers 「단어 추가」 (직접 입력 /
// 사진으로 / 기본 단어장). Typing a headword fills its empty fields from the
// dictionary; a word the library has is linked into the list, never made
// twice; a headword in kana offers kanji spellings; a word no dictionary
// knows is added by hand; the target playlist can be changed. Made-up words.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/decks/deck_data.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';
import '../support/word_dictionary.dart';

/// Past the pause after typing that starts the dictionary lookup.
const _lookupPause = Duration(milliseconds: 400);

void main() {
  late TestBlocks blocks;
  late Playlist listA;
  late Playlist listB;

  Future<void> open(WidgetTester tester, Playlist list) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      screen(
        blocks,
        PlaylistScreen(playlistId: list.id),
        extra: wordDictionaryOverrides,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAdder(WidgetTester tester) async {
    await tester.tap(find.text('단어 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 입력'));
    await tester.pumpAndSettle();
  }

  Finder field(String name) => find.byKey(ValueKey('word-$name'));

  String fieldText(WidgetTester tester, String name) =>
      tester.widget<TextField>(field(name)).controller!.text;

  Future<void> typeHeadword(WidgetTester tester, String text) async {
    await tester.enterText(field('headword'), text);
    await tester.pump(_lookupPause);
    await tester.pumpAndSettle();
  }

  Finder addButton(String label) => find.widgetWithText(FilledButton, label);

  /// Seeded inside each test body (the widget test's own zone).
  Future<void> seed() async {
    blocks = TestBlocks();
    (listA, listB) = await seedWordLists(blocks);
  }

  testWidgets('「단어 추가」 offers 직접 입력, 사진으로, 기본 단어장', (tester) async {
    await seed();
    await open(tester, listA);
    await tester.tap(find.text('단어 추가'));
    await tester.pumpAndSettle();
    expect(find.text('직접 입력'), findsOneWidget);
    expect(find.text('사진으로'), findsOneWidget);
    expect(find.text('기본 단어장'), findsOneWidget);

    await tester.tap(find.text('사진으로'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '페이지 등록'), findsOneWidget);
  });

  testWidgets('기본 단어장 opens the decks', (tester) async {
    await seed();
    usePhoneSize(tester);
    // The deck file is built outside git: whether this checkout has it must
    // not change the test (without it the screen loads at once).
    await tester.pumpWidget(
      screen(
        blocks,
        PlaylistScreen(playlistId: listA.id),
        extra: [
          ...wordDictionaryOverrides,
          builtinDecksProvider.overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('단어 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기본 단어장'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '기본 단어장'), findsOneWidget);
  });

  testWidgets('a headword fills its empty fields; 추가 puts it in the list', (
    tester,
  ) async {
    await seed();
    await open(tester, listA);
    await openAdder(tester);
    expect(find.text('단어 추가'), findsWidgets);
    expect(find.text('試語帳'), findsWidgets, reason: 'the list it opened from');

    // A word not stored yet but in the dictionary.
    await typeHeadword(tester, '試語花');
    expect(fieldText(tester, 'readings'), 'しごか');
    expect(fieldText(tester, 'meaning'), '시험 꽃');
    expect(find.text('사전에서 채움'), findsWidgets);

    await tester.tap(addButton('추가'));
    await tester.pumpAndSettle();

    expect(find.text("'試語帳'에 단어 1개 추가"), findsOneWidget);
    final added = await storedWord(blocks, '試語花');
    expect((added.pos, added.meaning), (PartOfSpeech.noun, '시험 꽃'));
    expect(added.readings, ['しごか']);
    expect(
      (await blocks.library.words(playlistId: listA.id)).last.id,
      added.id,
    );
    expect(find.text('시험 꽃'), findsOneWidget, reason: 'the row shows it');
  });

  testWidgets('a field typed before the lookup is not replaced', (
    tester,
  ) async {
    await seed();
    await open(tester, listA);
    await openAdder(tester);
    await tester.enterText(field('meaning'), '내 뜻');
    await typeHeadword(tester, '試語花');
    expect(fieldText(tester, 'meaning'), '내 뜻');
    expect(fieldText(tester, 'readings'), 'しごか');
    expect(find.widgetWithText(ActionChip, '시험 꽃'), findsOneWidget);
  });

  testWidgets('a stored word is linked into the list, not made again', (
    tester,
  ) async {
    await seed();
    final stored = await storedWord(blocks, '試語丁');
    final before = (await blocks.library.words()).length;
    await open(tester, listA);
    await openAdder(tester);
    await typeHeadword(tester, '試語丁');

    expect(find.text('이미 저장한 단어예요'), findsOneWidget);
    expect(find.text('시험 낱말 넷'), findsOneWidget);
    expect(find.textContaining('試語帳 2'), findsWidgets);
    await tester.tap(addButton('이 목록에 넣기'));
    await tester.pumpAndSettle();

    expect((await blocks.library.words()).length, before);
    expect(
      (await blocks.library.words(playlistId: listA.id)).last.id,
      stored.id,
    );
  });

  testWidgets('a word the list holds already says so, with nothing to press', (
    tester,
  ) async {
    await seed();
    await open(tester, listA);
    await openAdder(tester);
    await typeHeadword(tester, '試語甲だ');

    expect(find.text('이미 이 목록에 있어요'), findsOneWidget);
    expect(addButton('이 목록에 넣기'), findsNothing);
    expect(addButton('추가'), findsNothing);
  });

  testWidgets('a headword in kana offers kanji spellings', (tester) async {
    await seed();
    await open(tester, listA);
    await openAdder(tester);
    await typeHeadword(tester, 'しごか');

    expect(find.text('한자 표기'), findsOneWidget);
    final first = find.ancestor(
      of: find.text('試語花'),
      matching: find.byType(ActionChip),
    );
    expect(first, findsOneWidget);
    expect(
      find.descendant(of: first, matching: find.byType(JpText)),
      findsWidgets,
      reason: 'read in Japanese',
    );
    expect(
      tester.getTopLeft(first).dx,
      lessThan(
        tester
            .getTopLeft(
              find.ancestor(
                of: find.text('支語華'),
                matching: find.byType(ActionChip),
              ),
            )
            .dx,
      ),
    );

    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'headword'), '試語花');
    expect(fieldText(tester, 'readings'), 'しごか');
    expect(fieldText(tester, 'meaning'), '시험 꽃');
  });

  testWidgets('kept in kana, it is added without readings', (tester) async {
    await seed();
    await open(tester, listA);
    await openAdder(tester);
    await typeHeadword(tester, 'しごか');
    expect(fieldText(tester, 'readings'), isEmpty);
    await tester.tap(addButton('추가'));
    await tester.pumpAndSettle();

    final added = await storedWord(blocks, 'しごか');
    expect(added.readings, isEmpty);
    expect(added.meaning, '시험 꽃');
  });

  testWidgets('a word no dictionary knows is added by hand', (tester) async {
    await seed();
    await open(tester, listA);
    await openAdder(tester);
    await typeHeadword(tester, '試語戊');

    expect(find.text('사전에 없는 낱말이에요. 읽기와 뜻을 직접 써 주세요'), findsOneWidget);
    expect(find.text('뜻을 써 주세요'), findsOneWidget);
    expect(tester.widget<FilledButton>(addButton('추가')).onPressed, isNull);

    await tester.enterText(field('readings'), 'しごぼ');
    await tester.enterText(field('meaning'), '손으로 쓴 뜻');
    await tester.pump();
    await tester.tap(addButton('추가'));
    await tester.pumpAndSettle();

    final added = await storedWord(blocks, '試語戊');
    expect(added.readings, ['しごぼ']);
    expect(added.meaning, '손으로 쓴 뜻');
  });

  testWidgets('a headword without kana or kanji says how to write it', (
    tester,
  ) async {
    await seed();
    await open(tester, listA);
    await openAdder(tester);
    await typeHeadword(tester, 'abc');
    expect(find.text('표제어는 가나나 한자로 써 주세요'), findsOneWidget);
    expect(tester.widget<FilledButton>(addButton('추가')).onPressed, isNull);
  });

  testWidgets('the target playlist can be changed', (tester) async {
    await seed();
    await open(tester, listA);
    await openAdder(tester);
    await typeHeadword(tester, '試語花');
    await tester.tap(find.text('넣을 재생목록'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('pick-${listB.id}')));
    await tester.pumpAndSettle();
    await tester.tap(addButton('추가'));
    await tester.pumpAndSettle();

    final added = await storedWord(blocks, '試語花');
    expect(
      (await blocks.library.words(playlistId: listB.id)).last.id,
      added.id,
    );
    expect(await blocks.library.playlistsOf([added.id]), {
      added.id: {listB.id},
    });
  });

  testWidgets('취소 adds nothing', (tester) async {
    await seed();
    final before = await blocks.library.words();
    await open(tester, listA);
    await openAdder(tester);
    await typeHeadword(tester, '試語花');
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();
    expect(await blocks.library.words(), before);
  });

  testWidgets('an empty playlist: 「단어 추가」 is its one button', (tester) async {
    await seed();
    await blocks.library.savePlaylist(
      Playlist(id: 'e', name: '빈 목록', createdAt: testNow, position: 9),
    );
    usePhoneSize(tester);
    await tester.pumpWidget(
      screen(
        blocks,
        const PlaylistScreen(playlistId: 'e'),
        extra: wordDictionaryOverrides,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('단어 추가'), findsOneWidget);
    expect(find.text('페이지 등록'), findsNothing);

    await openAdder(tester);
    await typeHeadword(tester, '試語花');
    await tester.tap(addButton('추가'));
    await tester.pumpAndSettle();
    expect(
      (await blocks.library.words(playlistId: 'e')).single.headword,
      '試語花',
    );
  });

  testWidgets('large text: the adder fits and adds', (tester) async {
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
    await openAdder(tester);
    await typeHeadword(tester, 'しごか');
    expect(tester.takeException(), isNull);
    await tester.tap(addButton('추가'));
    await tester.pumpAndSettle();
    expect(await storedWord(blocks, 'しごか'), isA<Word>());
  });
}
