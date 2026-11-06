import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

void main() {
  final start = DateTime(2026, 11, 5, 21);
  late InMemoryLibraryRepository library;
  late InMemoryReviewRepository reviews;

  StudyService serviceAt(DateTime now, {int goal = 10}) => StudyService(
    library: library,
    reviews: reviews,
    scheduler: const LeitnerFourStepScheduler(),
    clock: FixedClock(now),
    settings: StudySettings(dailyGoal: goal),
  );

  setUp(() async {
    library = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    await seedPlaylist(library, 'tb', [
      for (var i = 1; i <= 3; i++)
        seedWord('tb:000$i', '語$i', at: start, meaning: '말 $i'),
    ], at: start);
  });

  test('summary counts new words and due reviews', () async {
    final summary = await serviceAt(start).summary();
    expect(
      (
        summary.dueCount,
        summary.newCount,
        summary.knownToday,
        summary.wordCount,
      ),
      (0, 3, 0, 3),
    );
  });

  test('a known new word is stored at level 4 and logged', () async {
    final service = serviceAt(start);
    final session = await service.startSession();
    final next = await service.answer(session, Answer.known);

    final card = await reviews.card('tb:0001');
    expect(card?.level, 4);
    expect(next.knownCount, 1);
    final logs = await reviews.logs();
    expect(logs.single.answer, Answer.known);
    expect((logs.single.levelBefore, logs.single.levelAfter), (0, 4));
  });

  test(
    'retry then known on a new word gives level 2, and the retry is kept meanwhile',
    () async {
      final service = serviceAt(start);
      var session = await service.startSession(goal: 1);
      session = await service.answer(session, Answer.retry);
      expect(
        (await reviews.card('tb:0001'))?.level,
        1,
        reason: 'left half way, the word stays due',
      );
      expect(session.current?.retries, 1);

      session = await service.answer(session, Answer.known);
      final card = await reviews.card('tb:0001');
      expect(
        (card?.level, card?.dueAt),
        (2, start.add(const Duration(days: 3))),
      );
      expect(session.isFinished, isTrue);
    },
  );

  test('a word comes back as a review when its interval has passed', () async {
    final service = serviceAt(start);
    var session = await service.startSession(goal: 1);
    session = await service.answer(session, Answer.retry);
    session = await service.answer(session, Answer.retry);
    await service.answer(session, Answer.known); // level 1, 30 minutes

    expect(
      (await serviceAt(
        start.add(const Duration(minutes: 29)),
      ).summary()).dueCount,
      0,
    );
    final later = serviceAt(start.add(const Duration(minutes: 30)));
    expect((await later.summary()).dueCount, 1);

    final review = await later.startSession(goal: 2);
    expect(review.queue.map((i) => (i.word.id, i.isNew)), [
      ('tb:0001', false),
      ('tb:0002', true),
    ]);
    await later.answer(review, Answer.known);
    expect((await reviews.card('tb:0001'))?.level, 2);
  });

  test('known today counts presses since the study day started', () async {
    final night = DateTime(2026, 11, 6, 2); // before the 04:00 boundary
    final s1 = serviceAt(night);
    await s1.answer(await s1.startSession(goal: 1), Answer.known);
    final morning = serviceAt(DateTime(2026, 11, 6, 9));
    expect((await morning.summary()).knownToday, 0);
    expect((await serviceAt(DateTime(2026, 11, 6, 3)).summary()).knownToday, 1);
  });

  test('a session can be limited to one playlist', () async {
    await seedPlaylist(library, 'other', [
      seedWord('other:1', '他', at: start, meaning: '다른'),
    ], at: start);
    final session = await serviceAt(
      start,
    ).startSession(scope: const PlaylistOnly('other'));
    expect(session.queue.map((i) => i.word.id), ['other:1']);
  });

  test('preview label follows the scheduler', () async {
    final service = serviceAt(start);
    final session = await service.startSession();
    expect(service.previewKnown(session.current!), const Duration(days: 21));
  });

  test('a failed log write keeps the card as it was', () async {
    final failing = _FailingLog();
    final service = StudyService(
      library: library,
      reviews: failing,
      scheduler: const LeitnerFourStepScheduler(),
      clock: FixedClock(start),
    );
    final session = await service.startSession();
    await expectLater(
      service.answer(session, Answer.known),
      throwsA(isA<StateError>()),
    );
    expect(await failing.cards(), isEmpty);
    expect(await failing.logs(), isEmpty);
  });
}

/// Writes the card, then fails on the log.
final class _FailingLog implements ReviewRepository {
  final _inner = InMemoryReviewRepository();

  @override
  Future<ReviewCard?> card(
    String wordId, {
    CardScope scope = CardScope.shared,
  }) => _inner.card(wordId, scope: scope);

  @override
  Future<Map<String, ReviewCard>> cards({
    Iterable<String>? wordIds,
    CardScope scope = CardScope.shared,
  }) => _inner.cards(wordIds: wordIds, scope: scope);

  @override
  Future<void> saveCard(ReviewCard card) => _inner.saveCard(card);

  @override
  Future<void> addLog(ReviewLog log) => Future.error(StateError('disk full'));

  @override
  Future<List<ReviewLog>> logs({DateTime? since, CardScope? scope}) =>
      _inner.logs(since: since, scope: scope);

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _inner.transaction(action);
}
