// 이미 알아요 through StudyService: hiding the current card, undoing it, what
// the summary counts, and a hide that fails.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime(2026, 11, 5, 21);
  late InMemoryLibraryRepository library;
  late InMemoryReviewRepository reviews;

  StudyService serviceAt(
    DateTime now, {
    int goal = 10,
    HiddenWordRepository? hidden,
  }) => StudyService(
    library: library,
    reviews: reviews,
    scheduler: const LeitnerFourStepScheduler(),
    clock: FixedClock(now),
    settings: StudySettings(dailyGoal: goal),
    hidden: hidden,
  );

  setUp(() async {
    library = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    await library.saveTextbook(
      Textbook(id: 'tb', title: '단어장', createdAt: start),
    );
    await library.saveWords([
      for (var i = 1; i <= 4; i++)
        Word(
          id: 'tb:000$i',
          textbookId: 'tb',
          day: 1,
          no: '000$i',
          headword: '語$i',
          readings: const ['ご'],
          meaning: '말 $i',
          createdAt: start,
        ),
    ]);
  });

  test('the in-memory library is where words are hidden by default', () {
    expect(serviceAt(start).hidden, same(library));
  });

  test(
    'hide: the word is hidden at the clock time and the next card is up',
    () async {
      final service = serviceAt(start);
      final session = await service.startSession();
      final next = await service.hide(session);

      expect(next.current?.word.id, 'tb:0002');
      expect(next.total, 3);
      final hidden = await library.word('tb:0001');
      expect(hidden?.hiddenAt, start);
      expect(await reviews.cards(), isEmpty, reason: 'no card is written');
      expect(await reviews.logs(), isEmpty, reason: 'no press is logged');
    },
  );

  test(
    'a hidden word with a card keeps the card and comes back with it',
    () async {
      final card = ReviewCard(
        wordId: 'tb:0003',
        level: 3,
        dueAt: start.subtract(const Duration(minutes: 1)),
        lastReviewedAt: start.subtract(const Duration(days: 7)),
        reviewCount: 2,
      );
      await reviews.saveCard(card);
      final service = serviceAt(start);
      final session = await service.startSession();
      expect(session.current?.word.id, 'tb:0003', reason: 'due first');

      final next = await service.hide(session);
      expect(await reviews.card('tb:0003'), card);
      final later = serviceAt(start.add(const Duration(days: 30)));
      expect(
        (await later.startSession()).queue.map((i) => i.word.id),
        isNot(contains('tb:0003')),
      );

      final back = await service.unhide(next, session.current!);
      expect(back.current?.word.id, 'tb:0003');
      expect(back.current?.before, card);
      expect((await library.word('tb:0003'))?.isHidden, isFalse);
      final again = await later.startSession();
      expect(again.current?.word.id, 'tb:0003');
      expect(again.current?.before, card);
    },
  );

  test('a hidden card can still be answered after it is restored', () async {
    final service = serviceAt(start);
    final session = await service.startSession();
    final item = session.current!;
    final back = await service.unhide(await service.hide(session), item);
    final next = await service.answer(back, Answer.known);
    expect((await reviews.card(item.word.id))?.level, 4);
    expect(next.knownCount, 1);
  });

  test(
    'the summary leaves hidden words out of today and keeps the count',
    () async {
      await reviews.saveCard(
        ReviewCard(
          wordId: 'tb:0004',
          level: 1,
          dueAt: start.subtract(const Duration(minutes: 1)),
          lastReviewedAt: start,
        ),
      );
      final service = serviceAt(start);
      final before = await service.summary();
      expect((before.dueCount, before.newCount, before.hiddenCount), (1, 3, 0));

      await library.hideWords(['tb:0001', 'tb:0004'], at: start);
      final after = await service.summary();
      expect(
        (after.dueCount, after.newCount, after.wordCount, after.hiddenCount),
        (0, 2, 4, 2),
      );
    },
  );

  test('presses made before hiding still count as known today', () async {
    final service = serviceAt(start);
    final session = await service.answer(
      await service.startSession(),
      Answer.known,
    );
    expect(session.knownCount, 1);
    await library.hideWords(['tb:0001'], at: start);
    expect((await service.summary()).knownToday, 1);
  });

  test('a hide that fails changes nothing and is reported', () async {
    final failing = _FailingHide();
    final service = serviceAt(start, hidden: failing);
    final session = await service.startSession();
    await expectLater(service.hide(session), throwsA(isA<StateError>()));
    expect(
      await library.words(),
      everyElement(isA<Word>().having((w) => w.isHidden, 'isHidden', isFalse)),
    );
    expect(await reviews.cards(), isEmpty);
    expect(await reviews.logs(), isEmpty);
    expect(session.current?.word.id, 'tb:0001', reason: 'sessions are values');
  });

  test('without a block that hides, hide is an error', () async {
    final service = StudyService(
      library: _PlainLibrary(library),
      reviews: reviews,
      scheduler: const LeitnerFourStepScheduler(),
      clock: FixedClock(start),
    );
    expect(service.hidden, isNull);
    final session = await service.startSession();
    await expectLater(service.hide(session), throwsStateError);
  });

  test('hiding in a finished session is an error', () async {
    final service = serviceAt(start);
    final session = await service.startSession(goal: 0);
    expect(session.isFinished, isTrue);
    await expectLater(service.hide(session), throwsStateError);
  });
}

/// Fails every write (a full disk, say).
final class _FailingHide implements HiddenWordRepository {
  @override
  Future<void> hideWords(Iterable<String> wordIds, {required DateTime at}) =>
      Future.error(StateError('disk full'));

  @override
  Future<void> unhideWords(Iterable<String> wordIds) =>
      Future.error(StateError('disk full'));

  @override
  Future<List<Word>> hiddenWords({String? textbookId}) async => const [];
}

/// A library block that cannot hide words.
final class _PlainLibrary implements LibraryRepository {
  _PlainLibrary(this._inner);

  final LibraryRepository _inner;

  @override
  Future<List<Textbook>> textbooks() => _inner.textbooks();

  @override
  Future<Textbook?> textbook(String id) => _inner.textbook(id);

  @override
  Future<void> saveTextbook(Textbook textbook) => _inner.saveTextbook(textbook);

  @override
  Future<List<TextbookDay>> days(String textbookId) => _inner.days(textbookId);

  @override
  Future<void> saveDay(TextbookDay day) => _inner.saveDay(day);

  @override
  Future<List<Word>> words({String? textbookId, int? day}) =>
      _inner.words(textbookId: textbookId, day: day);

  @override
  Future<Word?> word(String id) => _inner.word(id);

  @override
  Future<List<TextbookStats>> textbookStats() => _inner.textbookStats();

  @override
  Future<void> saveWords(List<Word> words) => _inner.saveWords(words);

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _inner.transaction(action);
}
