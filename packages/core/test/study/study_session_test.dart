import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 5, 21);

  Word word(String id) => Word(
    id: id,
    headword: id,
    readings: const ['よみ'],
    meaning: '뜻',
    createdAt: now,
  );

  ReviewCard due(String id, Duration ago) => ReviewCard(
    wordId: id,
    level: 2,
    dueAt: now.subtract(ago),
    lastReviewedAt: now.subtract(const Duration(days: 3)),
  );

  group('SessionBuilder', () {
    const builder = SessionBuilder();
    final words = [for (var i = 1; i <= 6; i++) word('w$i')];

    test(
      'puts due cards first (oldest due first), then fills with new words',
      () {
        final cards = {
          'w5': due('w5', const Duration(minutes: 5)),
          'w2': due('w2', const Duration(hours: 2)),
          'w4': ReviewCard(
            wordId: 'w4',
            level: 3,
            dueAt: now.add(const Duration(days: 1)),
            lastReviewedAt: now,
          ),
        };
        final s = builder.build(words: words, cards: cards, now: now, goal: 4);
        expect(s.queue.map((i) => i.word.id), ['w2', 'w5', 'w1', 'w3']);
        expect(s.queue.map((i) => i.isNew), [false, false, true, true]);
        expect(s.total, 4);
      },
    );

    test('a goal smaller than the due count takes due cards only', () {
      final cards = {
        for (final w in words) w.id: due(w.id, const Duration(minutes: 1)),
      };
      final s = builder.build(words: words, cards: cards, now: now, goal: 3);
      expect(s.queue.every((i) => !i.isNew), isTrue);
      expect(s.total, 3);
    });

    test('nothing to study gives a finished session', () {
      final s = builder.build(
        words: const [],
        cards: const {},
        now: now,
        goal: 10,
      );
      expect(s.isFinished, isTrue);
      expect(s.current, isNull);
      expect(s.progress, 0);
    });
  });

  group('StudySession', () {
    final session = const SessionBuilder().build(
      words: [word('a'), word('b'), word('c')],
      cards: const {},
      now: now,
      goal: 3,
    );

    test('다시 학습 sends the card to the back and does not advance progress', () {
      final next = session.afterRetry();
      expect(next.queue.map((i) => i.word.id), ['b', 'c', 'a']);
      expect(next.queue.last.retries, 1);
      expect(next.knownCount, 0);
      expect(next.retryCount, 1);
      expect(
        session.queue.first.word.id,
        'a',
        reason: 'sessions are immutable',
      );
    });

    test('알고있음 removes the card and counts toward progress', () {
      final next = session.afterKnown();
      expect(next.queue.map((i) => i.word.id), ['b', 'c']);
      expect(next.knownCount, 1);
      expect(next.progress, closeTo(1 / 3, 1e-9));
    });

    test('finishes when every card is known', () {
      final done = session.afterRetry().afterKnown().afterKnown().afterKnown();
      expect(done.isFinished, isTrue);
      expect((done.knownCount, done.total, done.progress), (3, 3, 1.0));
    });

    test('records when the last card was known; elapsed never negative', () {
      final end = now.add(const Duration(minutes: 3));
      final done = session
          .afterKnown(at: end)
          .afterKnown(at: end)
          .afterKnown(at: end);
      expect(done.finishedAt, end);
      expect(done.elapsed, const Duration(minutes: 3));
      expect(
        session.afterKnown(at: end).finishedAt,
        isNull,
        reason: 'not the last card',
      );
      final early = session.afterKnown().afterKnown().afterKnown(
        at: now.subtract(const Duration(seconds: 5)),
      );
      expect(early.elapsed, Duration.zero);
      expect(session.elapsed, isNull);
    });

    test('answering a finished session is an error', () {
      final done = session.afterKnown().afterKnown().afterKnown();
      expect(done.afterKnown, throwsStateError);
      expect(done.afterRetry, throwsStateError);
    });
  });
}
