// 더 학습하기 on the study screen and on home: cards whose review time has
// not come are studied now; 알고있음 leaves them as they were. Synthetic
// sample words only.
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  /// Every word of sample page [fixture] learned, the next review [days]
  /// days away (the first word soonest).
  Future<List<Word>> allWaiting(TestBlocks blocks, String fixture) async {
    final list = await blocks.seedPage(fixture);
    final words = await blocks.library.words(playlistId: list.id);
    for (final (i, w) in words.indexed) {
      await blocks.reviews.saveCard(
        ReviewCard(
          wordId: w.id,
          level: 2,
          dueAt: testNow.add(Duration(days: 3 + i)),
          lastReviewedAt: testNow.subtract(const Duration(days: 1)),
          reviewCount: 1,
        ),
      );
    }
    return words;
  }

  testWidgets('「지금 학습할 카드가 없어요」 offers 더 학습하기, and 알고있음 keeps '
      'the card', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await allWaiting(blocks, 's140');
    final first = await blocks.reviews.card(words.first.id);

    await tester.pumpWidget(screen(blocks, const StudyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('지금 학습할 카드가 없어요'), findsOneWidget);

    await tester.tap(find.text('더 학습하기'));
    await tester.pumpAndSettle();

    expect(find.text('지금 학습할 카드가 없어요'), findsNothing);
    expect(find.text('0 / ${words.length}'), findsOneWidget);
    expect(find.text('더 학습하기'), findsOneWidget, reason: 'the header');
    expect(find.text('3일 후'), findsOneWidget, reason: 'time left');

    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();

    expect(find.text('1 / ${words.length}'), findsOneWidget);
    expect(await blocks.reviews.card(words.first.id), first);
    expect((await blocks.reviews.logs()).single.answer, Answer.known);
  });

  testWidgets('다시 학습 in 더 학습하기 sends the card back to level 1', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await allWaiting(blocks, 's147');

    await tester.pumpWidget(
      screen(blocks, const StudyScreen(scope: AllWords(), more: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 학습'));
    await tester.pumpAndSettle();

    final card = await blocks.reviews.card(words.first.id);
    expect(card?.level, 1);
    expect(card?.dueAt, testNow);
    expect(card?.lapseCount, 1);
  });

  testWidgets('nothing to bring forward: no 더 학습하기', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(screen(blocks, const StudyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('지금 학습할 카드가 없어요'), findsOneWidget);
    expect(find.text('더 학습하기'), findsNothing);
  });

  testWidgets('「오늘 학습 끝」 offers 더 학습하기 for the words just learned', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s140');
    await tester.pumpWidget(
      screen(
        blocks,
        const StudyScreen(),
        extra: [
          studySettingsProvider.overrideWithValue(
            const StudySettings(dailyGoal: 2),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('알고있음'));
      await tester.pumpAndSettle();
    }
    expect(find.text('오늘 학습 끝'), findsOneWidget);

    await tester.tap(find.text('더 학습하기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 학습 끝'), findsNothing);
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.text('21일 후'), findsOneWidget, reason: 'time left');
  });

  testWidgets('home: 더 학습하기 in place of the study button when nothing is '
      'due', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await allWaiting(blocks, 's140');

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    expect(find.text('지금은 복습할 단어가 없어요'), findsNothing);
    await tester.tap(find.text('더 학습하기'));
    await tester.pumpAndSettle();

    expect(find.text('0 / ${words.length}'), findsOneWidget);
  });

  testWidgets('home: every learned word hidden, the button stays off', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await allWaiting(blocks, 's140');
    await LibraryService(
      library: blocks.library,
      clock: blocks.clock,
    ).hideWords([for (final w in words) w.id]);

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    expect(find.text('지금은 복습할 단어가 없어요'), findsOneWidget);
    expect(find.text('더 학습하기'), findsNothing);
  });

  testWidgets('a finished 더 학습하기 session starts a new one on 더 학습하기', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await allWaiting(blocks, 's147');

    await tester.pumpWidget(
      screen(blocks, const StudyScreen(scope: AllWords(), more: true)),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < words.length; i++) {
      await tester.tap(find.text('알고있음'));
      await tester.pumpAndSettle();
    }
    expect(find.text('오늘 학습 끝'), findsOneWidget);

    await tester.tap(find.text('더 학습하기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 학습 끝'), findsNothing);
    expect(find.text('0 / ${words.length}'), findsOneWidget);
  });
}
