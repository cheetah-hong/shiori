// 이미 알아요 on the study card: the card goes away, the next one comes up,
// 되돌리기 brings the word back. The 알고있음 answer button is unchanged.
// Synthetic sample pages only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  testWidgets('이미 알아요 hides the card, the next one comes up, 되돌리기 '
      'brings it back', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s140'); // 6 entry-layout words
    final words = await blocks.library.words();
    final first = words[0], second = words[1];

    await tester.pumpWidget(screen(blocks, const StudyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('0 / 6'), findsOneWidget);
    expect(find.text(first.headword), findsOneWidget);

    await tester.tap(find.text(HideLabels.button));
    await tester.pumpAndSettle();
    expect(find.text(first.headword), findsNothing);
    expect(find.text(second.headword), findsOneWidget);
    expect(find.text('0 / 5'), findsOneWidget);
    expect(find.text(HideLabels.hidden(first.headword)), findsOneWidget);
    expect((await blocks.library.word(first.id))?.isHidden, isTrue);
    expect(await blocks.reviews.cards(), isEmpty);
    expect(await blocks.reviews.logs(), isEmpty);

    await tester.tap(find.text(HideLabels.undo));
    await tester.pumpAndSettle();
    expect(find.text(first.headword), findsOneWidget);
    expect(find.text('0 / 6'), findsOneWidget);
    expect(find.text(HideLabels.hidden(first.headword)), findsNothing);
    expect((await blocks.library.word(first.id))?.isHidden, isFalse);
  });

  testWidgets('알고있음 still schedules the card; the two buttons read '
      'differently', (tester) async {
    usePhoneSize(tester);
    final semantics = tester.ensureSemantics();
    final blocks = TestBlocks();
    await blocks.seedPage('s140');
    final first = (await blocks.library.words()).first;

    await tester.pumpWidget(screen(blocks, const StudyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('알고있음'), findsOneWidget);
    expect(find.text('21일 후'), findsOneWidget);
    expect(find.text('다시 학습'), findsOneWidget);
    expect(find.bySemanticsLabel('알고있음, 다음 복습 21일 후'), findsOneWidget);
    expect(find.bySemanticsLabel(HideLabels.buttonSemantics), findsOneWidget);
    expect(HideLabels.buttonSemantics, isNot(contains('알고있음')));
    expect(HideLabels.button, isNot('알고있음'));

    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 6'), findsOneWidget);
    final card = await blocks.reviews.card(first.id);
    expect(card?.level, 4);
    expect((await blocks.library.word(first.id))?.isHidden, isFalse);
    expect(find.text(HideLabels.undo), findsNothing);
    semantics.dispose();
  });

  testWidgets('hiding the last card ends the session; 되돌리기 reopens it', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s140');
    final words = await blocks.library.words();
    await tester.pumpWidget(
      app(
        blocks,
        extra: [
          studySettingsProvider.overrideWithValue(
            const StudySettings(dailyGoal: 2),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 학습 시작 · 2장'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(HideLabels.button));
    await tester.pumpAndSettle();
    expect(find.text('오늘 학습 끝'), findsOneWidget);
    expect((await blocks.library.word(words[1].id))?.isHidden, isTrue);

    await tester.tap(find.text(HideLabels.undo));
    await tester.pumpAndSettle();
    expect(find.text(words[1].headword), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect((await blocks.library.word(words[1].id))?.isHidden, isFalse);
  });

  testWidgets('a hide that fails says so and keeps the card', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s140');
    final first = (await blocks.library.words()).first;
    await tester.pumpWidget(
      app(
        blocks,
        extra: [
          studyServiceProvider.overrideWith(
            (ref) => StudyService(
              library: blocks.library,
              reviews: blocks.reviews,
              scheduler: const LeitnerFourStepScheduler(),
              clock: blocks.clock,
              hidden: _FailingHide(),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(HideLabels.button));
    await tester.pumpAndSettle();
    expect(find.text(HideLabels.hideFailed), findsOneWidget);
    expect(find.text(first.headword), findsOneWidget);
    expect(find.text('0 / 6'), findsOneWidget);
    expect((await blocks.library.word(first.id))?.isHidden, isFalse);
    expect(find.byType(FilledButton), findsWidgets, reason: 'still studying');
  });
}

final class _FailingHide implements HiddenWordRepository {
  @override
  Future<void> hideWords(Iterable<String> wordIds, {required DateTime at}) =>
      Future.error(Exception('disk full'));

  @override
  Future<void> unhideWords(Iterable<String> wordIds) =>
      Future.error(Exception('disk full'));

  @override
  Future<List<Word>> hiddenWords({String? textbookId}) async => const [];
}
