// A record per study mode: answering a word in one mode moves that mode's
// card only, and in every mode the cards follow the same four-step rules.
// Made-up words, a fixed clock.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

void main() {
  final start = DateTime(2026, 11, 11, 21);
  late InMemoryLibraryRepository library;
  late InMemoryReviewRepository reviews;
  late Word word;

  StudyService serviceAt(DateTime now) => StudyService(
    library: library,
    reviews: reviews,
    scheduler: const LeitnerFourStepScheduler(),
    clock: FixedClock(now),
  );

  StudySession sessionOf(
    List<SessionItem> items,
    StudyMode mode, {
    CardScope cardScope = CardScope.shared,
  }) => StudySession(
    queue: items,
    total: items.length,
    startedAt: start,
    mode: mode,
    cardScope: cardScope,
  );

  ReviewCard card(
    int level, {
    StudyMode mode = StudyMode.meaning,
    Duration dueIn = Duration.zero,
    int reviewCount = 2,
    int lapseCount = 1,
    CardScope scope = CardScope.shared,
  }) => ReviewCard(
    wordId: word.id,
    level: level,
    dueAt: start.add(dueIn),
    lastReviewedAt: start.subtract(const Duration(days: 3)),
    reviewCount: reviewCount,
    lapseCount: lapseCount,
    scope: scope,
    mode: mode,
  );

  setUp(() async {
    library = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    word = seedWord('w1', '語一', at: start, meaning: '말 1');
    await seedPlaylist(library, 'tb', [word], at: start);
  });

  group('one mode does not move another', () {
    test('a new word known in recall leaves meaning new', () async {
      final service = serviceAt(start);
      final after = await service.answer(
        sessionOf([SessionItem(word: word, before: null)], StudyMode.recall),
        Answer.known,
      );

      expect(after.isFinished, isTrue);
      expect(await reviews.card(word.id), isNull);
      final recall = await reviews.card(word.id, mode: StudyMode.recall);
      expect(recall, isNotNull);
      expect(recall!.mode, StudyMode.recall);
      expect(recall.scope, CardScope.shared);
      expect(recall.level, 4);
      for (final mode in [StudyMode.listening, StudyMode.choice]) {
        expect(await reviews.card(word.id, mode: mode), isNull);
      }
    });

    test('a known meaning card keeps its level when listening is '
        'answered', () async {
      final meaning = card(3, dueIn: const Duration(days: 2));
      await reviews.saveCard(meaning);
      final service = serviceAt(start);

      var session = sessionOf([
        SessionItem(word: word, before: null),
      ], StudyMode.listening);
      session = await service.answer(session, Answer.retry);
      session = await service.answer(session, Answer.retry);
      await service.answer(session, Answer.known);

      expect(await reviews.card(word.id), meaning);
      final listening = await reviews.card(word.id, mode: StudyMode.listening);
      expect(listening!.level, 1);
      expect(listening.lapseCount, 2);
    });

    test('다시 학습 saves the interim card in its own mode', () async {
      final meaning = card(4, dueIn: const Duration(days: 20));
      final choice = card(3, mode: StudyMode.choice, lapseCount: 4);
      await reviews.saveCard(meaning);
      await reviews.saveCard(choice);
      final now = start.add(const Duration(minutes: 5));

      await serviceAt(now).answer(
        sessionOf([SessionItem(word: word, before: choice)], StudyMode.choice),
        Answer.retry,
      );

      expect(await reviews.card(word.id), meaning);
      final interim = await reviews.card(word.id, mode: StudyMode.choice);
      expect(interim, isNotNull);
      expect(interim!.level, 1);
      expect(interim.dueAt, now);
      expect(interim.lapseCount, 5, reason: 'counted from the choice card');
      expect(interim.reviewCount, choice.reviewCount);
      expect(interim.mode, StudyMode.choice);
    });

    test('presses are logged with the session mode', () async {
      final service = serviceAt(start);
      var session = sessionOf([
        SessionItem(word: word, before: null),
      ], StudyMode.choice);
      session = await service.answer(session, Answer.retry);
      await service.answer(session, Answer.known);

      final logs = await reviews.logs();
      expect(logs.map((l) => (l.answer, l.mode)), [
        (Answer.retry, StudyMode.choice),
        (Answer.known, StudyMode.choice),
      ]);
      expect(await reviews.logs(mode: StudyMode.meaning), isEmpty);
    });

    test('the session scope names the record (not always shared)', () async {
      final pl = CardScope.playlist('tb');
      final service = serviceAt(start);
      var session = sessionOf(
        [SessionItem(word: word, before: null)],
        StudyMode.recall,
        cardScope: pl,
      );
      session = await service.answer(session, Answer.retry);
      await service.answer(session, Answer.known);

      expect(await reviews.card(word.id, mode: StudyMode.recall), isNull);
      final saved = await reviews.card(
        word.id,
        scope: pl,
        mode: StudyMode.recall,
      );
      expect(saved, isNotNull);
      expect(saved!.scope, pl);
      expect((await reviews.logs(scope: pl)).length, 2);
    });

    test(
      'a card brought forward and known keeps its card in its mode',
      () async {
        final ahead = card(
          2,
          mode: StudyMode.listening,
          dueIn: const Duration(days: 2),
        );
        await reviews.saveCard(ahead);
        await serviceAt(start).answer(
          sessionOf([
            SessionItem(word: word, before: ahead, ahead: true),
          ], StudyMode.listening),
          Answer.known,
        );

        expect(await reviews.card(word.id, mode: StudyMode.listening), ahead);
        expect(await reviews.card(word.id), isNull);
        expect((await reviews.logs()).single.mode, StudyMode.listening);
      },
    );

    test('restoreCards puts a card back in its own mode', () async {
      final meaning = card(2);
      final recall = card(3, mode: StudyMode.recall);
      await reviews.saveCard(meaning);
      final service = serviceAt(start);

      await service.restoreCards([recall]);

      expect(await reviews.card(word.id, mode: StudyMode.recall), recall);
      expect(await reviews.card(word.id), meaning);
    });

    test('restoreCards skips a mode that got a new card meanwhile', () async {
      final old = card(3, mode: StudyMode.recall);
      final fresh = card(1, mode: StudyMode.recall, reviewCount: 9);
      await reviews.saveCard(fresh);

      await serviceAt(start).restoreCards([old]);

      expect(await reviews.card(word.id, mode: StudyMode.recall), fresh);
    });
  });

  group('the four-step rules in every mode', () {
    final day = start.add(const Duration(days: 30));

    /// Answers [retries] 다시 학습 then 알고있음 for [before] in [mode] and
    /// returns the stored card.
    Future<ReviewCard> play(
      StudyMode mode,
      ReviewCard? before,
      int retries,
    ) async {
      if (before != null) await reviews.saveCard(before);
      final service = serviceAt(day);
      var session = sessionOf([SessionItem(word: word, before: before)], mode);
      for (var i = 0; i < retries; i++) {
        session = await service.answer(session, Answer.retry);
      }
      await service.answer(session, Answer.known);
      return (await reviews.card(word.id, mode: mode))!;
    }

    for (final mode in StudyMode.values) {
      group(mode.name, () {
        test('new word: known at once → level 4, 21 days', () async {
          final c = await play(mode, null, 0);
          expect((c.level, c.dueAt), (4, day.add(const Duration(days: 21))));
          expect((c.reviewCount, c.lapseCount), (1, 0));
        });

        test('new word: one 다시 학습 → level 2, 3 days', () async {
          final c = await play(mode, null, 1);
          expect((c.level, c.dueAt), (2, day.add(const Duration(days: 3))));
          expect((c.reviewCount, c.lapseCount), (1, 1));
        });

        test('new word: two 다시 학습 → level 1, 30 minutes', () async {
          final c = await play(mode, null, 2);
          expect((c.level, c.dueAt), (1, day.add(const Duration(minutes: 30))));
        });

        test('review: known → one level up', () async {
          final c = await play(mode, card(2, mode: mode), 0);
          expect((c.level, c.dueAt), (3, day.add(const Duration(days: 7))));
          expect(c.reviewCount, 3);
        });

        test('review: top level stays top', () async {
          final c = await play(mode, card(4, mode: mode), 0);
          expect(c.level, 4);
        });

        test('review: one 다시 학습 → min(level, 2)', () async {
          expect((await play(mode, card(4, mode: mode), 1)).level, 2);
        });

        test('review: one 다시 학습 from level 1 stays 1', () async {
          expect((await play(mode, card(1, mode: mode), 1)).level, 1);
        });

        test('review: two 다시 학습 → level 1', () async {
          final c = await play(mode, card(3, mode: mode), 2);
          expect((c.level, c.dueAt), (1, day.add(const Duration(minutes: 30))));
          expect(c.lapseCount, 3);
        });

        test('the stored card carries the mode and scope', () async {
          final c = await play(mode, null, 0);
          expect((c.mode, c.scope, c.wordId), (mode, CardScope.shared, 'w1'));
        });
      });
    }
  });

  group('sessions carry their mode', () {
    test('today\'s session and 더 학습하기 are meaning, shared', () async {
      final service = serviceAt(start);
      final today = await service.startSession();
      expect(
        (today.mode, today.cardScope),
        (StudyMode.meaning, CardScope.shared),
      );
      await reviews.saveCard(card(2, dueIn: const Duration(days: 1)));
      final more = await service.startMoreSession();
      expect(
        (more.mode, more.cardScope),
        (StudyMode.meaning, CardScope.shared),
      );
    });

    test('every step of a session keeps mode and scope', () {
      final pl = CardScope.playlist('tb');
      final other = seedWord('w2', '語二', at: start);
      var s = sessionOf(
        [
          SessionItem(word: word, before: null),
          SessionItem(word: other, before: null),
        ],
        StudyMode.listening,
        cardScope: pl,
      );
      void check(StudySession s) =>
          expect((s.mode, s.cardScope), (StudyMode.listening, pl));
      s = s.afterRetry();
      check(s);
      final hidden = s.current!;
      s = s.afterHidden(at: start);
      check(s);
      s = s.restored(hidden);
      check(s);
      s = s.afterKnown(at: start);
      check(s);
    });

    test('a session left out of modes studies meaning', () {
      final s = StudySession(queue: const [], total: 0, startedAt: start);
      expect((s.mode, s.cardScope), (StudyMode.meaning, CardScope.shared));
    });
  });

  group('ReviewCard and ReviewLog know their mode', () {
    test('equality and hash include the mode', () {
      final a = card(2);
      final b = card(2, mode: StudyMode.choice);
      expect(a == b, isFalse);
      expect(a, card(2));
      expect(a.hashCode, card(2).hashCode);
      expect(b.copyWith(level: 3).mode, StudyMode.choice);
    });

    test('copyWith can move a card to a mode and scope', () {
      final pl = CardScope.playlist('tb');
      final moved = card(2).copyWith(mode: StudyMode.listening, scope: pl);
      expect(
        (moved.mode, moved.scope, moved.level),
        (StudyMode.listening, pl, 2),
      );
    });

    test('StudyMode has the four ways, stored by these names', () {
      expect(StudyMode.values.map((m) => m.name), [
        'meaning',
        'recall',
        'listening',
        'choice',
      ]);
    });
  });
}
