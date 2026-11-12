// 홈 as a day sheet (日めくり): today's date as the head, today's numbers as
// memo rows that add up to the session size, the week strip with the run
// of study days, the study mode as one pop-up row, and 페이지 등록 with the
// start button fixed at the bottom. Made-up words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/design.dart';
import '../support/harness.dart';

/// [count] made-up words in playlist 「모음」, oldest first.
Future<List<Word>> _seed(TestBlocks blocks, int count) async {
  final result =
      await LibraryService(
        library: blocks.library,
        clock: blocks.clock,
      ).addDraft(
        CaptureDraft(
          entries: [
            for (var i = 0; i < count; i++)
              CapturedEntry(
                headword: '語$i',
                readings: ['ご$i'],
                pos: PartOfSpeech.noun,
                meaning: '말 $i',
              ),
          ],
        ),
        to: const NewPlaylist('모음'),
      );
  return blocks.library.words(playlistId: result.playlist.id);
}

/// A card of [wordId] due an hour ago.
ReviewCard _due(String wordId) => ReviewCard(
  wordId: wordId,
  level: 1,
  dueAt: testNow.subtract(const Duration(hours: 1)),
  lastReviewedAt: testNow.subtract(const Duration(days: 3)),
  reviewCount: 1,
);

ReviewLog _answered(String wordId, DateTime at) => ReviewLog(
  wordId: wordId,
  answer: Answer.known,
  at: at,
  levelBefore: 0,
  levelAfter: 1,
  retriesInSession: 0,
);

Future<void> _pump(WidgetTester tester, TestBlocks blocks) async {
  usePhoneSize(tester);
  await tester.pumpWidget(app(blocks, extra: designBlocks()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the head is today\'s date: day, month, weekday', (tester) async {
    final blocks = TestBlocks();
    await _seed(blocks, 3);
    await _pump(tester, blocks);

    // Thursday 5 November 2026.
    expect(find.text('5'), findsWidgets);
    expect(find.text('11월'), findsOneWidget);
    expect(find.text('목요일'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('11월 5일 목요일')), findsOneWidget);
  });

  testWidgets('memo rows add up to the session: reviews first, then new', (
    tester,
  ) async {
    final blocks = TestBlocks();
    final words = await _seed(blocks, 15);
    for (final w in words.take(2)) {
      await blocks.reviews.saveCard(_due(w.id));
    }
    await blocks.preferences.save(
      const StudyPreferences(dailyGoal: DailyGoal.ten),
    );
    await _pump(tester, blocks);

    expect(find.text('복습할 단어'), findsOneWidget);
    expect(find.text('2개'), findsOneWidget);
    expect(find.text('새 단어'), findsOneWidget);
    expect(find.text('8개 · 13개 중'), findsOneWidget);
    expect(
      find.textContaining('복습 2장을 먼저, 남은 8장은 새 단어로 — 오늘 10장.'),
      findsOneWidget,
    );
    expect(find.text('오늘 학습 시작 · 10장'), findsOneWidget);
  });

  testWidgets('daily goal 전부: every new word, no 「· n개 중」', (tester) async {
    final blocks = TestBlocks();
    await _seed(blocks, 15);
    await blocks.preferences.save(
      const StudyPreferences(dailyGoal: DailyGoal.all),
    );
    await _pump(tester, blocks);

    expect(find.text('15개'), findsOneWidget);
    expect(find.textContaining('개 중'), findsNothing);
    expect(find.textContaining('새 단어 15장 — 오늘 15장.'), findsOneWidget);
    expect(find.text('오늘 학습 시작 · 15장'), findsOneWidget);
  });

  testWidgets('daily goal 50 with fewer reviews than the goal', (tester) async {
    final blocks = TestBlocks();
    final words = await _seed(blocks, 60);
    for (final w in words.take(55)) {
      await blocks.reviews.saveCard(_due(w.id));
    }
    await blocks.preferences.save(
      const StudyPreferences(dailyGoal: DailyGoal.fifty),
    );
    await _pump(tester, blocks);

    expect(find.text('55개'), findsOneWidget);
    expect(find.text('0개 · 5개 중'), findsOneWidget);
    expect(find.textContaining('복습 50장 — 오늘 50장.'), findsOneWidget);
    expect(find.text('오늘 학습 시작 · 50장'), findsOneWidget);
  });

  testWidgets('the week strip marks the days studied and the run of days', (
    tester,
  ) async {
    final blocks = TestBlocks();
    final words = await _seed(blocks, 3);
    for (final days in [1, 2]) {
      await blocks.reviews.addLog(
        _answered(words.first.id, testNow.subtract(Duration(days: days))),
      );
    }
    await _pump(tester, blocks);

    for (final day in ['월', '화', '수', '목', '금', '토', '일']) {
      expect(find.text(day), findsOneWidget);
    }
    expect(find.text('이번 주 2일 학습 · 연속 2일'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('11월 4일 수요일, 학습함')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('11월 5일 목요일, 오늘')), findsOneWidget);
  });

  testWidgets('the study mode is one row that opens a menu', (tester) async {
    final handle = tester.ensureSemantics();
    final blocks = TestBlocks();
    await _seed(blocks, 6);
    await _pump(tester, blocks);

    expect(find.byType(ChoiceChip), findsNothing, reason: 'folded on 홈');
    expect(find.bySemanticsLabel(RegExp('학습 방식.*뜻 맞히기')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('학습 방식.*뜻 맞히기')));
    await tester.pumpAndSettle();
    for (final mode in StudyMode.values) {
      expect(
        find.text(switch (mode) {
          StudyMode.meaning => '뜻 맞히기',
          StudyMode.recall => '일본어 떠올리기',
          StudyMode.listening => '듣고 맞히기',
          StudyMode.choice => '객관식',
        }),
        findsWidgets,
      );
    }
    await tester.tap(find.text('일본어 떠올리기').last);
    await tester.pumpAndSettle();

    expect((await blocks.preferences.load()).mode, StudyMode.recall);
    expect(find.bySemanticsLabel(RegExp('학습 방식.*일본어 떠올리기')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a mode that cannot be picked says why in the menu', (
    tester,
  ) async {
    final blocks = TestBlocks();
    await _seed(blocks, 2);
    await _pump(tester, blocks);
    await tester.tap(find.textContaining('뜻 맞히기').first);
    await tester.pumpAndSettle();

    expect(find.text('뜻이 서로 다른 단어가 4개 이상 있어야 해요'), findsWidgets);
    await tester.tap(find.text('객관식').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect((await blocks.preferences.load()).mode, StudyMode.meaning);
  });

  testWidgets('페이지 등록 and the start button stay at the bottom', (tester) async {
    final blocks = TestBlocks();
    await _seed(blocks, 5);
    for (var i = 0; i < 8; i++) {
      await LibraryService(
        library: blocks.library,
        clock: blocks.clock,
      ).createPlaylist('목록 $i');
    }
    await _pump(tester, blocks);

    final register = tester.getRect(find.text('페이지 등록'));
    final start = tester.getRect(find.text('오늘 학습 시작 · 5장'));
    expect(register.bottom, greaterThan(844 - 120));
    expect(start.bottom, greaterThan(844 - 120));

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('페이지 등록')), register);
    expect(find.text('오늘 학습 시작 · 5장'), findsOneWidget);
  });

  testWidgets('no word yet: the sheet says so, the bar offers 페이지 등록 only', (
    tester,
  ) async {
    await _pump(tester, TestBlocks());
    expect(find.text('먼저 페이지를 등록해 주세요'), findsOneWidget);
    expect(find.textContaining('오늘 학습 시작'), findsNothing);
    expect(find.text('페이지 등록'), findsOneWidget);
  });
}
