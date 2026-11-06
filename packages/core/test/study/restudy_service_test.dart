// Studying learned words again through StudyService: 처음부터 다시 학습 for one
// word (and its undo), resetting every word, and 더 학습하기 (cards brought
// forward before their review time). Made-up words, a fixed clock.
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

  ReviewCard card(
    String id,
    int level,
    Duration dueIn, {
    int reviewCount = 1,
    int lapseCount = 0,
    CardScope scope = CardScope.shared,
  }) => ReviewCard(
    wordId: id,
    level: level,
    dueAt: start.add(dueIn),
    lastReviewedAt: start.subtract(const Duration(days: 1)),
    reviewCount: reviewCount,
    lapseCount: lapseCount,
    scope: scope,
  );

  ReviewLog log(String id, Answer answer) => ReviewLog(
    wordId: id,
    answer: answer,
    at: start.subtract(const Duration(hours: 1)),
    levelBefore: 0,
    levelAfter: 4,
    retriesInSession: 0,
  );

  (String, Answer, DateTime, int, int, int) fields(ReviewLog l) => (
    l.wordId,
    l.answer,
    l.at,
    l.levelBefore,
    l.levelAfter,
    l.retriesInSession,
  );

  setUp(() async {
    library = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    await seedPlaylist(library, 'tb', [
      for (var i = 1; i <= 6; i++)
        seedWord('tb:000$i', '語$i', at: start, meaning: '말 $i'),
    ], at: start);
  });

  group('처음부터 다시 학습 (resetWords)', () {
    late ReviewCard first;
    late ReviewCard second;

    setUp(() async {
      first = card('tb:0001', 4, const Duration(days: 21));
      second = card('tb:0002', 3, const Duration(days: 7), reviewCount: 3);
      await reviews.saveCard(first);
      await reviews.saveCard(second);
      await reviews.addLog(log('tb:0001', Answer.known));
      await reviews.addLog(log('tb:0002', Answer.retry));
    });

    test('the word is new again and comes up in the next session', () async {
      final service = serviceAt(start);
      final before = await service.summary();

      final removed = await service.resetWords(['tb:0001']);

      expect(removed, [first]);
      expect(await reviews.card('tb:0001'), isNull);
      final after = await service.summary();
      expect(after.newCount, before.newCount + 1);
      final session = await service.startSession();
      final item = session.queue.firstWhere((i) => i.word.id == 'tb:0001');
      expect(item.isNew, isTrue);
      expect(item.ahead, isFalse);
    });

    test('other cards and every press stay', () async {
      final logsBefore = (await reviews.logs()).map(fields).toList();

      await serviceAt(start).resetWords(['tb:0001']);

      expect(await reviews.card('tb:0002'), second);
      expect((await reviews.logs()).map(fields), logsBefore);
    });

    test('unknown ids and words without a card change nothing', () async {
      final removed = await serviceAt(
        start,
      ).resetWords(['zz', 'tb:0003', 'tb:0003']);

      expect(removed, isEmpty);
      expect((await reviews.cards()).values, unorderedEquals([first, second]));
      expect(await reviews.logs(), hasLength(2));
    });

    test('a hidden word stays hidden', () async {
      await library.hideWords(['tb:0002'], at: start);

      await serviceAt(start).resetWords(['tb:0002']);

      expect(await reviews.card('tb:0002'), isNull);
      expect((await library.word('tb:0002'))?.isHidden, isTrue);
    });

    test('restoreCards puts the removed cards back as they were', () async {
      final service = serviceAt(start);
      final removed = await service.resetWords(['tb:0001', 'tb:0002']);

      await service.restoreCards(removed);

      expect(await reviews.card('tb:0001'), first);
      expect(await reviews.card('tb:0002'), second);
      expect(await reviews.logs(), hasLength(2));
    });

    test('restoreCards skips a word studied again meanwhile', () async {
      final service = serviceAt(start);
      final removed = await service.resetWords(['tb:0001', 'tb:0002']);
      final fresh = card('tb:0001', 1, const Duration(minutes: 30));
      await reviews.saveCard(fresh);

      await service.restoreCards(removed);

      expect(await reviews.card('tb:0001'), fresh);
      expect(await reviews.card('tb:0002'), second);
    });
  });

  group('전체 초기화 (resetAll)', () {
    test('removes every card of every scope and keeps the rest', () async {
      final pl = CardScope.playlist('tb');
      await reviews.saveCard(card('tb:0001', 4, const Duration(days: 21)));
      await reviews.saveCard(card('tb:0002', 2, const Duration(days: 3)));
      await reviews.saveCard(
        card('tb:0003', 1, const Duration(minutes: 30), scope: pl),
      );
      await reviews.saveCard(card('tb:0006', 3, const Duration(days: 7)));
      await reviews.addLog(log('tb:0001', Answer.known));
      await reviews.addLog(log('tb:0002', Answer.retry));
      await library.hideWords(['tb:0006'], at: start);
      final service = serviceAt(start);

      expect(await service.resetAll(), 4);

      expect(await reviews.cards(), isEmpty);
      expect(await reviews.cards(scope: pl), isEmpty);
      expect(await reviews.logs(), hasLength(2));
      expect((await library.word('tb:0006'))?.isHidden, isTrue);
      expect(await library.playlists(), hasLength(1));
      expect(await library.words(playlistId: 'tb'), hasLength(6));
      final summary = await service.summary();
      expect(
        (summary.newCount, summary.dueCount, summary.aheadCount),
        (5, 0, 0),
      );
      expect(summary.hiddenCount, 1);
    });

    test('no cards: nothing to remove', () async {
      expect(await serviceAt(start).resetAll(), 0);
    });
  });

  group('더 학습하기 (startMoreSession)', () {
    // tb:0001 L4 in 21 days, tb:0002 L2 in 3 days, tb:0003 L2 in 1 day,
    // tb:0004 due a minute ago, tb:0005 new, tb:0006 hidden with a card not due.
    late Map<String, ReviewCard> cards;

    setUp(() async {
      cards = {
        'tb:0001': card('tb:0001', 4, const Duration(days: 21)),
        'tb:0002': card('tb:0002', 2, const Duration(days: 3), lapseCount: 1),
        'tb:0003': card('tb:0003', 2, const Duration(days: 1), reviewCount: 2),
        'tb:0004': card('tb:0004', 1, -const Duration(minutes: 1)),
        'tb:0006': card('tb:0006', 1, const Duration(minutes: 10)),
      };
      for (final c in cards.values) {
        await reviews.saveCard(c);
      }
      await library.hideWords(['tb:0006'], at: start);
    });

    test('the summary counts cards whose time has not come', () async {
      final s = await serviceAt(start).summary();
      expect((s.dueCount, s.newCount, s.aheadCount), (1, 1, 3));
    });

    test('picks only cards not due yet, lowest level first, then the '
        'earliest review', () async {
      final session = await serviceAt(start).startMoreSession();
      expect(session.queue.map((i) => i.word.id), [
        'tb:0003',
        'tb:0002',
        'tb:0001',
      ]);
      expect(session.queue.every((i) => i.ahead), isTrue);
      expect(session.queue.first.before, cards['tb:0003']);
    });

    test('the goal (or the daily goal) caps it', () async {
      expect(
        (await serviceAt(
          start,
        ).startMoreSession(goal: 2)).queue.map((i) => i.word.id),
        ['tb:0003', 'tb:0002'],
      );
      expect((await serviceAt(start, goal: 1).startMoreSession()).total, 1);
    });

    test('a playlist scope brings forward only its own words', () async {
      await seedPlaylist(library, 'other', [
        seedWord('ot:0001', '他1', at: start),
      ], at: start);
      await reviews.saveCard(card('ot:0001', 1, const Duration(hours: 1)));
      final service = serviceAt(start);

      final mine = await service.startMoreSession(
        scope: const PlaylistOnly('tb'),
      );
      expect(mine.queue.map((i) => i.word.id), isNot(contains('ot:0001')));
      final all = await service.startMoreSession();
      expect(all.queue.first.word.id, 'ot:0001');
      expect(
        (await service.summary(scope: const PlaylistOnly('other'))).aheadCount,
        1,
      );
    });

    test('nothing brought forward: an empty session', () async {
      await serviceAt(start).resetAll();
      final session = await serviceAt(start).startMoreSession();
      expect(session.total, 0);
      expect(session.isFinished, isTrue);
    });

    test('알고있음 on a card brought forward keeps the card and logs the '
        'press', () async {
      final service = serviceAt(start);
      final session = await service.startMoreSession();

      final next = await service.answer(session, Answer.known);

      expect(await reviews.card('tb:0003'), cards['tb:0003']);
      final logs = await reviews.logs();
      expect(logs, hasLength(1));
      expect(fields(logs.single), ('tb:0003', Answer.known, start, 2, 2, 0));
      expect(next.knownCount, 1);
      expect(next.knownReviewCount, 1);
      expect((await service.summary()).knownToday, 1);
    });

    test('알고있음 at the top level keeps the card too', () async {
      final service = serviceAt(start);
      var session = await service.startMoreSession();
      session = await service.answer(session, Answer.known);
      session = await service.answer(session, Answer.known);
      expect(session.current?.word.id, 'tb:0001');

      await service.answer(session, Answer.known);

      expect(await reviews.card('tb:0001'), cards['tb:0001']);
      expect(fields((await reviews.logs()).last).$4, 4);
      expect(fields((await reviews.logs()).last).$5, 4);
    });

    test('다시 학습: level 1, due now, one more lapse, logged', () async {
      final service = serviceAt(start);
      final session = await service.startMoreSession();

      final next = await service.answer(session, Answer.retry);

      final stored = await reviews.card('tb:0003');
      expect(stored?.level, 1);
      expect(stored?.dueAt, start);
      expect(stored?.lastReviewedAt, start);
      expect(stored?.lapseCount, 1);
      expect(stored?.reviewCount, 2);
      final logs = await reviews.logs();
      expect(fields(logs.single), ('tb:0003', Answer.retry, start, 2, 1, 1));
      expect(next.queue.last.word.id, 'tb:0003');
      expect(next.queue.last.ahead, isTrue);
      expect(next.queue.last.retries, 1);
      expect(next.knownCount, 0);
    });

    test('알고있음 after one 다시 학습 follows the usual rule', () async {
      final service = serviceAt(start);
      var session = await service.startMoreSession(goal: 1);
      session = await service.answer(session, Answer.retry);

      await service.answer(session, Answer.known);

      final stored = await reviews.card('tb:0003');
      expect(stored?.level, 2);
      expect(stored?.dueAt, start.add(const Duration(days: 3)));
      expect(stored?.reviewCount, 3);
      expect(stored?.lapseCount, 1);
      final logs = await reviews.logs();
      expect(fields(logs.last), ('tb:0003', Answer.known, start, 2, 2, 1));
    });

    test('알고있음 after two 다시 학습 goes to level 1', () async {
      final service = serviceAt(start);
      var session = await service.startMoreSession(goal: 1);
      session = await service.answer(session, Answer.retry);
      session = await service.answer(session, Answer.retry);

      await service.answer(session, Answer.known);

      final stored = await reviews.card('tb:0003');
      expect(stored?.level, 1);
      expect(stored?.dueAt, start.add(const Duration(minutes: 30)));
      expect(stored?.lapseCount, 2);
    });

    test('the 알고있음 button shows the time left, or the usual interval '
        'after a retry', () async {
      final service = serviceAt(start);
      var session = await service.startMoreSession(goal: 1);
      expect(service.previewKnown(session.current!), const Duration(days: 1));
      session = await service.answer(session, Answer.retry);
      expect(service.previewKnown(session.current!), const Duration(days: 3));
    });

    test('the usual session is unchanged', () async {
      final service = serviceAt(start);
      var session = await service.startSession();
      expect(session.queue.map((i) => i.word.id), ['tb:0004', 'tb:0005']);
      expect(session.queue.any((i) => i.ahead), isFalse);
      expect(service.previewKnown(session.current!), const Duration(days: 3));

      session = await service.answer(session, Answer.known);
      await service.answer(session, Answer.known);

      final due = await reviews.card('tb:0004');
      expect(due?.level, 2);
      expect(due?.dueAt, start.add(const Duration(days: 3)));
      final fresh = await reviews.card('tb:0005');
      expect(fresh?.level, 4);
      expect(fresh?.dueAt, start.add(const Duration(days: 21)));
    });
  });
}
