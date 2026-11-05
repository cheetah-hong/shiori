import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

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
    await library.saveTextbook(
      Textbook(id: 'tb', title: '단어장', createdAt: start),
    );
    await library.saveWords([
      for (var i = 1; i <= 3; i++)
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

  test('a session can be limited to one textbook', () async {
    await library.saveTextbook(
      Textbook(id: 'other', title: '다른 책', createdAt: start),
    );
    await library.saveWords([
      Word(
        id: 'other:1',
        textbookId: 'other',
        headword: '他',
        readings: const ['た'],
        meaning: '다른',
        createdAt: start,
      ),
    ]);
    final session = await serviceAt(start).startSession(textbookId: 'other');
    expect(session.queue.map((i) => i.word.id), ['other:1']);
  });

  test('preview label follows the scheduler', () async {
    final service = serviceAt(start);
    final session = await service.startSession();
    expect(service.previewKnown(session.current!), const Duration(days: 21));
  });
}
