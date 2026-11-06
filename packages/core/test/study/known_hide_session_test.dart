// 이미 알아요 (hiding a word the learner already knows) in the pure session
// logic: the builder leaves hidden words out, a session can drop its current
// card without an answer and take it back.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 5, 21);

  Word word(String id, {DateTime? hiddenAt}) => Word(
    id: id,
    headword: id,
    readings: const ['よみ'],
    meaning: '뜻',
    createdAt: now,
    hiddenAt: hiddenAt,
  );

  ReviewCard due(String id, Duration ago) => ReviewCard(
    wordId: id,
    level: 2,
    dueAt: now.subtract(ago),
    lastReviewedAt: now.subtract(const Duration(days: 3)),
  );

  group('SessionBuilder', () {
    const builder = SessionBuilder();
    final hiddenAt = now.subtract(const Duration(days: 1));

    test('leaves hidden words out, due or new', () {
      final words = [
        word('d1'),
        word('d2', hiddenAt: hiddenAt),
        word('n1', hiddenAt: hiddenAt),
        word('n2'),
      ];
      final cards = {
        'd1': due('d1', const Duration(hours: 1)),
        'd2': due('d2', const Duration(hours: 2)),
      };
      final s = builder.build(words: words, cards: cards, now: now, goal: 10);
      expect(s.queue.map((i) => i.word.id), ['d1', 'n2']);
      expect(s.total, 2);
    });

    test('hidden words do not take places of the goal', () {
      final words = [
        for (var i = 0; i < 4; i++) word('h$i', hiddenAt: hiddenAt),
        word('a'),
        word('b'),
      ];
      final s = builder.build(words: words, cards: const {}, now: now, goal: 2);
      expect(s.queue.map((i) => i.word.id), ['a', 'b']);
    });

    test('only hidden words: nothing to study', () {
      final s = builder.build(
        words: [word('a', hiddenAt: hiddenAt)],
        cards: {'a': due('a', const Duration(minutes: 1))},
        now: now,
        goal: 10,
      );
      expect(s.isFinished, isTrue);
      expect(s.total, 0);
    });
  });

  group('StudySession', () {
    final session = const SessionBuilder().build(
      words: [word('a'), word('b'), word('c')],
      cards: const {},
      now: now,
      goal: 3,
    );

    test('afterHidden drops the current card without counting it', () {
      final next = session.afterHidden(at: now);
      expect(next.queue.map((i) => i.word.id), ['b', 'c']);
      expect(next.total, 2);
      expect(next.knownCount, 0);
      expect(next.retryCount, 0);
      expect(next.isFinished, isFalse);
      expect(next.finishedAt, isNull);
      expect(session.queue, hasLength(3), reason: 'the old session is kept');
    });

    test('progress stays a share of the cards left to learn', () {
      final known = session.afterKnown(at: now);
      final next = known.afterHidden(at: now);
      expect((next.knownCount, next.total), (1, 2));
      expect(next.progress, 0.5);
    });

    test('hiding the last card finishes the session at that time', () {
      final last = session.afterKnown(at: now).afterKnown(at: now);
      final later = now.add(const Duration(minutes: 3));
      final done = last.afterHidden(at: later);
      expect(done.isFinished, isTrue);
      expect(done.finishedAt, later);
      expect((done.knownCount, done.total), (2, 2));
    });

    test('a retried card keeps its retries in the counts when hidden', () {
      final retried = session.afterRetry();
      expect(retried.queue.last.retries, 1);
      final next = retried.afterHidden(at: now);
      expect(next.current?.word.id, 'c');
      expect(next.retryCount, 1);
    });

    test('restored puts the card back in front and counts it again', () {
      final item = session.current!;
      final hidden = session.afterHidden(at: now);
      final back = hidden.restored(item);
      expect(back.queue.map((i) => i.word.id), ['a', 'b', 'c']);
      expect(back.total, 3);
      expect(back.current, same(item));
    });

    test('restoring into a finished session reopens it', () {
      final last = session.afterKnown(at: now).afterKnown(at: now);
      final item = last.current!;
      final done = last.afterHidden(at: now);
      final back = done.restored(item);
      expect(back.isFinished, isFalse);
      expect(back.finishedAt, isNull);
      expect(back.current?.word.id, 'c');
      expect((back.knownCount, back.total), (2, 3));
    });

    test('hiding in a finished session is an error', () {
      final done = session
          .afterKnown(at: now)
          .afterKnown(at: now)
          .afterKnown(at: now);
      expect(() => done.afterHidden(at: now), throwsStateError);
    });
  });
}
