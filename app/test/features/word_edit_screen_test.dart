// E7 단어 고치기 on the playlist screen: a word row opens the word sheet
// (its content, its playlists, the four modes' levels and 「고치기」); the
// editor saves into every playlist, cancels without a change, refuses a
// headword another word has (or puts the stored word in its places), only
// suggests the dictionary's meaning over a written one, offers 「학습 기록
// 처음부터」 only for a changed key of a studied word, and undoes. Made-up
// words.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';
import '../support/word_dictionary.dart';

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

  Future<void> openEditor(WidgetTester tester, Word word) async {
    await tester.ensureVisible(find.byTooltip('${word.headword} 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('${word.headword} 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고치기'));
    await tester.pumpAndSettle();
  }

  Finder field(String name) => find.byKey(ValueKey('word-$name'));

  String fieldText(WidgetTester tester, String name) =>
      tester.widget<TextField>(field(name)).controller!.text;

  /// Seeded inside each test body (the widget test's own zone).
  Future<void> seed() async {
    blocks = TestBlocks();
    (listA, listB) = await seedWordLists(blocks);
  }

  testWidgets('a row opens the word sheet: content, lists, levels, 고치기', (
    tester,
  ) async {
    await seed();
    final w = await storedWord(blocks, '試語甲');
    await blocks.reviews.saveCard(
      ReviewCard(
        wordId: w.id,
        level: 2,
        dueAt: testNow.add(const Duration(days: 3)),
        lastReviewedAt: testNow,
      ),
    );
    await open(tester, listA);

    await tester.tap(find.byKey(ValueKey('word-${w.id}')));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);
    expect(inSheet(find.text('試語甲')), findsOneWidget);
    expect(inSheet(find.text('しごこう')), findsOneWidget);
    expect(inSheet(find.text('시험 낱말 하나')), findsOneWidget);
    expect(inSheet(find.text('試語帳 · 試語帳 2')), findsOneWidget);
    expect(inSheet(find.byType(MemoryMeter)), findsNWidgets(4));
    expect(inSheet(find.widgetWithText(TextButton, '고치기')), findsOneWidget);

    await tester.tap(inSheet(find.widgetWithText(TextButton, '고치기')));
    await tester.pumpAndSettle();
    expect(find.text('단어 고치기'), findsOneWidget);
  });

  testWidgets('「고치기」 is the first item of a row\'s menu', (tester) async {
    await seed();
    await open(tester, listA);
    await tester.tap(find.byTooltip('試語甲 메뉴'));
    await tester.pumpAndSettle();
    final items = ['고치기', '이미 알아요', '이 목록에서 빼기', '다른 목록에 추가'];
    final tops = [for (final i in items) tester.getTopLeft(find.text(i)).dy];
    expect(tops, [...tops]..sort());
  });

  testWidgets('saving shows the change in every playlist; undo puts it back', (
    tester,
  ) async {
    await seed();
    final w = await storedWord(blocks, '試語甲');
    await open(tester, listA);
    await openEditor(tester, w);

    expect(fieldText(tester, 'headword'), '試語甲');
    expect(fieldText(tester, 'readings'), 'しごこう');
    expect(fieldText(tester, 'meaning'), '시험 낱말 하나');
    await tester.enterText(field('meaning'), '고친 뜻');
    await tester.enterText(field('readings'), 'しごこ');
    await tester.tap(find.widgetWithText(ChoiceChip, '동'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('단어 고치기'), findsNothing);
    expect(find.text('고친 뜻'), findsOneWidget);
    expect(find.text('「試語甲」 고쳤어요'), findsOneWidget);
    final saved = await blocks.library.word(w.id);
    expect((saved!.meaning, saved.pos), ('고친 뜻', PartOfSpeech.verb));
    expect(saved.readings, ['しごこ']);
    final inB = await blocks.library.words(playlistId: listB.id);
    expect(inB.firstWhere((x) => x.id == w.id).meaning, '고친 뜻');

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(await blocks.library.word(w.id), w);
    expect(find.text('시험 낱말 하나'), findsOneWidget);
  });

  testWidgets('취소 changes nothing', (tester) async {
    await seed();
    final w = await storedWord(blocks, '試語甲');
    await open(tester, listA);
    await openEditor(tester, w);
    await tester.enterText(field('meaning'), '버릴 뜻');
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();

    expect(find.text('단어 고치기'), findsNothing);
    expect(await blocks.library.word(w.id), w);
  });

  testWidgets('a blank meaning cannot be saved, and says why', (tester) async {
    await seed();
    final w = await storedWord(blocks, '試語甲');
    await open(tester, listA);
    await openEditor(tester, w);
    await tester.enterText(field('meaning'), ' ');
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '저장'))
          .onPressed,
      isNull,
    );
    expect(find.text('뜻을 써 주세요'), findsOneWidget);
  });

  group('a headword another word has', () {
    testWidgets('취소 in the dialog keeps the editor and the library', (
      tester,
    ) async {
      await seed();
      final w = await storedWord(blocks, '試語丙');
      await open(tester, listA);
      await openEditor(tester, w);
      await tester.enterText(field('headword'), '試語乙');
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('이미 저장한 단어예요'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '취소').last);
      await tester.pumpAndSettle();

      expect(find.text('이미 저장한 단어예요'), findsNothing);
      expect(find.text('단어 고치기'), findsOneWidget);
      expect(fieldText(tester, 'headword'), '試語乙');
      expect(await blocks.library.word(w.id), w);
    });

    testWidgets('저장된 단어로 바꾸기 puts the stored word in its places, undo', (
      tester,
    ) async {
      await seed();
      final w = await storedWord(blocks, '試語丁');
      final stored = await storedWord(blocks, '試語乙');
      await open(tester, listB);
      await openEditor(tester, w);
      await tester.enterText(field('headword'), '試語乙');
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장된 단어로 바꾸기'));
      await tester.pumpAndSettle();

      expect(find.text('단어 고치기'), findsNothing);
      expect(find.text('저장된 단어로 바꿨어요'), findsOneWidget);
      expect(
        [
          for (final x in await blocks.library.words(playlistId: listB.id))
            x.id,
        ],
        [(await storedWord(blocks, '試語甲')).id, stored.id],
      );
      expect(await blocks.library.word(w.id), w, reason: 'kept, unchanged');

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(
        [
          for (final x in await blocks.library.words(playlistId: listB.id))
            x.id,
        ],
        [(await storedWord(blocks, '試語甲')).id, w.id],
      );
    });
  });

  testWidgets('사전에서 다시 찾기 suggests; a written meaning is not replaced', (
    tester,
  ) async {
    await seed();
    final w = await storedWord(blocks, '試語甲');
    await open(tester, listA);
    await openEditor(tester, w);
    await tester.enterText(field('meaning'), '내가 쓴 뜻');
    await tester.tap(find.text('사전에서 다시 찾기'));
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'meaning'), '내가 쓴 뜻');
    expect(find.widgetWithText(ActionChip, '시험 낱말'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '시험어'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, '시험어'));
    await tester.pump();
    expect(fieldText(tester, 'meaning'), '시험어');
  });

  testWidgets('사전에서 다시 찾기 fills an empty meaning', (tester) async {
    await seed();
    final w = await storedWord(blocks, '試語甲');
    await open(tester, listA);
    await openEditor(tester, w);
    await tester.enterText(field('meaning'), '');
    await tester.tap(find.text('사전에서 다시 찾기'));
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'meaning'), '시험 낱말');
    expect(find.text('사전에서 채움'), findsOneWidget);
  });

  group('학습 기록 처음부터', () {
    Future<Word> studied() async {
      final w = await storedWord(blocks, '試語丙');
      for (final mode in StudyMode.values) {
        await blocks.reviews.saveCard(
          ReviewCard(
            wordId: w.id,
            mode: mode,
            level: 2,
            dueAt: testNow.add(const Duration(days: 3)),
            lastReviewedAt: testNow,
          ),
        );
      }
      return w;
    }

    const note = '표제어가 바뀌어요. 학습 기록은 그대로 남아요.';

    testWidgets('is offered only for a changed key of a studied word', (
      tester,
    ) async {
      await seed();
      final w = await studied();
      await open(tester, listA);
      await openEditor(tester, w);
      expect(find.text(note), findsNothing);

      await tester.enterText(field('headword'), '試語丙だ');
      await tester.pump();
      expect(find.text(note), findsNothing, reason: 'the same key');

      await tester.enterText(field('headword'), '試語戊');
      await tester.pump();
      expect(find.text(note), findsOneWidget);
      expect(find.text('학습 기록 처음부터'), findsOneWidget);
    });

    testWidgets('a new word key of a word never studied has no switch', (
      tester,
    ) async {
      await seed();
      final w = await storedWord(blocks, '試語丙');
      await open(tester, listA);
      await openEditor(tester, w);
      await tester.enterText(field('headword'), '試語戊');
      await tester.pump();
      expect(find.text('학습 기록 처음부터'), findsNothing);
    });

    testWidgets('off (the default): every card stays', (tester) async {
      await seed();
      final w = await studied();
      await open(tester, listA);
      await openEditor(tester, w);
      await tester.enterText(field('headword'), '試語戊');
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();

      expect((await blocks.library.word(w.id))!.headword, '試語戊');
      for (final mode in StudyMode.values) {
        expect(await blocks.reviews.card(w.id, mode: mode), isNotNull);
      }
    });

    testWidgets('on: every mode starts again, the log stays; undo restores', (
      tester,
    ) async {
      await seed();
      final w = await studied();
      await blocks.reviews.addLog(
        ReviewLog(
          wordId: w.id,
          answer: Answer.known,
          at: testNow,
          levelBefore: 1,
          levelAfter: 2,
          retriesInSession: 0,
        ),
      );
      await open(tester, listA);
      await openEditor(tester, w);
      await tester.enterText(field('headword'), '試語戊');
      await tester.pump();
      await tester.tap(find.text('학습 기록 처음부터'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();

      for (final mode in StudyMode.values) {
        expect(await blocks.reviews.card(w.id, mode: mode), isNull);
      }
      expect(await blocks.reviews.logs(), hasLength(1));

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect((await blocks.library.word(w.id))!.headword, '試語丙');
      for (final mode in StudyMode.values) {
        expect((await blocks.reviews.card(w.id, mode: mode))?.level, 2);
      }
    });
  });

  testWidgets('a hidden word opens from 숨긴 단어 and can be changed', (
    tester,
  ) async {
    await seed();
    final w = await storedWord(blocks, '試語乙');
    await (blocks.library as HiddenWordRepository).hideWords([
      w.id,
    ], at: testNow);
    await open(tester, listA);
    await tester.tap(find.text('숨긴 단어 1개 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('試語乙'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('되살리기')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: sheet,
        matching: find.widgetWithText(TextButton, '고치기'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(field('meaning'), '숨긴 채 고침');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    final after = await blocks.library.word(w.id);
    expect((after!.meaning, after.isHidden), ('숨긴 채 고침', true));
  });

  testWidgets('large text: the editor head stays one row, save reachable', (
    tester,
  ) async {
    await seed();
    final w = await storedWord(blocks, '試語甲');
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
    await openEditor(tester, w);

    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('단어 고치기'));
    final save = tester.getRect(find.widgetWithText(FilledButton, '저장'));
    expect((title.center.dy - save.center.dy).abs(), lessThan(title.height));
    await tester.enterText(field('meaning'), '큰 글자');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect((await blocks.library.word(w.id))!.meaning, '큰 글자');
  });

  testWidgets('VoiceOver: the editor\'s fields and buttons are labelled', (
    tester,
  ) async {
    await seed();
    final handle = tester.ensureSemantics();
    final w = await storedWord(blocks, '試語甲');
    await open(tester, listA);
    await openEditor(tester, w);

    for (final label in ['표제어', '읽기', '뜻']) {
      expect(
        find.bySemanticsLabel(RegExp('^$label')),
        findsWidgets,
        reason: label,
      );
    }
    expect(find.bySemanticsLabel('저장'), findsOneWidget);
    expect(find.bySemanticsLabel('취소'), findsOneWidget);
    handle.dispose();
  });
}
