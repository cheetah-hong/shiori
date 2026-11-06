// Study scopes: 전체 (every word in some playlist) and one playlist, with the
// learning record shared between playlists.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

void main() {
  final start = DateTime(2026, 11, 6, 15);
  late InMemoryLibraryRepository library;
  late InMemoryReviewRepository reviews;

  StudyService serviceAt(
    DateTime now, {
    StudyPreferences preferences = const StudyPreferences(),
  }) => StudyService(
    library: library,
    reviews: reviews,
    scheduler: const LeitnerFourStepScheduler(),
    clock: FixedClock(now),
    settings: const StudySettings(dailyGoal: 20),
    preferences: preferences,
  );

  ReviewCard dueCard(String id, {Duration ago = const Duration(hours: 1)}) =>
      ReviewCard(
        wordId: id,
        level: 2,
        dueAt: start.subtract(ago),
        lastReviewedAt: start.subtract(const Duration(days: 3)),
      );

  ReviewCard laterCard(String id) => ReviewCard(
    wordId: id,
    level: 3,
    dueAt: start.add(const Duration(days: 5)),
    lastReviewedAt: start,
  );

  // A: 雨 雪 空 海, B: 空 山 川. 空 is in both.
  setUp(() async {
    library = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    await seedPlaylist(library, 'A', [
      seedWord('rain', '雨', at: start),
      seedWord('snow', '雪', at: start),
      seedWord('sky', '空', at: start),
      seedWord('sea', '海', at: start),
    ], at: start);
    await seedPlaylist(library, 'B', [
      seedWord('sky', '空', at: start),
      seedWord('hill', '山', at: start.add(const Duration(seconds: 1))),
      seedWord('river', '川', at: start.add(const Duration(seconds: 1))),
    ], at: start);
    await reviews.saveCard(dueCard('rain', ago: const Duration(hours: 2)));
    await reviews.saveCard(dueCard('sky'));
    await reviews.saveCard(laterCard('hill'));
  });

  test(
    '전체: due reviews and new words of every playlist, each word once',
    () async {
      final service = serviceAt(start);
      final summary = await service.summary();
      expect(
        (summary.dueCount, summary.newCount, summary.wordCount),
        (2, 3, 6),
      );
      final session = await service.startSession();
      expect(session.queue.map((i) => (i.word.id, i.isNew)), [
        ('rain', false),
        ('sky', false),
        // New words oldest first, then by id.
        ('sea', true),
        ('snow', true),
        ('river', true),
      ]);
    },
  );

  test('one playlist: only its words, with the shared cards', () async {
    final service = serviceAt(start);
    final b = await service.summary(scope: const PlaylistOnly('B'));
    expect((b.dueCount, b.newCount, b.wordCount), (1, 1, 3));
    final session = await service.startSession(scope: const PlaylistOnly('B'));
    expect(session.queue.map((i) => (i.word.id, i.isNew)), [
      ('sky', false),
      ('river', true),
    ]);
    expect(session.queue.first.before, dueCard('sky'));
  });

  test('a hidden word is left out of both scopes', () async {
    await library.hideWords(['sky', 'river'], at: start);
    final service = serviceAt(start);
    final all = await service.summary();
    expect((all.dueCount, all.newCount, all.hiddenCount), (1, 2, 2));
    final b = await service.summary(scope: const PlaylistOnly('B'));
    expect((b.dueCount, b.newCount, b.hiddenCount), (0, 0, 2));
    expect((await service.startSession()).queue.map((i) => i.word.id), [
      'rain',
      'sea',
      'snow',
    ]);
    expect(
      (await service.startSession(scope: const PlaylistOnly('B'))).queue,
      isEmpty,
    );
  });

  test('a word studied in one playlist is studied in the other', () async {
    final service = serviceAt(start);
    var session = await service.startSession(scope: const PlaylistOnly('B'));
    expect(session.current?.word.id, 'sky');
    session = await service.answer(session, Answer.known);

    final card = await reviews.card('sky');
    expect(card?.level, 3);
    expect(card?.scope, CardScope.shared);
    final a = await service.summary(scope: const PlaylistOnly('A'));
    expect(a.dueCount, 1, reason: '空 is no longer due in A either');
    expect(a.knownToday, 1, reason: 'the press counts in A too');
    expect((await service.summary()).knownToday, 1);
    expect((await reviews.cards()).keys.toSet(), {
      'rain',
      'sky',
      'hill',
    }, reason: 'one card per word');
  });

  test(
    'a word taken out of a playlist leaves its scope; the card stays',
    () async {
      await library.removeFromPlaylist('B', ['sky']);
      final service = serviceAt(start);
      expect(
        (await service.startSession(
          scope: const PlaylistOnly('B'),
        )).queue.map((i) => i.word.id),
        ['river'],
      );
      expect(
        (await service.summary()).dueCount,
        2,
        reason: 'still in A, still due',
      );
      await library.removeFromPlaylist('A', ['sky']);
      expect((await service.summary()).dueCount, 1, reason: 'in no playlist');
      expect(await reviews.card('sky'), dueCard('sky'));
    },
  );

  test('a deleted playlist\'s only words leave 전체; their cards stay', () async {
    await library.deletePlaylist('B');
    final service = serviceAt(start);
    final all = await service.summary();
    expect((all.dueCount, all.newCount, all.wordCount), (2, 2, 4));
    expect(await reviews.card('hill'), laterCard('hill'));
  });

  test('an unknown playlist has nothing to study', () async {
    final service = serviceAt(start);
    final summary = await service.summary(scope: const PlaylistOnly('gone'));
    expect((summary.dueCount, summary.newCount, summary.wordCount), (0, 0, 0));
    expect(
      (await service.startSession(scope: const PlaylistOnly('gone'))).queue,
      isEmpty,
    );
  });

  test(
    'a stored per-playlist setting still studies the shared record (준비 중)',
    () async {
      final service = serviceAt(
        start,
        preferences: const StudyPreferences(recordMode: RecordMode.perPlaylist),
      );
      expect(service.cardScopeFor(const PlaylistOnly('B')), CardScope.shared);
      expect(service.cardScopeFor(const AllWords()), CardScope.shared);
      final session = await service.startSession(
        scope: const PlaylistOnly('B'),
      );
      await service.answer(session, Answer.known);
      expect((await reviews.card('sky'))?.level, 3);
      expect(await reviews.cards(scope: CardScope.playlist('B')), isEmpty);
      expect((await reviews.logs()).single.scope, CardScope.shared);
    },
  );

  test('retry stores the shared card too', () async {
    final service = serviceAt(start);
    final session = await service.startSession(scope: const PlaylistOnly('A'));
    await service.answer(session, Answer.retry);
    final logs = await reviews.logs(scope: CardScope.shared);
    expect(logs.single.answer, Answer.retry);
    expect((await reviews.card('rain'))?.scope, CardScope.shared);
  });

  test('scopes compare by value', () {
    expect(const PlaylistOnly('A'), const PlaylistOnly('A'));
    expect(const PlaylistOnly('A').hashCode, const PlaylistOnly('A').hashCode);
    expect(const PlaylistOnly('A'), isNot(const PlaylistOnly('B')));
    expect(const AllWords(), const AllWords());
    expect(const AllWords().hashCode, const AllWords().hashCode);
    expect(const AllWords(), isNot(const PlaylistOnly('A')));
  });
}
