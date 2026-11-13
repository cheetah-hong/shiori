// E4: adding one word by hand (단어 추가). A new word is made and goes into
// the chosen playlist (or a new one); a word the library has already is
// linked, never made twice, with its stored content, record and hidden
// state; a word no dictionary knows is added as typed. Made-up words, a
// fixed clock.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

void main() {
  final now = DateTime(2026, 11, 14, 9);
  late InMemoryLibraryRepository repo;
  late LibraryService service;

  setUp(() async {
    repo = InMemoryLibraryRepository();
    service = LibraryService(library: repo, clock: FixedClock(now));
    await seedPlaylist(repo, 'a', [
      seedWord('w1', '試語甲', at: now, meaning: '저장된 뜻'),
    ], at: now);
    await seedPlaylist(repo, 'b', const [], at: now);
  });

  const typed = WordEdit(
    headword: ' 試語戊 ',
    readings: ['しごぼ'],
    pos: PartOfSpeech.noun,
    meaning: ' 손으로 쓴 뜻 ',
  );

  test('a new word is made and goes into the chosen playlist', () async {
    final result = await service.addWord(
      typed,
      to: const ExistingPlaylist('b'),
    );

    expect((result.added, result.linked, result.alreadyIn), (1, 0, 0));
    final inB = await repo.words(playlistId: 'b');
    expect(inB, hasLength(1));
    final w = inB.single;
    expect(
      (w.headword, w.pos, w.meaning, w.createdAt),
      ('試語戊', PartOfSpeech.noun, '손으로 쓴 뜻', now),
    );
    expect(w.readings, ['しごぼ']);
    expect(w.isHidden, isFalse);
  });

  test('into a new playlist', () async {
    final result = await service.addWord(typed, to: const NewPlaylist('새 목록'));
    expect(result.playlist.name, '새 목록');
    expect(
      (await repo.words(playlistId: result.playlist.id)).single.headword,
      '試語戊',
    );
  });

  test('a word the library has is linked, not made again', () async {
    final result = await service.addWord(
      const WordEdit(headword: '試語甲', meaning: '다른 뜻'),
      to: const ExistingPlaylist('b'),
    );

    expect((result.added, result.linked), (0, 1));
    expect((await repo.words()).where((w) => w.key == wordKey('試語甲')), [
      isA<Word>().having((w) => w.id, 'id', 'w1'),
    ]);
    final inB = (await repo.words(playlistId: 'b')).single;
    expect((inB.id, inB.meaning), ('w1', '저장된 뜻'));
  });

  test('a word the playlist holds already is counted, not added', () async {
    final result = await service.addWord(
      const WordEdit(headword: '試語甲だ', meaning: '뜻'),
      to: const ExistingPlaylist('a'),
    );
    expect((result.added, result.linked, result.alreadyIn), (0, 0, 1));
    expect(await repo.words(playlistId: 'a'), hasLength(1));
  });

  test('a hidden word linked stays hidden', () async {
    await repo.hideWords(['w1'], at: now);
    await service.addWord(
      const WordEdit(headword: '試語甲', meaning: '뜻'),
      to: const ExistingPlaylist('b'),
    );
    expect((await repo.words(playlistId: 'b')).single.isHidden, isTrue);
  });

  test('a word in kana without readings is added as typed', () async {
    await service.addWord(
      const WordEdit(headword: 'しごか', meaning: '시험 꽃'),
      to: const ExistingPlaylist('b'),
    );
    final w = (await repo.words(playlistId: 'b')).single;
    expect(w.headword, 'しごか');
    expect(w.readings, isEmpty);
  });

  test(
    'a blank meaning or a headword without kana or kanji is refused',
    () async {
      for (final bad in const [
        WordEdit(headword: '試語戊', meaning: ' '),
        WordEdit(headword: 'abc', meaning: '뜻'),
        WordEdit(headword: '', meaning: '뜻'),
      ]) {
        await expectLater(
          service.addWord(bad, to: const ExistingPlaylist('b')),
          throwsA(isA<LibraryException>()),
          reason: '$bad',
        );
      }
      expect(await repo.words(playlistId: 'b'), isEmpty);
    },
  );
}
