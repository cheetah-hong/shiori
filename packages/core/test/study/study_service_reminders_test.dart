// StudyService.reminders (N1): the cards summary counts, in the mode asked,
// planned by planReminders. Reads only: no card or press changes.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

/// Friday 13 November 2026, 10:00.
final _now = DateTime(2026, 11, 13, 10);

const _eight = ReminderTime(8 * 60);

void main() {
  late InMemoryLibraryRepository library;
  late InMemoryReviewRepository reviews;

  StudyService serviceAt(DateTime now) => StudyService(
    library: library,
    reviews: reviews,
    scheduler: const LeitnerFourStepScheduler(),
    clock: FixedClock(now),
  );

  ReviewCard card(
    String id,
    DateTime due, {
    StudyMode mode = StudyMode.meaning,
  }) => ReviewCard(
    wordId: id,
    level: 2,
    dueAt: due,
    lastReviewedAt: due.subtract(const Duration(days: 3)),
    mode: mode,
  );

  setUp(() async {
    library = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    await seedPlaylist(library, 'tb', [
      seedWord('w1', '語一', at: _now, meaning: '말 하나'),
      seedWord('w2', '語二', at: _now, meaning: '말 둘'),
      seedWord('w3', '語三', at: _now, meaning: '말 셋'),
      seedWord('w4', '語四', at: _now, meaning: ''),
      seedWord('w5', '語五', at: _now, meaning: '말 다섯', hiddenAt: _now),
    ], at: _now);
    await library.hideWords(['w5'], at: _now);
  });

  test('counts the due cards of the mode, new words left out', () async {
    await reviews.saveCard(card('w1', DateTime(2026, 11, 12)));
    await reviews.saveCard(card('w2', DateTime(2026, 11, 15, 9)));
    // Another mode's card is another record.
    await reviews.saveCard(
      card('w3', DateTime(2026, 11, 12), mode: StudyMode.recall),
    );

    final plan = await serviceAt(
      _now,
    ).reminders(mode: StudyMode.meaning, time: _eight);
    expect([for (final r in plan) r.at.day], [14, 15, 16, 17, 18, 19, 20]);
    expect([for (final r in plan) r.dueCount], [1, 1, 2, 2, 2, 2, 2]);
  });

  test('hidden words and words the mode cannot ask are left out', () async {
    await reviews.saveCard(
      card('w4', DateTime(2026, 11, 12), mode: StudyMode.recall),
    ); // no meaning: 일본어 떠올리기 cannot ask it
    await reviews.saveCard(
      card('w5', DateTime(2026, 11, 12), mode: StudyMode.recall),
    ); // hidden
    await reviews.saveCard(
      card('w1', DateTime(2026, 11, 14, 7), mode: StudyMode.recall),
    );

    final plan = await serviceAt(
      _now,
    ).reminders(mode: StudyMode.recall, time: _eight, days: 2);
    expect([for (final r in plan) (r.at.day, r.dueCount)], [(14, 1), (15, 1)]);
  });

  test('a press today, in any mode, drops today', () async {
    await reviews.saveCard(card('w1', DateTime(2026, 11, 12)));
    await reviews.addLog(
      ReviewLog(
        wordId: 'w2',
        mode: StudyMode.choice,
        answer: Answer.retry,
        at: DateTime(2026, 11, 13, 5),
        levelBefore: 0,
        levelAfter: 1,
        retriesInSession: 1,
      ),
    );

    final plan = await serviceAt(
      DateTime(2026, 11, 13, 6),
    ).reminders(mode: StudyMode.meaning, time: _eight, days: 3);
    expect([for (final r in plan) r.at.day], [14, 15]);
  });

  test('a press on an earlier study day keeps today', () async {
    await reviews.saveCard(card('w1', DateTime(2026, 11, 12)));
    await reviews.addLog(
      ReviewLog(
        wordId: 'w1',
        answer: Answer.known,
        at: DateTime(2026, 11, 13, 3), // before 04:00: the 12th's study day
        levelBefore: 1,
        levelAfter: 2,
        retriesInSession: 0,
      ),
    );

    final plan = await serviceAt(
      DateTime(2026, 11, 13, 6),
    ).reminders(mode: StudyMode.meaning, time: _eight, days: 2);
    expect([for (final r in plan) r.at.day], [13, 14]);
  });

  test('planning changes no card and no press', () async {
    await reviews.saveCard(card('w1', DateTime(2026, 11, 12)));
    final before = (await reviews.cards(), await reviews.logs());
    await serviceAt(_now).reminders(mode: StudyMode.meaning, time: _eight);
    expect(await reviews.cards(), before.$1);
    expect(await reviews.logs(), before.$2);
  });
}
