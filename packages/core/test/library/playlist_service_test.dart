// Playlists (LibraryService): making, renaming, ordering and deleting them,
// adding a reviewed draft to one, taking words out.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

void main() {
  final now = DateTime(2026, 11, 6, 15);
  late InMemoryLibraryRepository repo;
  late InMemoryReviewRepository reviews;
  late FixedClock clock;
  late LibraryService service;

  CapturedEntry entry(
    String head, {
    bool included = true,
    String meaning = '뜻',
    List<String> readings = const ['よみ'],
  }) => CapturedEntry(
    headword: head,
    readings: readings,
    pos: PartOfSpeech.noun,
    meaning: meaning,
    included: included,
  );

  CaptureDraft draft(List<String> heads) =>
      CaptureDraft(entries: [for (final h in heads) entry(h)]);

  /// Twelve made-up words, in the order the photo shows them.
  const twelve = [
    '雨', '雪', '空', '海', '山', '川', '朝', '昼', '夜', '春', '夏', '秋', //
  ];

  setUp(() {
    repo = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    clock = FixedClock(now);
    service = LibraryService(library: repo, clock: clock);
  });

  group('making playlists', () {
    test('a new playlist has the trimmed name and goes last', () async {
      final a = await service.createPlaylist('  N5 동사 ');
      final b = await service.createPlaylist('N5 명사');
      expect((a.name, a.createdAt, a.position), ('N5 동사', now, 0));
      expect(b.position, 1);
      expect(a.id, isNot(b.id));
      expect(await repo.playlists(), [a, b]);
    });

    test('a blank name is refused', () async {
      await expectLater(
        service.createPlaylist('  '),
        throwsA(
          isA<LibraryException>().having(
            (e) => e.message,
            'message',
            '재생목록 이름이 비어 있어요',
          ),
        ),
      );
      expect(await repo.playlists(), isEmpty);
    });

    test(
      'a name another playlist has is refused, ignoring spaces, case and width',
      () async {
        await service.createPlaylist('JLPT N5');
        for (final same in ['JLPT N5', ' jlpt n5 ', 'ＪＬＰＴ　Ｎ５']) {
          await expectLater(
            service.createPlaylist(same),
            throwsA(
              isA<LibraryException>().having(
                (e) => e.message,
                'message',
                '같은 이름의 재생목록이 있어요',
              ),
            ),
            reason: same,
          );
        }
        expect(await repo.playlists(), hasLength(1));
      },
    );

    test(
      'renaming keeps id, time and place; the same name is refused',
      () async {
        final a = await service.createPlaylist('A');
        await service.createPlaylist('B');
        final renamed = await service.renamePlaylist(a.id, ' 가 ');
        expect(renamed, a.copyWith(name: '가'));
        expect(await repo.playlist(a.id), renamed);
        expect(
          await service.renamePlaylist(a.id, '가'),
          renamed,
          reason: 'its own name is not taken',
        );
        await expectLater(
          service.renamePlaylist(a.id, 'b'),
          throwsA(isA<LibraryException>()),
        );
        await expectLater(
          service.renamePlaylist(a.id, ''),
          throwsA(isA<LibraryException>()),
        );
        await expectLater(
          service.renamePlaylist('missing', 'C'),
          throwsA(isA<LibraryException>()),
        );
      },
    );

    test('reordering puts the playlists in the given order', () async {
      final a = await service.createPlaylist('A');
      final b = await service.createPlaylist('B');
      final c = await service.createPlaylist('C');
      await service.reorderPlaylists([c.id, a.id, b.id]);
      expect((await repo.playlists()).map((p) => (p.name, p.position)), [
        ('C', 0),
        ('A', 1),
        ('B', 2),
      ]);
      expect(
        () => service.reorderPlaylists([a.id, b.id]),
        throwsArgumentError,
        reason: 'every playlist once',
      );
      expect(
        () => service.reorderPlaylists([a.id, a.id, b.id]),
        throwsArgumentError,
      );
    });
  });

  group('adding a draft', () {
    test('adds the included words in the photo\'s order', () async {
      final result = await service.addDraft(
        CaptureDraft(
          entries: [entry('雨'), entry('雪', included: false), entry('空')],
        ),
        to: const NewPlaylist('내 단어장'),
      );
      expect(
        (result.added, result.linked, result.alreadyIn, result.skipped),
        (2, 0, 0, 1),
      );
      expect(result.playlist.name, '내 단어장');
      final words = await repo.words(playlistId: result.playlist.id);
      expect(words.map((w) => w.headword), ['雨', '空']);
      expect(words.map((w) => w.createdAt).toSet(), {now});
    });

    test('a page of twelve words reads back in the photo\'s order', () async {
      final result = await service.addDraft(
        draft(twelve),
        to: const NewPlaylist('A'),
      );
      final words = await repo.words(playlistId: result.playlist.id);
      expect(words.map((w) => w.headword), twelve);
      expect(
        (await repo.words()).map((w) => w.headword),
        twelve,
        reason: 'every listed word, oldest first, in the save\'s order',
      );
    });

    test(
      'the same word twice in one playlist is kept once (이미 있음 1)',
      () async {
        final list = await service.createPlaylist('A');
        await service.addDraft(
          draft(['雨', '雪']),
          to: ExistingPlaylist(list.id),
        );
        final again = await service.addDraft(
          draft(['雨', '空']),
          to: ExistingPlaylist(list.id),
        );
        expect((again.added, again.linked, again.alreadyIn), (1, 0, 1));
        expect((await repo.words(playlistId: list.id)).map((w) => w.headword), [
          '雨',
          '雪',
          '空',
        ]);
      },
    );

    test('a word twice in one draft is added once', () async {
      final result = await service.addDraft(
        draft(['雨', '雪', '雨']),
        to: const NewPlaylist('A'),
      );
      expect((result.added, result.alreadyIn), (2, 1));
      expect((await repo.words(playlistId: result.playlist.id)).length, 2);
    });

    test(
      'a word another playlist holds is linked: one word, one record',
      () async {
        final a = await service.addDraft(
          draft(['雨', '雪']),
          to: const NewPlaylist('A'),
        );
        final rain = (await repo.words(playlistId: a.playlist.id)).first;
        await reviews.saveCard(
          ReviewCard(
            wordId: rain.id,
            level: 3,
            dueAt: now.add(const Duration(days: 7)),
            lastReviewedAt: now,
          ),
        );

        final b = await service.addDraft(
          draft(['雨', '海']),
          to: const NewPlaylist('B'),
        );
        expect((b.added, b.linked, b.alreadyIn), (1, 1, 0));
        final inB = await repo.words(playlistId: b.playlist.id);
        expect(inB.first.id, rain.id, reason: 'the same word, not a copy');
        expect(await repo.wordsByKey(['雨']), {'雨': rain});
        expect((await reviews.cards()).keys, [rain.id]);
        expect((await reviews.card(rain.id))?.level, 3);
        expect(await repo.playlistsOf([rain.id]), {
          rain.id: {a.playlist.id, b.playlist.id},
        });
      },
    );

    test(
      'a linked word keeps its stored content (the new capture does not change it)',
      () async {
        await service.addDraft(
          CaptureDraft(entries: [entry('雨', meaning: '비')]),
          to: const NewPlaylist('A'),
        );
        await service.addDraft(
          CaptureDraft(
            entries: [
              entry('雨', meaning: '빗물', readings: const ['う']),
            ],
          ),
          to: const NewPlaylist('B'),
        );
        final rain = (await repo.wordsByKey(['雨']))['雨']!;
        expect(rain.meaning, '비');
        expect(rain.readings, ['よみ']);
      },
    );

    test('the same word is found whatever spaces and な-adjective だ', () async {
      await service.addDraft(draft(['丈夫']), to: const NewPlaylist('A'));
      final b = await service.addDraft(
        draft([' 丈夫だ', '丈 夫']),
        to: const NewPlaylist('B'),
      );
      expect((b.added, b.linked, b.alreadyIn), (0, 1, 1));
      expect(await repo.words(), hasLength(1));
    });

    test('a word in no playlist comes back with its record', () async {
      final a = await service.addDraft(
        draft(['雨']),
        to: const NewPlaylist('A'),
      );
      final rain = (await repo.words()).single;
      await reviews.saveCard(
        ReviewCard(wordId: rain.id, level: 2, dueAt: now, lastReviewedAt: now),
      );
      await service.deletePlaylist(a.playlist.id);
      expect(await repo.words(), isEmpty, reason: 'in no playlist: not listed');

      final b = await service.addDraft(
        draft(['雨']),
        to: const NewPlaylist('B'),
      );
      expect((b.added, b.linked), (0, 1));
      expect((await repo.words(playlistId: b.playlist.id)).single.id, rain.id);
      expect((await reviews.card(rain.id))?.level, 2);
    });

    test('blank headwords and excluded entries are skipped', () async {
      final result = await service.addDraft(
        CaptureDraft(
          entries: [entry('雨'), entry('  '), entry('雪', included: false)],
        ),
        to: const NewPlaylist('A'),
      );
      expect((result.added, result.skipped), (1, 2));
    });

    test('a playlist that is gone is a learner error, nothing saved', () async {
      await expectLater(
        service.addDraft(draft(['雨']), to: const ExistingPlaylist('gone')),
        throwsA(isA<LibraryException>()),
      );
      expect(await repo.wordsByKey(['雨']), isEmpty);
    });

    test(
      'a new playlist with a taken name fails before anything is saved',
      () async {
        await service.createPlaylist('A');
        await expectLater(
          service.addDraft(draft(['雨']), to: const NewPlaylist('a')),
          throwsA(isA<LibraryException>()),
        );
        expect(await repo.playlists(), hasLength(1));
        expect(await repo.wordsByKey(['雨']), isEmpty);
      },
    );

    test('ids of two saves at the same instant do not collide', () async {
      final a = await service.addDraft(
        draft(['雨', '雪']),
        to: const NewPlaylist('A'),
      );
      final b = await service.addDraft(
        draft(['空', '海']),
        to: ExistingPlaylist(a.playlist.id),
      );
      expect(b.added, 2);
      final ids = [for (final w in await repo.words()) w.id];
      expect(ids.toSet(), hasLength(4));
      expect(
        (await repo.words(playlistId: a.playlist.id)).map((w) => w.headword),
        ['雨', '雪', '空', '海'],
      );
    });
  });

  group('preview before adding', () {
    test('says which words the library has and what each list holds', () async {
      final a = await service.addDraft(
        draft(['雨', '雪']),
        to: const NewPlaylist('A'),
      );
      final b = await service.addDraft(
        draft(['雨']),
        to: const NewPlaylist('B'),
      );
      final empty = await service.createPlaylist('C');
      final preview = await service.previewAdd(['雨', '雪', '空', '雨']);
      expect(preview.libraryKeys, {'雨', '雪'});
      expect(preview.alreadyInFor(a.playlist.id), 2);
      expect(preview.alreadyInFor(b.playlist.id), 1);
      expect(preview.alreadyInFor(empty.id), 0);
    });
  });

  group('words already in the library', () {
    test('other list: 다른 목록에 추가 links the same words', () async {
      final a = await service.addDraft(
        draft(['雨', '雪', '空']),
        to: const NewPlaylist('A'),
      );
      final b = await service.addDraft(
        draft(['空']),
        to: const NewPlaylist('B'),
      );
      final ids = [
        for (final w in await repo.words(playlistId: a.playlist.id)) w.id,
      ];
      final result = await service.addWords(
        ids,
        to: ExistingPlaylist(b.playlist.id),
      );
      expect((result.added, result.linked, result.alreadyIn), (0, 2, 1));
      expect(
        (await repo.words(playlistId: b.playlist.id)).map((w) => w.headword),
        ['空', '雨', '雪'],
      );
    });
  });

  group('taking words out', () {
    test('a word taken out leaves that list only; its record stays', () async {
      final a = await service.addDraft(
        draft(['雨', '雪']),
        to: const NewPlaylist('A'),
      );
      final b = await service.addDraft(
        draft(['雨']),
        to: const NewPlaylist('B'),
      );
      final rain = (await repo.wordsByKey(['雨']))['雨']!;
      await reviews.saveCard(
        ReviewCard(wordId: rain.id, level: 4, dueAt: now, lastReviewedAt: now),
      );
      await service.removeWords(a.playlist.id, [rain.id]);
      expect(
        (await repo.words(playlistId: a.playlist.id)).map((w) => w.headword),
        ['雪'],
      );
      expect((await repo.words(playlistId: b.playlist.id)).single.id, rain.id);
      expect((await reviews.card(rain.id))?.level, 4);
    });

    test('undo puts the word back at its place', () async {
      final a = await service.addDraft(
        draft(['雨', '雪', '空']),
        to: const NewPlaylist('A'),
      );
      final snow = (await repo.wordsByKey(['雪']))['雪']!;
      final removed = await service.removeWords(a.playlist.id, [snow.id]);
      await service.restoreWords(removed);
      expect(
        (await repo.words(playlistId: a.playlist.id)).map((w) => w.headword),
        ['雨', '雪', '空'],
      );
    });

    test('a word in no list any more stays in the library, unlisted', () async {
      final a = await service.addDraft(
        draft(['雨']),
        to: const NewPlaylist('A'),
      );
      final rain = (await repo.words()).single;
      await service.removeWords(a.playlist.id, [rain.id]);
      expect(await repo.words(), isEmpty);
      expect(await repo.word(rain.id), rain);
    });

    test('deleting a playlist keeps its words and their records', () async {
      final a = await service.addDraft(
        draft(['雨', '雪']),
        to: const NewPlaylist('A'),
      );
      await service.addDraft(draft(['雨']), to: const NewPlaylist('B'));
      final words = await repo.words(playlistId: a.playlist.id);
      await reviews.saveCard(
        ReviewCard(
          wordId: words.last.id,
          level: 2,
          dueAt: now,
          lastReviewedAt: now,
        ),
      );
      await service.deletePlaylist(a.playlist.id);
      expect(await repo.playlist(a.playlist.id), isNull);
      expect((await repo.words()).map((w) => w.headword), ['雨']);
      expect(await repo.word(words.last.id), isNotNull);
      expect((await reviews.card(words.last.id))?.level, 2);
      expect(
        (await repo.playlists()).map((p) => p.position),
        [0],
        reason: 'the playlists left are numbered again from 0',
      );
    });
  });

  group('playlist view and hiding', () {
    test('lists the playlist\'s words with hidden ones apart', () async {
      final a = await service.addDraft(
        draft(['雨', '雪', '空']),
        to: const NewPlaylist('A'),
      );
      final snow = (await repo.wordsByKey(['雪']))['雪']!;
      await service.hideWords([snow.id]);
      final view = await service.playlistView(a.playlist.id);
      expect(view.playlist.name, 'A');
      expect(view.words.map((w) => w.headword), ['雨', '雪', '空']);
      expect(view.shownWords.map((w) => w.headword), ['雨', '空']);
      expect(view.hiddenWords.map((w) => w.headword), ['雪']);
      expect((view.shownCount, view.hiddenCount), (2, 1));
      await expectLater(
        service.playlistView('gone'),
        throwsA(isA<LibraryException>()),
      );
    });

    test('hiding is per word: hidden in every playlist', () async {
      final a = await service.addDraft(
        draft(['雨']),
        to: const NewPlaylist('A'),
      );
      final b = await service.addDraft(
        draft(['雨']),
        to: const NewPlaylist('B'),
      );
      final rain = (await repo.words()).single;
      await service.hideWords([rain.id]);
      for (final id in [a.playlist.id, b.playlist.id]) {
        expect((await service.playlistView(id)).hiddenCount, 1);
      }
      await service.unhideWords([rain.id]);
      expect((await service.playlistView(b.playlist.id)).hiddenCount, 0);
    });

    test('a library block that cannot hide makes hiding a StateError', () {
      final service = LibraryService(library: _NoHiding(repo), clock: clock);
      expect(() => service.hideWords(['x']), throwsStateError);
    });
  });

  test('seeded words list in the playlist order', () async {
    await seedPlaylist(repo, 'pl', [
      seedWord('w2', '雪', at: now),
      seedWord('w1', '雨', at: now),
    ], at: now);
    expect((await repo.words(playlistId: 'pl')).map((w) => w.id), ['w2', 'w1']);
  });
}

/// A library block without the hiding slot.
final class _NoHiding implements LibraryRepository {
  _NoHiding(this._inner);

  final LibraryRepository _inner;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _inner.transaction(action);
}
