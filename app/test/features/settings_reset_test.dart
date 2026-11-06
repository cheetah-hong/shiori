// 설정 → 학습 기록: making every word new again, only after a confirmation.
// The press log, hidden words and playlists stay. Synthetic sample words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/settings/settings_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  const rowTitle = '모든 단어 처음부터 다시 학습';

  ListTile row(WidgetTester tester) => tester.widget<ListTile>(
    find.ancestor(of: find.text(rowTitle), matching: find.byType(ListTile)),
  );

  /// Two learned words of sample page s010 and one press.
  Future<void> seedLearned(TestBlocks blocks) async {
    final list = await blocks.seedPage('s010');
    final words = await blocks.library.words(playlistId: list.id);
    for (final w in words.take(2)) {
      await blocks.reviews.saveCard(
        ReviewCard(
          wordId: w.id,
          level: 3,
          dueAt: testNow.add(const Duration(days: 7)),
          lastReviewedAt: testNow,
          reviewCount: 2,
        ),
      );
    }
    await blocks.reviews.addLog(
      ReviewLog(
        wordId: words.first.id,
        answer: Answer.known,
        at: testNow,
        levelBefore: 2,
        levelAfter: 3,
        retriesInSession: 0,
      ),
    );
  }

  testWidgets('no word learned yet: the row is off', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(row(tester).enabled, isFalse);
    expect(find.text('아직 학습한 단어가 없어요'), findsOneWidget);
  });

  testWidgets('asks first; 취소 changes nothing', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedLearned(blocks);
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(row(tester).enabled, isTrue);

    await tester.tap(find.text(rowTitle));
    await tester.pumpAndSettle();
    expect(find.text('모든 단어를 처음부터 다시 학습할까요?'), findsOneWidget);
    expect(find.textContaining('학습한 단어 2개'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(await blocks.reviews.cards(), hasLength(2));
  });

  testWidgets('처음부터 makes every word new and keeps the press log', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedLearned(blocks);
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(rowTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('처음부터'));
    await tester.pumpAndSettle();

    expect(await blocks.reviews.cards(), isEmpty);
    expect(await blocks.reviews.logs(), hasLength(1));
    expect(await blocks.library.words(), hasLength(12));
    expect(find.text('단어 2개를 새 단어로 돌렸어요'), findsOneWidget);
    expect(row(tester).enabled, isFalse);
  });
}
