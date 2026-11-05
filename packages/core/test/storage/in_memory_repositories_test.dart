import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime(2026, 11, 5);

  Word word(
    String id, {
    String tb = 'tb',
    int? day,
    String? no,
    DateTime? at,
  }) => Word(
    id: id,
    textbookId: tb,
    day: day,
    no: no,
    headword: id,
    readings: const [],
    meaning: '',
    createdAt: at ?? t0,
  );

  group('InMemoryLibraryRepository', () {
    test('lists textbooks oldest first', () async {
      final repo = InMemoryLibraryRepository();
      await repo.saveTextbook(
        Textbook(
          id: 'b',
          title: 'B',
          createdAt: t0.add(const Duration(days: 1)),
        ),
      );
      await repo.saveTextbook(Textbook(id: 'a', title: 'A', createdAt: t0));
      expect((await repo.textbooks()).map((t) => t.id), ['a', 'b']);
      expect((await repo.textbook('b'))?.title, 'B');
      expect(await repo.textbook('zz'), isNull);
    });

    test('orders words by textbook, day and number, and filters', () async {
      final repo = InMemoryLibraryRepository();
      await repo.saveTextbook(Textbook(id: 'tb', title: 'T', createdAt: t0));
      await repo.saveTextbook(
        Textbook(
          id: 'tb2',
          title: 'T2',
          createdAt: t0.add(const Duration(days: 1)),
        ),
      );
      await repo.saveWords([
        word('tb2:1', tb: 'tb2', day: 1, no: '0001'),
        word('c', day: 2, no: '0031'),
        word('b', day: 1, no: '0016'),
        word('a', day: 1, no: '0001'),
        word('x'), // no day: last
      ]);
      expect((await repo.words()).map((w) => w.id), [
        'a',
        'b',
        'c',
        'x',
        'tb2:1',
      ]);
      expect((await repo.words(textbookId: 'tb', day: 1)).map((w) => w.id), [
        'a',
        'b',
      ]);
      expect((await repo.word('c'))?.day, 2);
    });

    test('saveWords replaces by id', () async {
      final repo = InMemoryLibraryRepository();
      await repo.saveWords([word('a', no: '0001')]);
      await repo.saveWords([word('a', no: '0002')]);
      expect((await repo.words()).single.no, '0002');
    });

    test('days are ordered by number and replaced by number', () async {
      final repo = InMemoryLibraryRepository();
      await repo.saveDay(
        const TextbookDay(textbookId: 'tb', number: 2, title: '둘'),
      );
      await repo.saveDay(
        const TextbookDay(textbookId: 'tb', number: 1, title: '하나'),
      );
      await repo.saveDay(
        const TextbookDay(textbookId: 'tb', number: 1, title: '자연, 몸'),
      );
      expect((await repo.days('tb')).map((d) => (d.number, d.title)), [
        (1, '자연, 몸'),
        (2, '둘'),
      ]);
    });

    test('returned lists cannot be changed by callers', () async {
      final repo = InMemoryLibraryRepository();
      await repo.saveWords([word('a')]);
      final list = await repo.words();
      expect(() => list.add(word('b')), throwsUnsupportedError);
    });
  });

  group('InMemoryReviewRepository', () {
    ReviewCard card(String id) =>
        ReviewCard(wordId: id, level: 1, dueAt: t0, lastReviewedAt: t0);

    test('stores cards by word id', () async {
      final repo = InMemoryReviewRepository();
      await repo.saveCard(card('a'));
      await repo.saveCard(card('b'));
      await repo.saveCard(card('a').copyWith(level: 3));
      expect((await repo.card('a'))?.level, 3);
      expect((await repo.cards()).keys, unorderedEquals(['a', 'b']));
      expect((await repo.cards(wordIds: ['b', 'zz'])).keys, ['b']);
    });

    test('logs filter by time', () async {
      final repo = InMemoryReviewRepository();
      for (final h in [1, 5, 9]) {
        await repo.addLog(
          ReviewLog(
            wordId: 'a',
            answer: Answer.known,
            at: t0.add(Duration(hours: h)),
            levelBefore: 0,
            levelAfter: 4,
            retriesInSession: 0,
          ),
        );
      }
      expect((await repo.logs()).length, 3);
      expect(
        (await repo.logs(since: t0.add(const Duration(hours: 5)))).length,
        2,
      );
    });
  });
}
