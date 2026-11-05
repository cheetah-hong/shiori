import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/textbook_screen.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  testWidgets('groups words by DAY and shows each memory level', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final textbook = await blocks.seedPage('s010');
    await blocks.seedPage('s140');
    final first = (await blocks.library.words()).first;
    await blocks.reviews.saveCard(
      ReviewCard(
        wordId: first.id,
        level: 4,
        dueAt: testNow,
        lastReviewedAt: testNow,
      ),
    );

    await tester.pumpWidget(
      screen(blocks, TextbookScreen(textbookId: textbook.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('JLPT 단어장'), findsOneWidget);
    expect(find.text('DAY 01  자연, 몸'), findsOneWidget);
    expect(
      find.text('1'),
      findsWidgets,
      reason: 'one word in long-term memory',
    );
    expect(
      find.byWidgetPredicate((w) => w is MemoryMeter && w.level == 4),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(find.text('DAY 20  여행·교통'), 300);
    expect(find.text('DAY 20  여행·교통'), findsOneWidget);
  });

  testWidgets(
    'the study button is off when nothing in the book is due or new',
    (tester) async {
      usePhoneSize(tester);
      final blocks = TestBlocks();
      final textbook = await blocks.seedPage('s147');
      for (final w in await blocks.library.words()) {
        await blocks.reviews.saveCard(
          ReviewCard(
            wordId: w.id,
            level: 4,
            dueAt: testNow.add(const Duration(days: 21)),
            lastReviewedAt: testNow,
          ),
        );
      }
      await tester.pumpWidget(
        screen(blocks, TextbookScreen(textbookId: textbook.id)),
      );
      await tester.pumpAndSettle();
      expect(find.text('지금은 학습할 카드가 없어요'), findsOneWidget);
    },
  );
}
