// 더 학습하기: which cards a session brought forward picks, in what order,
// and how its cards carry that through the session. Made-up words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 5, 21);
  const builder = SessionBuilder();

  Word word(String id, {bool hidden = false}) => Word(
    id: id,
    headword: id,
    readings: const ['よみ'],
    meaning: '뜻',
    createdAt: now,
    hiddenAt: hidden ? now : null,
  );

  ReviewCard card(String id, int level, Duration dueIn) => ReviewCard(
    wordId: id,
    level: level,
    dueAt: now.add(dueIn),
    lastReviewedAt: now.subtract(const Duration(days: 1)),
  );

  group('SessionBuilder.buildMore', () {
    final words = [
      word('w1'),
      word('w2'),
      word('w3'),
      word('w4'),
      word('w5'),
      word('w6', hidden: true),
      word('w7'),
    ];
    final cards = {
      'w1': card('w1', 4, const Duration(days: 21)),
      'w2': card('w2', 2, const Duration(days: 3)),
      'w3': card('w3', 2, const Duration(days: 1)),
      // Due already: left to the usual session.
      'w4': card('w4', 1, -const Duration(minutes: 1)),
      // w5 has no card: a new word, left to the usual session.
      // Hidden: left out.
      'w6': card('w6', 1, const Duration(minutes: 10)),
      'w7': card('w7', 3, const Duration(days: 2)),
    };

    test('picks only cards whose time has not come, lowest level first, '
        'then the earliest review', () {
      final s = builder.buildMore(
        words: words,
        cards: cards,
        now: now,
        goal: 10,
      );
      expect(s.queue.map((i) => i.word.id), ['w3', 'w2', 'w7', 'w1']);
      expect(s.total, 4);
      expect(s.startedAt, now);
      expect(s.queue.every((i) => i.ahead), isTrue);
      expect(s.queue.every((i) => i.retries == 0), isTrue);
      expect(s.queue.map((i) => i.before), [
        cards['w3'],
        cards['w2'],
        cards['w7'],
        cards['w1'],
      ]);
    });

    test('same level and same review time keep the words\' order', () {
      final same = {
        for (final id in ['w5', 'w2', 'w3'])
          id: card(id, 2, const Duration(days: 3)),
      };
      final s = builder.buildMore(
        words: words,
        cards: same,
        now: now,
        goal: 10,
      );
      expect(s.queue.map((i) => i.word.id), ['w2', 'w3', 'w5']);
    });

    test('the goal caps the session', () {
      final s = builder.buildMore(
        words: words,
        cards: cards,
        now: now,
        goal: 2,
      );
      expect(s.queue.map((i) => i.word.id), ['w3', 'w2']);
      expect(s.total, 2);
    });

    test('a goal below one gives an empty session', () {
      for (final goal in [0, -1]) {
        final s = builder.buildMore(
          words: words,
          cards: cards,
          now: now,
          goal: goal,
        );
        expect(s.total, 0);
        expect(s.isFinished, isTrue);
      }
    });

    test('a card due exactly now is due, not brought forward', () {
      final s = builder.buildMore(
        words: [word('w1')],
        cards: {'w1': card('w1', 2, Duration.zero)},
        now: now,
        goal: 10,
      );
      expect(s.total, 0);
    });

    test('only new words, or nothing: an empty session', () {
      expect(
        builder
            .buildMore(words: words, cards: const {}, now: now, goal: 10)
            .isFinished,
        isTrue,
      );
      expect(
        builder
            .buildMore(words: const [], cards: const {}, now: now, goal: 10)
            .total,
        0,
      );
    });

    test('the usual session still marks nothing as brought forward', () {
      final s = builder.build(words: words, cards: cards, now: now, goal: 10);
      expect(s.queue.map((i) => i.word.id), ['w4', 'w5']);
      expect(s.queue.any((i) => i.ahead), isFalse);
    });
  });

  group('a card brought forward in a session', () {
    final item = SessionItem(
      word: word('w1'),
      before: card('w1', 3, const Duration(days: 2)),
      ahead: true,
    );

    test('stays brought forward when retried', () {
      final again = item.retried();
      expect(again.ahead, isTrue);
      expect(again.retries, 1);
      expect(again.before, item.before);
    });

    test('goes to the back on 다시 학습 and keeps its mark', () {
      final session = StudySession(
        queue: [
          item,
          SessionItem(
            word: word('w2'),
            before: card('w2', 2, const Duration(days: 1)),
            ahead: true,
          ),
        ],
        total: 2,
        startedAt: now,
      );
      final next = session.afterRetry();
      expect(next.queue.last.word.id, 'w1');
      expect(next.queue.last.ahead, isTrue);
    });

    test('a card is not brought forward unless the builder says so', () {
      expect(SessionItem(word: word('w1'), before: null).ahead, isFalse);
    });
  });
}
