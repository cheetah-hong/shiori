// Session size (a playlist studies every card, 전체 follows the daily goal)
// and the shuffled card order.
import 'dart:math';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

void main() {
  final start = DateTime(2026, 11, 6, 15);
  late InMemoryLibraryRepository library;
  late InMemoryReviewRepository reviews;

  StudyService serviceAt(DateTime now, {Random Function()? random}) =>
      StudyService(
        library: library,
        reviews: reviews,
        scheduler: const LeitnerFourStepScheduler(),
        clock: FixedClock(now),
        random: random,
      );

  Word word(String id, int n, {String meaning = '뜻', DateTime? hiddenAt}) =>
      seedWord(
        id,
        '語$n',
        at: start.add(Duration(seconds: n)),
        meaning: meaning,
        hiddenAt: hiddenAt,
      );

  ReviewCard dueCard(String id, int hoursAgo) => ReviewCard(
    wordId: id,
    level: 2,
    dueAt: start.subtract(Duration(hours: hoursAgo)),
    lastReviewedAt: start.subtract(const Duration(days: 3)),
  );

  ReviewCard laterCard(String id, {int level = 2, int days = 1}) => ReviewCard(
    wordId: id,
    level: level,
    dueAt: start.add(Duration(days: days)),
    lastReviewedAt: start,
  );

  List<String> ids(StudySession s) => [for (final i in s.queue) i.word.id];

  group('SessionSize', () {
    test('UpTo takes at most its cards, AllCards takes every card', () {
      expect(const UpTo(10).of(3), 3);
      expect(const UpTo(10).of(30), 10);
      expect(const UpTo(10).of(0), 0);
      expect(const AllCards().of(0), 0);
      expect(const AllCards().of(345), 345);
    });

    test('daily goals: 10 · 20 · 30 · 50 · 전부, 10 by default', () {
      expect(DailyGoal.values.map((g) => g.cards), [10, 20, 30, 50, null]);
      expect(DailyGoal.values.map((g) => g.storedAs), [
        '10',
        '20',
        '30',
        '50',
        'all',
      ]);
      expect(const StudyPreferences().dailyGoal, DailyGoal.ten);
      expect(const StudyPreferences().shuffle, isTrue);
      expect(DailyGoal.thirty.size.of(100), 30);
      expect(DailyGoal.all.size.of(100), 100);
      expect(DailyGoal.fromStored('50'), DailyGoal.fifty);
      expect(DailyGoal.fromStored('15'), isNull);
      expect(DailyGoal.fromStored(''), isNull);
    });
  });

  group('S1 a playlist studies every card', () {
    // A: 7 due (d0..d6), 25 new (n0..n24), 2 hidden (h0 with a due card,
    // h1 new), 3 waiting (l0..l2). B only: 5 words (b0, b1 due).
    setUp(() async {
      library = InMemoryLibraryRepository();
      reviews = InMemoryReviewRepository();
      await seedPlaylist(library, 'A', [
        for (var i = 0; i < 7; i++) word('d$i', i),
        for (var i = 0; i < 25; i++)
          word('n$i', 10 + i, meaning: i == 24 ? '' : '뜻$i'),
        word('h0', 40, hiddenAt: start),
        word('h1', 41, hiddenAt: start),
        for (var i = 0; i < 3; i++) word('l$i', 50 + i),
      ], at: start);
      await seedPlaylist(library, 'B', [
        for (var i = 0; i < 5; i++) word('b$i', 60 + i),
      ], at: start);
      for (var i = 0; i < 7; i++) {
        await reviews.saveCard(dueCard('d$i', 10 - i));
      }
      await reviews.saveCard(dueCard('h0', 2));
      for (var i = 0; i < 3; i++) {
        await reviews.saveCard(laterCard('l$i'));
      }
      await reviews.saveCard(dueCard('b0', 1));
      await reviews.saveCard(dueCard('b1', 1));
      await library.hideWords(['h0', 'h1'], at: start);
    });

    test('7 due + 25 new = 32 cards, whatever the daily goal', () async {
      final service = serviceAt(start);
      const scope = PlaylistOnly('A');
      for (final goal in DailyGoal.values) {
        final size = service.sessionSizeFor(scope, goal);
        expect(size, isA<AllCards>(), reason: '$goal');
        final s = await service.startSession(scope: scope, size: size);
        expect(s.total, 32, reason: '$goal');
        expect(ids(s), [
          for (var i = 0; i < 7; i++) 'd$i',
          for (var i = 0; i < 25; i++) 'n$i',
        ]);
      }
    });

    test('in the chosen mode: 일본어 떠올리기 leaves out the word without a '
        'meaning', () async {
      final service = serviceAt(start);
      const scope = PlaylistOnly('A');
      final s = await service.startSession(
        scope: scope,
        mode: StudyMode.recall,
        size: service.sessionSizeFor(scope, DailyGoal.ten),
      );
      // No recall card yet: every shown word is new in this mode (7 + 25 +
      // 3 waiting), less n24.
      expect(s.total, 34);
      expect(ids(s), isNot(contains('n24')));
      expect(ids(s).where((id) => id.startsWith('h')), isEmpty);
      expect(ids(s).where((id) => id.startsWith('b')), isEmpty);
    });

    test('더 학습하기 in a playlist: every waiting card of it', () async {
      final service = serviceAt(start);
      const scope = PlaylistOnly('A');
      await reviews.saveCard(laterCard('b2'));
      final s = await service.startMoreSession(
        scope: scope,
        size: service.sessionSizeFor(scope, DailyGoal.ten),
      );
      expect(ids(s), ['l0', 'l1', 'l2']);
      expect(s.queue.every((i) => i.ahead), isTrue);
    });
  });

  group('S2·S3 전체 follows the daily goal', () {
    // 40 cards to study: 4 due (d0..d3) + 36 new (n0..n35); 25 waiting
    // (w0..w24) in another playlist.
    setUp(() async {
      library = InMemoryLibraryRepository();
      reviews = InMemoryReviewRepository();
      await seedPlaylist(library, 'A', [
        for (var i = 0; i < 4; i++) word('d$i', i),
        for (var i = 0; i < 36; i++) word('n$i', 10 + i),
      ], at: start);
      await seedPlaylist(library, 'B', [
        for (var i = 0; i < 25; i++) word('w$i', 100 + i),
      ], at: start);
      for (var i = 0; i < 4; i++) {
        await reviews.saveCard(dueCard('d$i', 5 - i));
      }
      for (var i = 0; i < 25; i++) {
        await reviews.saveCard(laterCard('w$i', level: 1 + i % 4, days: i + 1));
      }
    });

    test('10 · 20 · 30 · 50 · 전부 → 10 · 20 · 30 · 40 · 40', () async {
      final service = serviceAt(start);
      const scope = AllWords();
      final totals = [
        for (final goal in DailyGoal.values)
          (await service.startSession(
            scope: scope,
            size: service.sessionSizeFor(scope, goal),
          )).total,
      ];
      expect(totals, [10, 20, 30, 40, 40]);
    });

    test('reviews come first, then new words', () async {
      final service = serviceAt(start);
      final s = await service.startSession(
        size: service.sessionSizeFor(const AllWords(), DailyGoal.ten),
      );
      expect(ids(s), [
        'd0',
        'd1',
        'd2',
        'd3',
        for (var i = 0; i < 6; i++) 'n$i',
      ]);
    });

    test('no size given: StudySettings.dailyGoal, as before', () async {
      expect((await serviceAt(start).startSession()).total, 10);
    });

    test('7 cards to study: every goal gives 7', () async {
      library = InMemoryLibraryRepository();
      reviews = InMemoryReviewRepository();
      await seedPlaylist(library, 'A', [
        for (var i = 0; i < 7; i++) word('n$i', i),
      ], at: start);
      final service = serviceAt(start);
      for (final goal in DailyGoal.values) {
        final s = await service.startSession(
          size: service.sessionSizeFor(const AllWords(), goal),
        );
        expect(s.total, 7, reason: '$goal');
      }
    });

    test('더 학습하기 in 전체: as many as the daily goal', () async {
      final service = serviceAt(start);
      const scope = AllWords();
      final twenty = await service.startMoreSession(
        scope: scope,
        size: service.sessionSizeFor(scope, DailyGoal.twenty),
      );
      expect(twenty.total, 20);
      final all = await service.startMoreSession(
        scope: scope,
        size: service.sessionSizeFor(scope, DailyGoal.all),
      );
      expect(all.total, 25);
    });
  });

  group('S4 shuffled order', () {
    // 4 due (d0..d3) + 20 new (n0..n19), 6 waiting (w0..w5).
    setUp(() async {
      library = InMemoryLibraryRepository();
      reviews = InMemoryReviewRepository();
      await seedPlaylist(library, 'A', [
        for (var i = 0; i < 4; i++) word('d$i', i),
        for (var i = 0; i < 20; i++) word('n$i', 10 + i),
        for (var i = 0; i < 6; i++) word('w$i', 40 + i),
      ], at: start);
      for (var i = 0; i < 4; i++) {
        await reviews.saveCard(dueCard('d$i', 5 - i));
      }
      for (var i = 0; i < 6; i++) {
        await reviews.saveCard(laterCard('w$i', level: 4 - i % 3, days: i + 1));
      }
    });

    Future<StudySession> startWith(
      int? seed, {
      bool shuffle = true,
      bool more = false,
    }) {
      final service = serviceAt(
        start,
        random: seed == null ? null : () => Random(seed),
      );
      const scope = PlaylistOnly('A');
      final size = service.sessionSizeFor(scope, DailyGoal.ten);
      return more
          ? service.startMoreSession(scope: scope, size: size, shuffle: shuffle)
          : service.startSession(scope: scope, size: size, shuffle: shuffle);
    }

    test('the seed changes the order, never the cards', () async {
      final plain = ids(await startWith(1, shuffle: false));
      final one = ids(await startWith(1));
      final two = ids(await startWith(2));
      expect(one, isNot(plain));
      expect(two, isNot(plain));
      expect(one, isNot(two));
      expect(one.toSet(), plain.toSet());
      expect(two.toSet(), plain.toSet());
      expect(one, hasLength(plain.length));
      expect(ids(await startWith(1)), one, reason: 'same seed, same order');
    });

    test('off: the order of today, card for card', () async {
      final s = await startWith(1, shuffle: false);
      expect(ids(s), [
        for (var i = 0; i < 4; i++) 'd$i',
        for (var i = 0; i < 20; i++) 'n$i',
      ]);
      expect(s.queue.take(4).every((i) => i.before != null), isTrue);
      expect(s.queue.skip(4).every((i) => i.isNew), isTrue);
      final more = await startWith(1, shuffle: false, more: true);
      // Lowest level first, then the earliest review.
      expect(ids(more), ['w2', 'w5', 'w1', 'w4', 'w0', 'w3']);
      expect(more.queue.every((i) => i.ahead), isTrue);
    });

    test('off is the default of the service', () async {
      final service = serviceAt(start, random: () => Random(1));
      expect(
        ids(
          await service.startSession(
            scope: const PlaylistOnly('A'),
            size: const AllCards(),
          ),
        ),
        ids(await startWith(1, shuffle: false)),
      );
    });

    test('더 학습하기 is shuffled too', () async {
      final plain = ids(await startWith(3, shuffle: false, more: true));
      final mixed = await startWith(3, more: true);
      expect(ids(mixed).toSet(), plain.toSet());
      expect(ids(mixed), isNot(plain));
      expect(mixed.queue.every((i) => i.ahead), isTrue);
    });

    test(
      'with a daily goal the same cards are picked, due reviews kept',
      () async {
        final service = serviceAt(start, random: () => Random(5));
        final plain = await service.startSession(size: const UpTo(10));
        final mixed = await service.startSession(
          size: const UpTo(10),
          shuffle: true,
        );
        expect(ids(mixed).toSet(), ids(plain).toSet());
        expect(ids(mixed), containsAll(['d0', 'd1', 'd2', 'd3']));
        expect(mixed.total, 10);
      },
    );
  });

  group('S7 the session rules stay', () {
    setUp(() async {
      library = InMemoryLibraryRepository();
      reviews = InMemoryReviewRepository();
      await seedPlaylist(library, 'A', [
        for (var i = 0; i < 2; i++) word('d$i', i),
        for (var i = 0; i < 6; i++) word('n$i', 10 + i),
        word('w0', 30),
      ], at: start);
      await reviews.saveCard(dueCard('d0', 3));
      await reviews.saveCard(dueCard('d1', 2));
      await reviews.saveCard(laterCard('w0', level: 3, days: 4));
    });

    test('다시 학습 sends the card to the back of a shuffled session', () async {
      final service = serviceAt(start, random: () => Random(9));
      var s = await service.startSession(
        scope: const PlaylistOnly('A'),
        mode: StudyMode.recall,
        size: const AllCards(),
        shuffle: true,
      );
      final first = s.current!.word.id;
      final total = s.total;
      s = await service.answer(s, Answer.retry);
      expect(s.queue.last.word.id, first);
      expect(s.queue.last.retries, 1);
      expect((s.knownCount, s.total), (0, total));
      final log = await reviews.logs(
        since: start.subtract(const Duration(days: 1)),
        mode: StudyMode.recall,
      );
      expect(log.single.wordId, first);
      expect(log.single.mode, StudyMode.recall);
    });

    test('the scheduler gives the same card shuffled or not', () async {
      final mixed = serviceAt(start, random: () => Random(4));
      var s = await mixed.startSession(
        scope: const PlaylistOnly('A'),
        size: const AllCards(),
        shuffle: true,
      );
      final cards = <String, ReviewCard?>{};
      while (!s.isFinished) {
        final id = s.current!.word.id;
        s = await mixed.answer(s, Answer.known);
        cards[id] = await reviews.card(id);
      }
      // New known at once: level 4 in 21 days; a due review: one level up.
      for (final id in [for (var i = 0; i < 6; i++) 'n$i']) {
        expect(cards[id]!.level, 4, reason: id);
        expect(cards[id]!.dueAt, start.add(const Duration(days: 21)));
      }
      expect(cards['d0']!.level, 3);
      expect(cards['d0']!.dueAt, start.add(const Duration(days: 7)));
    });

    test('a card brought forward stays as it was on 알고있음, shuffled', () async {
      final service = serviceAt(start, random: () => Random(2));
      final before = await reviews.card('w0');
      var s = await service.startMoreSession(
        scope: const PlaylistOnly('A'),
        size: const AllCards(),
        shuffle: true,
      );
      expect(ids(s), ['w0']);
      s = await service.answer(s, Answer.known);
      expect(await reviews.card('w0'), before);
    });
  });

  test('a large session: 3000 cards built and answered', () async {
    library = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    await seedPlaylist(library, 'A', [
      for (var i = 0; i < 3000; i++) word('n$i', i),
    ], at: start);
    final service = serviceAt(start, random: () => Random(1));
    var s = await service.startSession(
      scope: const PlaylistOnly('A'),
      size: const AllCards(),
      shuffle: true,
    );
    expect(s.total, 3000);
    while (!s.isFinished) {
      s = s.afterKnown(at: start);
    }
    expect(s.knownCount, 3000);
  });
}
