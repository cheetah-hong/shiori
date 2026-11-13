import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  testWidgets('new cards: preview, retry to the back, reveal, finish', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s140'); // 6 entry-layout words with examples
    await tester.pumpWidget(
      app(
        blocks,
        extra: [
          studySettingsProvider.overrideWithValue(
            const StudySettings(dailyGoal: 3),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('오늘 학습 시작 · 3장'), findsOneWidget);

    await tester.tap(find.text('오늘 학습 시작 · 3장'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 3'), findsOneWidget);
    expect(find.text('새 단어'), findsOneWidget);
    expect(find.text('21일 후'), findsOneWidget);
    expect(find.bySemanticsLabel('뜻 가림'), findsOneWidget);

    await tester.tap(find.text('뜻 보기'));
    await tester.pumpAndSettle();
    expect(find.text('뜻 가리기'), findsOneWidget);

    // 다시 학습: progress stays, the card comes back later marked 다시 1.
    await tester.tap(find.text('다시 학습'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 3'), findsOneWidget);
    expect(
      find.bySemanticsLabel('뜻 가림'),
      findsOneWidget,
      reason: 'the next card starts covered',
    );

    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('다시 1'), findsOneWidget);
    expect(find.text('3일 후'), findsOneWidget, reason: 'one retry → level 2');

    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 학습 끝'), findsOneWidget);
    expect(find.text('3개'), findsOneWidget, reason: '3 new words learned');
    expect(find.text('1번'), findsOneWidget, reason: 'one retry');

    final cards = await blocks.reviews.cards();
    expect(cards.values.map((c) => c.level).toList()..sort(), [2, 4, 4]);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 3개 외움'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a due review card shows its level and comes first', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s010');
    final words = await blocks.library.words();
    await blocks.reviews.saveCard(
      ReviewCard(
        wordId: words[5].id,
        level: 2,
        dueAt: testNow.subtract(const Duration(hours: 1)),
        lastReviewedAt: testNow.subtract(const Duration(days: 3)),
      ),
    );
    await tester.pumpWidget(screen(blocks, const StudyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('복습 2단계'), findsOneWidget);
    expect(find.text('7일 후'), findsOneWidget);
  });

  testWidgets(
    'nothing due and no new words: explains instead of an empty card',
    (tester) async {
      usePhoneSize(tester);
      final blocks = TestBlocks();
      await tester.pumpWidget(screen(blocks, const StudyScreen()));
      await tester.pumpAndSettle();
      expect(find.text('지금 학습할 카드가 없어요'), findsOneWidget);
    },
  );

  testWidgets(
    'a summary that fails to load is shown as an error, not as zero',
    (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        app(
          TestBlocks(),
          extra: [
            homeSummaryProvider.overrideWith(
              (ref) => Future.error(Exception('db')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('오늘 학습할 단어를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('지금은 복습할 단어가 없어요'), findsNothing);
    },
  );
}
