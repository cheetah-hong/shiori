// Sessions and counts per study mode: every mode starts with every word as a
// new word (no mode waits for another), each counts its own cards and
// presses, and the multiple-choice modes leave out words no question can be
// made for. Made-up words, a fixed clock.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

void main() {
  final start = DateTime(2026, 11, 12, 9);
  late InMemoryLibraryRepository library;
  late InMemoryReviewRepository reviews;

  StudyService serviceAt(DateTime now, {int goal = 10}) => StudyService(
    library: library,
    reviews: reviews,
    scheduler: const LeitnerFourStepScheduler(),
    clock: FixedClock(now),
    settings: StudySettings(dailyGoal: goal),
  );

  Word w(String id, String meaning, {PartOfSpeech? pos, int minutes = 0}) =>
      Word(
        id: id,
        headword: '語$id',
        readings: const ['ご'],
        meaning: meaning,
        pos: pos,
        createdAt: start.add(Duration(minutes: minutes)),
      );

  ReviewCard card(
    String id,
    StudyMode mode, {
    int level = 2,
    Duration dueIn = const Duration(days: 1),
  }) => ReviewCard(
    wordId: id,
    level: level,
    dueAt: start.add(dueIn),
    lastReviewedAt: start.subtract(const Duration(days: 2)),
    reviewCount: 1,
    mode: mode,
  );

  ReviewLog known(String id, StudyMode mode) => ReviewLog(
    wordId: id,
    answer: Answer.known,
    at: start.subtract(const Duration(hours: 1)),
    levelBefore: 0,
    levelAfter: 4,
    retriesInSession: 0,
    mode: mode,
  );

  List<String> ids(StudySession s) => [for (final i in s.queue) i.word.id];

  /// w1..w6 in tb (meanings apart), w7 in tb without a meaning, w8 in tb
  /// hidden, w9 in pl2.
  setUp(() async {
    library = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    await seedPlaylist(library, 'tb', [
      w('w1', '하나', pos: PartOfSpeech.noun, minutes: 1),
      w('w2', '둘', pos: PartOfSpeech.noun, minutes: 2),
      w('w3', '셋', pos: PartOfSpeech.verb, minutes: 3),
      w('w4', '넷', pos: PartOfSpeech.verb, minutes: 4),
      w('w5', '다섯', minutes: 5),
      w('w6', '여섯', minutes: 6),
      w('w7', '  ', minutes: 7),
      w('w8', '여덟', minutes: 8),
    ], at: start);
    await seedPlaylist(library, 'pl2', [w('w9', '아홉', minutes: 9)], at: start);
    await library.hideWords(['w8'], at: start);
  });

  group('new words: every mode on its own', () {
    test('a word studied in meaning is still new in the other modes', () async {
      for (final id in ['w1', 'w2', 'w3']) {
        await reviews.saveCard(card(id, StudyMode.meaning));
      }
      final service = serviceAt(start);
      for (final mode in [
        StudyMode.recall,
        StudyMode.listening,
        StudyMode.choice,
      ]) {
        final s = await service.startSession(mode: mode);
        expect(ids(s).take(3), ['w1', 'w2', 'w3'], reason: '$mode');
        expect(s.queue.every((i) => i.isNew), isTrue, reason: '$mode');
      }
    });

    test('meaning counts only its own cards', () async {
      for (final id in ['w1', 'w2', 'w3', 'w4', 'w5', 'w6', 'w9']) {
        await reviews.saveCard(card(id, StudyMode.recall));
        await reviews.saveCard(card(id, StudyMode.choice));
      }
      final s = await serviceAt(start).startSession();
      expect(ids(s), ['w1', 'w2', 'w3', 'w4', 'w5', 'w6', 'w7', 'w9']);
      expect(s.mode, StudyMode.meaning);
    });

    test('due cards of the mode come first, oldest due first', () async {
      await reviews.saveCard(
        card('w5', StudyMode.recall, dueIn: const Duration(hours: -2)),
      );
      await reviews.saveCard(
        card('w3', StudyMode.recall, dueIn: const Duration(hours: -5)),
      );
      // Due in meaning only: new in recall.
      await reviews.saveCard(
        card('w1', StudyMode.meaning, dueIn: const Duration(hours: -9)),
      );
      final s = await serviceAt(
        start,
        goal: 4,
      ).startSession(mode: StudyMode.recall);
      expect(ids(s), ['w3', 'w5', 'w1', 'w2']);
      expect(
        s.queue[0].before,
        card('w3', StudyMode.recall, dueIn: const Duration(hours: -5)),
      );
      expect(s.queue[2].isNew, isTrue);
    });

    test('hidden words are left out in every mode', () async {
      final service = serviceAt(start);
      for (final mode in StudyMode.values) {
        final s = await service.startSession(mode: mode);
        expect(ids(s), isNot(contains('w8')), reason: '$mode');
      }
    });
  });

  group('words a mode cannot ask', () {
    test('recall leaves out a word without a meaning', () async {
      final s = await serviceAt(start).startSession(mode: StudyMode.recall);
      expect(ids(s), ['w1', 'w2', 'w3', 'w4', 'w5', 'w6', 'w9']);
    });

    test('choice and listening leave out a word without a meaning', () async {
      final service = serviceAt(start);
      for (final mode in [StudyMode.choice, StudyMode.listening]) {
        final s = await service.startSession(mode: mode);
        expect(ids(s), ['w1', 'w2', 'w3', 'w4', 'w5', 'w6', 'w9']);
      }
    });

    test('choice leaves out a word whose meaning overlaps too many', () async {
      library = InMemoryLibraryRepository();
      await seedPlaylist(library, 'small', [
        w('a', '하나', minutes: 1),
        w('b', '둘', minutes: 2),
        w('c', '셋', minutes: 3),
        w('e', '넷', minutes: 4),
        // Overlaps a and b: only c and e can be wrong options.
        w('d', '하나, 둘', minutes: 5),
      ], at: start);
      final service = serviceAt(start);
      final s = await service.startSession(mode: StudyMode.choice);
      expect(ids(s), ['a', 'b', 'c', 'e']);
      expect((await service.summary(mode: StudyMode.choice)).newCount, 4);
      expect((await service.summary(mode: StudyMode.meaning)).newCount, 5);
    });
  });

  group('a session knows its mode and its options', () {
    test('mode, shared record, and the whole library as option pool', () async {
      final service = serviceAt(start);
      final choice = await service.startSession(
        scope: const PlaylistOnly('pl2'),
        mode: StudyMode.choice,
      );
      expect(ids(choice), ['w9']);
      expect(
        (choice.mode, choice.cardScope),
        (StudyMode.choice, CardScope.shared),
      );
      expect(
        choice.choicePool.map((x) => x.id).toSet(),
        {'w1', 'w2', 'w3', 'w4', 'w5', 'w6', 'w7', 'w8', 'w9'},
        reason: 'options come from every word, hidden ones too',
      );
      final recall = await service.startSession(mode: StudyMode.recall);
      expect(recall.mode, StudyMode.recall);
      expect(recall.choicePool, isEmpty);
      final listening = await service.startSession(mode: StudyMode.listening);
      expect(listening.choicePool, hasLength(9));
    });

    test('the question of the current card: four options, the answer '
        'among them, the same every time', () async {
      final service = serviceAt(start);
      final s = await service.startSession(mode: StudyMode.choice);
      final q = service.questionFor(s)!;
      expect(q.answer.id, 'w1');
      expect(q.options, hasLength(4));
      expect(q.options[q.answerIndex].id, 'w1');
      expect(
        service.questionFor(s)!.options.map((o) => o.id),
        q.options.map((o) => o.id),
      );
      final expected = const ChoiceMaker().make(
        answer: s.current!.word,
        pool: s.choicePool,
        seed: choiceSeed(sessionStart: s.startedAt, wordId: 'w1', retries: 0),
      )!;
      expect(q.options.map((o) => o.id), expected.options.map((o) => o.id));
    });

    test('a card back after 다시 학습 gets the seed of its retry', () async {
      final service = serviceAt(start, goal: 1);
      var s = await service.startSession(mode: StudyMode.listening);
      s = await service.answer(s, Answer.retry);
      expect(s.current!.retries, 1);
      final expected = const ChoiceMaker().make(
        answer: s.current!.word,
        pool: s.choicePool,
        seed: choiceSeed(sessionStart: s.startedAt, wordId: 'w1', retries: 1),
      )!;
      expect(
        service.questionFor(s)!.options.map((o) => o.id),
        expected.options.map((o) => o.id),
      );
    });

    test('no question in the other modes or when finished', () async {
      final service = serviceAt(start, goal: 1);
      expect(service.questionFor(await service.startSession()), isNull);
      expect(
        service.questionFor(await service.startSession(mode: StudyMode.recall)),
        isNull,
      );
      var s = await service.startSession(mode: StudyMode.choice);
      s = await service.answer(s, Answer.known);
      expect(s.isFinished, isTrue);
      expect(service.questionFor(s), isNull);
    });

    test('a right pick is 알고있음, a wrong one 다시 학습, in that mode', () async {
      final service = serviceAt(start, goal: 2);
      var s = await service.startSession(mode: StudyMode.choice);
      s = await service.answer(s, Answer.known);
      s = await service.answer(s, Answer.retry);
      final w1 = await reviews.card('w1', mode: StudyMode.choice);
      final w2 = await reviews.card('w2', mode: StudyMode.choice);
      expect((w1!.level, w1.dueAt), (4, start.add(const Duration(days: 21))));
      expect((w2!.level, w2.dueAt), (1, start));
      expect(await reviews.cards(), isEmpty);
      expect(ids(s), ['w2']);
    });
  });

  group('more study per mode', () {
    test('only the mode\'s cards whose time has not come', () async {
      await reviews.saveCard(card('w1', StudyMode.listening, level: 3));
      await reviews.saveCard(card('w2', StudyMode.listening, level: 1));
      await reviews.saveCard(card('w3', StudyMode.meaning, level: 1));
      await reviews.saveCard(
        card('w4', StudyMode.listening, dueIn: const Duration(hours: -1)),
      );
      final s = await serviceAt(
        start,
      ).startMoreSession(mode: StudyMode.listening);
      expect(ids(s), ['w2', 'w1']);
      expect(s.mode, StudyMode.listening);
      expect(s.queue.every((i) => i.ahead), isTrue);
      expect(s.choicePool, hasLength(9));
    });
  });

  group('summary per mode', () {
    test('due, new, ahead and known today are the mode\'s own', () async {
      await reviews.saveCard(
        card('w1', StudyMode.recall, dueIn: const Duration(hours: -1)),
      );
      await reviews.saveCard(card('w2', StudyMode.recall));
      await reviews.saveCard(card('w3', StudyMode.meaning));
      await reviews.addLog(known('w1', StudyMode.recall));
      await reviews.addLog(known('w2', StudyMode.recall));
      await reviews.addLog(known('w3', StudyMode.meaning));
      final service = serviceAt(start);

      final recall = await service.summary(mode: StudyMode.recall);
      expect((recall.dueCount, recall.newCount, recall.aheadCount), (1, 5, 1));
      expect(recall.knownToday, 2);
      expect((recall.wordCount, recall.hiddenCount), (9, 1));

      final meaning = await service.summary();
      expect(
        (meaning.dueCount, meaning.newCount, meaning.aheadCount),
        (0, 7, 1),
      );
      expect(meaning.knownToday, 1);

      final choice = await service.summary(mode: StudyMode.choice);
      expect((choice.dueCount, choice.newCount, choice.knownToday), (0, 7, 0));
    });

    test('a playlist summary in a mode', () async {
      await reviews.saveCard(card('w9', StudyMode.choice));
      final s = await serviceAt(
        start,
      ).summary(scope: const PlaylistOnly('pl2'), mode: StudyMode.choice);
      expect((s.newCount, s.aheadCount, s.wordCount), (0, 1, 1));
    });
  });

  group('which modes can be picked', () {
    test('every mode with speech and four words apart', () async {
      expect(
        await serviceAt(start).availableModes(speechAvailable: true),
        StudyMode.values.toSet(),
      );
    });

    test('no speech: no listening', () async {
      expect(await serviceAt(start).availableModes(speechAvailable: false), {
        StudyMode.meaning,
        StudyMode.recall,
        StudyMode.choice,
      });
    });

    test('fewer than four words apart: no choice, no listening', () async {
      library = InMemoryLibraryRepository();
      await seedPlaylist(library, 'small', [
        w('a', '하나'),
        w('b', '둘'),
        w('c', '셋'),
        w('d', '하나'),
        w('e', ''),
      ], at: start);
      expect(await serviceAt(start).availableModes(speechAvailable: true), {
        StudyMode.meaning,
        StudyMode.recall,
      });
    });

    test('an empty library: meaning and recall only', () async {
      library = InMemoryLibraryRepository();
      expect(await serviceAt(start).availableModes(speechAvailable: true), {
        StudyMode.meaning,
        StudyMode.recall,
      });
    });
  });

  group('cards by mode', () {
    test('every mode is listed, with the cards of the words asked', () async {
      await reviews.saveCard(card('w1', StudyMode.meaning, level: 3));
      await reviews.saveCard(card('w1', StudyMode.choice, level: 1));
      await reviews.saveCard(card('w2', StudyMode.listening, level: 4));
      final all = await serviceAt(start).cardsByMode();
      expect(all.keys.toSet(), StudyMode.values.toSet());
      expect(all[StudyMode.meaning]!['w1']!.level, 3);
      expect(all[StudyMode.choice]!['w1']!.level, 1);
      expect(all[StudyMode.listening]!.keys, ['w2']);
      expect(all[StudyMode.recall], isEmpty);
      final some = await serviceAt(start).cardsByMode(wordIds: ['w2']);
      expect(some[StudyMode.meaning], isEmpty);
      expect(some[StudyMode.listening]!.keys, ['w2']);
    });
  });

  test('isMultipleChoice: choice and listening', () {
    expect(
      [
        for (final m in StudyMode.values)
          if (m.isMultipleChoice) m,
      ],
      [StudyMode.listening, StudyMode.choice],
    );
  });
}
