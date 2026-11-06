// The playlist screen's ways to study learned words again: 처음부터 다시
// 학습 in a word's menu (with 되돌리기), and 더 학습하기 where the study button
// would be off. Synthetic sample words only.
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  ReviewCard waiting(String wordId, {int level = 2, int days = 3}) =>
      ReviewCard(
        wordId: wordId,
        level: level,
        dueAt: testNow.add(Duration(days: days)),
        lastReviewedAt: testNow.subtract(const Duration(days: 1)),
        reviewCount: 1,
      );

  Finder meter(int level) =>
      find.byWidgetPredicate((w) => w is MemoryMeter && w.level == level);

  Future<void> openMenu(WidgetTester tester, Word word) async {
    await tester.tap(find.byTooltip('${word.headword} 메뉴'));
    await tester.pumpAndSettle();
  }

  testWidgets('처음부터 다시 학습 turns a studied word into a new word, and '
      '되돌리기 brings its level back', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s010');
    final words = await blocks.library.words(playlistId: list.id);
    final first = words.first;
    final card = waiting(first.id, level: 4, days: 21);
    await blocks.reviews.saveCard(card);
    await blocks.reviews.addLog(
      ReviewLog(
        wordId: first.id,
        answer: Answer.known,
        at: testNow.subtract(const Duration(days: 1)),
        levelBefore: 0,
        levelAfter: 4,
        retriesInSession: 0,
      ),
    );

    await tester.pumpWidget(
      screen(blocks, PlaylistScreen(playlistId: list.id)),
    );
    await tester.pumpAndSettle();
    expect(meter(4), findsOneWidget);

    await openMenu(tester, first);
    await tester.tap(find.text('처음부터 다시 학습'));
    await tester.pumpAndSettle();

    expect(find.text('「${first.headword}」 새 단어로 돌렸어요'), findsOneWidget);
    expect(meter(4), findsNothing);
    expect(await blocks.reviews.card(first.id), isNull);
    expect(await blocks.reviews.logs(), hasLength(1), reason: 'log kept');

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();

    expect(await blocks.reviews.card(first.id), card);
    expect(meter(4), findsOneWidget);
  });

  testWidgets('a new word has no 처음부터 다시 학습', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s010');
    final words = await blocks.library.words(playlistId: list.id);
    await blocks.reviews.saveCard(waiting(words.first.id));

    await tester.pumpWidget(
      screen(blocks, PlaylistScreen(playlistId: list.id)),
    );
    await tester.pumpAndSettle();
    await openMenu(tester, words[1]);

    expect(find.text('이 목록에서 빼기'), findsOneWidget);
    expect(find.text('처음부터 다시 학습'), findsNothing);
  });

  testWidgets('every word waiting for its review: 더 학습하기 studies them now', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s140');
    final words = await blocks.library.words(playlistId: list.id);
    for (final (i, w) in words.indexed) {
      await blocks.reviews.saveCard(waiting(w.id, days: 3 + i));
    }

    await tester.pumpWidget(
      screen(blocks, PlaylistScreen(playlistId: list.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('지금은 학습할 카드가 없어요'), findsNothing);
    expect(find.text('이 목록 학습'), findsNothing);
    await tester.tap(find.text('더 학습하기'));
    await tester.pumpAndSettle();

    expect(find.text('0 / ${words.length}'), findsOneWidget);
    expect(find.text(words.first.headword), findsWidgets);
    expect(find.text('3일 후'), findsOneWidget, reason: 'time left');
  });

  testWidgets('nothing to bring forward: the study button stays off', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s140');
    final words = await blocks.library.words(playlistId: list.id);
    await blocks.reviews.saveCard(waiting(words.first.id));
    await LibraryService(
      library: blocks.library,
      clock: blocks.clock,
    ).hideWords([for (final w in words) w.id]);

    await tester.pumpWidget(
      screen(blocks, PlaylistScreen(playlistId: list.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('지금은 학습할 카드가 없어요'), findsOneWidget);
    expect(find.text('더 학습하기'), findsNothing);
  });
}
