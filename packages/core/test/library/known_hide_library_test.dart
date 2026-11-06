// Hiding words (LibraryService) and what the models say about hidden words.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

void main() {
  final now = DateTime(2026, 11, 5, 21);
  late InMemoryLibraryRepository repo;
  late LibraryService service;

  setUp(() async {
    repo = InMemoryLibraryRepository();
    service = LibraryService(library: repo, clock: FixedClock(now));
  });

  test(
    'hideWords and unhideWords use the clock and the library block',
    () async {
      expect(service.hidden, same(repo));
      await seedPlaylist(repo, 'pl', [
        seedWord('w1', '雨', at: now),
        seedWord('w2', '雪', at: now),
      ], at: now);
      await service.hideWords(['w2']);
      expect((await repo.word('w2'))?.hiddenAt, now);
      await service.unhideWords(['w2']);
      expect((await repo.word('w2'))?.isHidden, isFalse);
    },
  );

  test('an unknown word id is reported, not skipped', () async {
    await expectLater(
      service.hideWords(['nope']),
      throwsA(isA<WordNotFoundException>()),
    );
    await expectLater(
      service.unhideWords(['nope']),
      throwsA(isA<WordNotFoundException>()),
    );
  });

  group('models', () {
    Word w({DateTime? hiddenAt}) => Word(
      id: 'w',
      headword: '雨',
      readings: const ['あめ'],
      meaning: '비',
      createdAt: now,
      hiddenAt: hiddenAt,
    );

    test('Word tells hidden from shown and compares the time', () {
      expect(w().isHidden, isFalse);
      expect(w(hiddenAt: now).isHidden, isTrue);
      expect(w(hiddenAt: now), w(hiddenAt: now));
      expect(w(hiddenAt: now).hashCode, w(hiddenAt: now).hashCode);
      expect(w(hiddenAt: now), isNot(w()));
      expect(w().withHiddenAt(now), w(hiddenAt: now));
      expect(w(hiddenAt: now).withHiddenAt(null), w());
      expect(w(hiddenAt: now).toString(), contains('hidden'));
    });

    test('PlaylistStats counts hidden words apart', () {
      final list = Playlist(id: 'a', name: 'A', createdAt: now, position: 0);
      PlaylistStats s({int hidden = 1}) =>
          PlaylistStats(playlist: list, wordCount: 5, hiddenCount: hidden);
      expect(s().shownCount, 4);
      expect(s(), s());
      expect(s().hashCode, s().hashCode);
      expect(s(), isNot(s(hidden: 2)));
      expect(PlaylistStats(playlist: list, wordCount: 2).hiddenCount, 0);
      expect(s().toString(), contains('hidden: 1'));
    });

    test('WordNotFoundException names the ids', () {
      expect(
        const WordNotFoundException(['a', 'b']).toString(),
        allOf(contains('a'), contains('b')),
      );
    });
  });
}
