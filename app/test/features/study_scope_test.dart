// Choosing what to study from the home screen: 전체 or one playlist.
// Synthetic sample words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  testWidgets('the sheet offers 전체 and each playlist with its counts', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final nature = await blocks.seedPage('s010', name: '자연');
    final travel = await blocks.seedPage('s140', name: '여행');
    final natureCount = (await blocks.library.words(
      playlistId: nature.id,
    )).length;
    final travelWords = await blocks.library.words(playlistId: travel.id);
    // Everything in 여행 is learned and not due.
    for (final w in travelWords) {
      await blocks.reviews.saveCard(
        ReviewCard(
          wordId: w.id,
          level: 4,
          dueAt: testNow.add(const Duration(days: 21)),
          lastReviewedAt: testNow,
        ),
      );
    }

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재생목록 골라 학습'));
    await tester.pumpAndSettle();

    expect(find.text('무엇을 학습할까요?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('scope-all')),
        matching: find.text('복습 0 · 새 단어 $natureCount'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey('scope-${nature.id}')),
        matching: find.text('복습 0 · 새 단어 $natureCount'),
      ),
      findsOneWidget,
    );
    final done = find.byKey(ValueKey('scope-${travel.id}'));
    expect(
      find.descendant(of: done, matching: find.text('오늘 할 것 없음')),
      findsOneWidget,
    );
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.byType(StudyScreen), findsNothing, reason: 'nothing to study');
  });

  testWidgets('picking a playlist studies its words only', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s010', name: '자연');
    final travel = await blocks.seedPage('s140', name: '여행');
    final words = await blocks.library.words(playlistId: travel.id);

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재생목록 골라 학습'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('scope-${travel.id}')));
    await tester.pumpAndSettle();

    final study = tester.widget<StudyScreen>(find.byType(StudyScreen));
    expect(study.scope, PlaylistOnly(travel.id));
    expect(find.text('0 / ${words.length}'), findsOneWidget);
    expect(find.text(words.first.headword), findsWidgets);
  });

  testWidgets('「오늘 학습 시작」 studies every playlist (전체)', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s140', name: '여행');
    await blocks.seedPage('s147', name: '쇼핑');

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();

    final study = tester.widget<StudyScreen>(find.byType(StudyScreen));
    expect(study.scope, const AllWords());
  });

  testWidgets('a hidden word is not counted in either scope', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final travel = await blocks.seedPage('s140', name: '여행');
    final words = await blocks.library.words(playlistId: travel.id);
    await LibraryService(
      library: blocks.library,
      clock: blocks.clock,
    ).hideWords([words.first.id]);

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재생목록 골라 학습'));
    await tester.pumpAndSettle();
    final left = '복습 0 · 새 단어 ${words.length - 1}';
    expect(find.text(left), findsNWidgets(2));
  });

  testWidgets('without playlists there is nothing to pick', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    expect(find.text('재생목록 골라 학습'), findsNothing);
  });
}
