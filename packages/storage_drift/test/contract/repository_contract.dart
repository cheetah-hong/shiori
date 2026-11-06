// One set of behaviour tests for every storage block. Each block runs it from
// its own test file (see contract_test.dart), so the in-memory block and the
// SQLite block are held to the same meaning of the repository ports.
import 'dart:async';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

/// A fresh pair of repositories for one test.
abstract interface class StorageUnderTest {
  LibraryRepository get library;
  ReviewRepository get reviews;
  Future<void> close();
}

void repositoryContract(
  String name,
  FutureOr<StorageUnderTest> Function() open,
) {
  group('$name storage', () {
    late StorageUnderTest storage;
    LibraryRepository lib() => storage.library;
    ReviewRepository rev() => storage.reviews;

    setUp(() async => storage = await open());
    tearDown(() => storage.close());

    _wordContract(lib);
    _playlistContract(lib);
    _statsContract(lib);
    _transactionContract(lib);
    _reviewContract(lib, rev);
    _useCaseContract(lib, rev);
  });
}

// Local times with microseconds, the shape the app's clock gives.
final _t0 = DateTime(2026, 11, 5, 9, 30, 15, 123, 456);

Word _word(
  String id, {
  String? headword,
  DateTime? at,
  List<String> readings = const [],
}) => Word(
  id: id,
  headword: headword ?? id,
  readings: readings,
  meaning: '',
  createdAt: at ?? _t0,
);

Playlist _list(String id, {int position = 0, String? name, DateTime? at}) =>
    Playlist(
      id: id,
      name: name ?? id,
      createdAt: at ?? _t0,
      position: position,
    );

ReviewCard _card(String id, {int level = 1, CardScope? scope}) => ReviewCard(
  wordId: id,
  level: level,
  dueAt: _t0.add(const Duration(minutes: 30)),
  lastReviewedAt: _t0,
  scope: scope ?? CardScope.shared,
);

ReviewLog _log(
  String id,
  DateTime at, {
  Answer answer = Answer.known,
  CardScope? scope,
}) => ReviewLog(
  wordId: id,
  answer: answer,
  at: at,
  levelBefore: 0,
  levelAfter: 4,
  retriesInSession: 0,
  scope: scope ?? CardScope.shared,
);

Object _logFields(ReviewLog l) => (
  l.wordId,
  l.answer,
  l.at,
  l.levelBefore,
  l.levelAfter,
  l.retriesInSession,
  l.scope,
);

/// Playlist [id] at [position] holding [wordIds] (inserted when new).
Future<void> _seed(
  LibraryRepository repo,
  String id,
  List<String> wordIds, {
  int position = 0,
  DateTime? at,
}) async {
  if (await repo.playlist(id) == null) {
    await repo.savePlaylist(_list(id, position: position));
  }
  await repo.insertWords([
    for (final w in wordIds)
      if (await repo.word(w) == null) _word(w),
  ]);
  await repo.addToPlaylist(id, wordIds, at: at ?? _t0);
}

void _wordContract(LibraryRepository Function() lib) {
  group('words', () {
    test('a word reads back equal with every field filled', () async {
      final repo = lib();
      final full = Word(
        id: 'w1',
        headword: '乗る',
        readings: const ['のる', 'じょう'],
        pos: PartOfSpeech.verb,
        meaning: '타다',
        example: const Example(ja: '電車に乗る。', ko: '전철을 타다.'),
        createdAt: _t0,
      );
      await repo.insertWords([full, _word('w2')]);
      expect(await repo.word('w1'), full);
      expect((await repo.word('w1'))?.key, '乗る');
      expect(await repo.word('zz'), isNull);
    });

    test('a time reads back as the same instant', () async {
      final repo = lib();
      final at = DateTime.utc(2026, 11, 5, 0, 30, 15, 123, 456);
      await repo.insertWords([_word('w', at: at)]);
      final back = await repo.word('w');
      expect(back?.createdAt.microsecondsSinceEpoch, at.microsecondsSinceEpoch);
    });

    test('a new word is stored shown whatever hiddenAt says', () async {
      final repo = lib();
      await repo.insertWords([_word('w').withHiddenAt(_t0)]);
      expect((await repo.word('w'))?.isHidden, isFalse);
    });

    test(
      'a key already in the library is refused; nothing is written',
      () async {
        final repo = lib();
        await repo.insertWords([_word('w1', headword: '丈夫')]);
        await expectLater(
          repo.insertWords([
            _word('w2', headword: '雨'),
            _word('w3', headword: '丈夫だ'),
          ]),
          throwsA(
            isA<DuplicateWordException>().having((e) => e.keys, 'keys', ['丈夫']),
          ),
        );
        expect(await repo.word('w2'), isNull);
        expect(await repo.word('w3'), isNull);
      },
    );

    test('two new words with one key are refused', () async {
      final repo = lib();
      await expectLater(
        repo.insertWords([
          _word('w1', headword: '雨'),
          _word('w2', headword: ' 雨'),
        ]),
        throwsA(isA<DuplicateWordException>()),
      );
      expect(await repo.wordsByKey(['雨']), isEmpty);
    });

    test('an id already in the library is refused', () async {
      final repo = lib();
      await repo.insertWords([_word('w1', headword: '雨')]);
      await expectLater(
        repo.insertWords([_word('w1', headword: '雪')]),
        throwsA(isA<DuplicateWordException>()),
      );
      expect((await repo.word('w1'))?.headword, '雨');
    });

    test('no words: nothing happens', () async {
      await lib().insertWords(const []);
      expect(await lib().words(), isEmpty);
    });

    test('wordsByKey finds words in no playlist too', () async {
      final repo = lib();
      await repo.insertWords([
        _word('w1', headword: '雨'),
        _word('w2', headword: '雪'),
      ]);
      final found = await repo.wordsByKey(['雨', '空', '雨']);
      expect(found.keys, ['雨']);
      expect(found['雨']?.id, 'w1');
      expect(await repo.wordsByKey(const []), isEmpty);
    });

    test('words() lists only words in a playlist, oldest first', () async {
      final repo = lib();
      await repo.insertWords([
        _word('c', at: _t0),
        _word('a', at: _t0.add(const Duration(seconds: 1))),
        _word('b', at: _t0),
        _word('alone'),
      ]);
      await repo.savePlaylist(_list('p'));
      await repo.savePlaylist(_list('q', position: 1));
      await repo.addToPlaylist('p', ['a', 'c'], at: _t0);
      await repo.addToPlaylist('q', ['b', 'c'], at: _t0);
      expect((await repo.words()).map((w) => w.id), ['b', 'c', 'a']);
      expect((await repo.words(playlistId: 'p')).map((w) => w.id), ['a', 'c']);
      expect((await repo.words(playlistId: 'q')).map((w) => w.id), ['b', 'c']);
      expect(await repo.words(playlistId: 'gone'), isEmpty);
    });

    test('many words at once (more than one query chunk)', () async {
      final repo = lib();
      final words = [
        for (var i = 0; i < 1200; i++) _word('w$i', headword: '語$i'),
      ];
      await repo.insertWords(words);
      final found = await repo.wordsByKey([for (final w in words) w.key]);
      expect(found, hasLength(1200));
      await repo.savePlaylist(_list('p'));
      await repo.addToPlaylist('p', [for (final w in words) w.id], at: _t0);
      expect(await repo.words(playlistId: 'p'), hasLength(1200));
      expect(
        (await repo.playlistsOf([for (final w in words) w.id])).length,
        1200,
      );
    });
  });
}

void _playlistContract(LibraryRepository Function() lib) {
  group('playlists', () {
    test('listed by position and replaced by id', () async {
      final repo = lib();
      await repo.savePlaylist(_list('b', position: 1));
      await repo.savePlaylist(_list('a', position: 0));
      await repo.savePlaylist(_list('c', position: 2));
      expect((await repo.playlists()).map((p) => p.id), ['a', 'b', 'c']);
      await repo.savePlaylist(_list('a', position: 3, name: 'A2'));
      expect((await repo.playlists()).map((p) => p.id), ['b', 'c', 'a']);
      expect(await repo.playlist('a'), _list('a', position: 3, name: 'A2'));
      expect(await repo.playlist('zz'), isNull);
    });

    test(
      'adding appends in order; words already in it keep their place',
      () async {
        final repo = lib();
        await _seed(repo, 'p', ['a', 'b']);
        await repo.insertWords([_word('c'), _word('d')]);
        await repo.addToPlaylist('p', [
          'c',
          'a',
          'd',
          'c',
        ], at: _t0.add(const Duration(minutes: 1)));
        expect((await repo.words(playlistId: 'p')).map((w) => w.id), [
          'a',
          'b',
          'c',
          'd',
        ]);
      },
    );

    test(
      'adding to an unknown playlist or an unknown word adds nothing',
      () async {
        final repo = lib();
        await _seed(repo, 'p', ['a']);
        await repo.insertWords([_word('b')]);
        await expectLater(
          repo.addToPlaylist('gone', ['a'], at: _t0),
          throwsA(isA<PlaylistNotFoundException>()),
        );
        await expectLater(
          repo.addToPlaylist('p', ['b', 'nope'], at: _t0),
          throwsA(
            isA<WordNotFoundException>().having((e) => e.wordIds, 'ids', [
              'nope',
            ]),
          ),
        );
        expect((await repo.words(playlistId: 'p')).map((w) => w.id), ['a']);
        expect(await repo.playlistsOf(['a', 'b']), {
          'a': {'p'},
        });
      },
    );

    test('taking words out returns the entries; undo puts them back', () async {
      final repo = lib();
      await _seed(repo, 'p', ['a', 'b', 'c']);
      final removed = await repo.removeFromPlaylist('p', ['b', 'nope']);
      expect(removed.map((e) => (e.playlistId, e.wordId, e.addedAt)), [
        ('p', 'b', _t0),
      ]);
      expect((await repo.words(playlistId: 'p')).map((w) => w.id), ['a', 'c']);
      expect(await repo.word('b'), isNotNull, reason: 'the word stays');

      await repo.restoreEntries(removed);
      expect((await repo.words(playlistId: 'p')).map((w) => w.id), [
        'a',
        'b',
        'c',
      ]);
      await repo.restoreEntries(removed);
      expect(
        await repo.words(playlistId: 'p'),
        hasLength(3),
        reason: 'a word already back is skipped',
      );
    });

    test('restoring into a playlist that is gone is skipped', () async {
      final repo = lib();
      await _seed(repo, 'p', ['a']);
      final removed = await repo.removeFromPlaylist('p', ['a']);
      await repo.deletePlaylist('p');
      await repo.restoreEntries(removed);
      expect(await repo.playlistsOf(['a']), isEmpty);
    });

    test('deleting a playlist removes its entries, never its words', () async {
      final repo = lib();
      await _seed(repo, 'p', ['a', 'b']);
      await _seed(repo, 'q', ['b'], position: 1);
      await repo.deletePlaylist('p');
      await repo.deletePlaylist('unknown');
      expect(await repo.playlist('p'), isNull);
      expect((await repo.words()).map((w) => w.id), ['b']);
      expect(await repo.word('a'), isNotNull);
      expect(await repo.playlistsOf(['a', 'b']), {
        'b': {'q'},
      });
    });

    test('playlistsOf says where each word is', () async {
      final repo = lib();
      await _seed(repo, 'p', ['a', 'b']);
      await _seed(repo, 'q', ['b'], position: 1);
      await repo.insertWords([_word('c')]);
      expect(await repo.playlistsOf(['a', 'b', 'c', 'zz']), {
        'a': {'p'},
        'b': {'p', 'q'},
      });
    });

    test('returned collections cannot be changed by callers', () async {
      final repo = lib();
      await _seed(repo, 'p', ['a']);
      final words = await repo.words();
      expect(() => words.add(_word('x')), throwsUnsupportedError);
      final lists = await repo.playlists();
      expect(() => lists.add(_list('x')), throwsUnsupportedError);
      final byKey = await repo.wordsByKey(['a']);
      expect(() => byKey.clear(), throwsUnsupportedError);
      final of = await repo.playlistsOf(['a']);
      expect(() => of.clear(), throwsUnsupportedError);
      expect(() => of['a']!.add('q'), throwsUnsupportedError);
      final removed = await repo.removeFromPlaylist('p', ['a']);
      expect(() => removed.clear(), throwsUnsupportedError);
    });
  });
}

void _statsContract(LibraryRepository Function() lib) {
  group('playlist stats', () {
    test('no playlists: no stats', () async {
      expect(await lib().playlistStats(), isEmpty);
    });

    test(
      'one row per playlist in order, with counts and last addition',
      () async {
        final repo = lib();
        final later = _t0.add(const Duration(days: 1));
        await _seed(repo, 'p', ['a', 'b', 'c']);
        await repo.savePlaylist(_list('empty', position: 1));
        await _seed(repo, 'q', ['c'], position: 2, at: later);
        if (repo case final HiddenWordRepository hidden) {
          await hidden.hideWords(['c'], at: _t0);
        }
        final stats = await repo.playlistStats();
        expect(stats.map((s) => s.playlist.id), ['p', 'empty', 'q']);
        expect(stats.map((s) => (s.wordCount, s.hiddenCount, s.lastAddedAt)), [
          (3, 1, _t0),
          (0, 0, null),
          (1, 1, later),
        ]);
        expect(stats.first.playlist, _list('p'));
        for (final s in stats) {
          expect(
            s.wordCount,
            (await repo.words(playlistId: s.playlist.id)).length,
            reason: 'agrees with words()',
          );
        }
        expect(() => stats.add(stats.first), throwsUnsupportedError);
      },
    );
  });
}

void _transactionContract(LibraryRepository Function() lib) {
  group('transaction', () {
    test('a failure leaves the library as it was', () async {
      final repo = lib();
      await _seed(repo, 'p', ['a']);
      await expectLater(
        repo.transaction(() async {
          await repo.savePlaylist(_list('q', position: 1));
          await repo.insertWords([_word('b')]);
          await repo.addToPlaylist('q', ['a', 'b'], at: _t0);
          await repo.removeFromPlaylist('p', ['a']);
          await repo.deletePlaylist('p');
          expect((await repo.words()).map((w) => w.id), [
            'a',
            'b',
          ], reason: 'sees its writes');
          throw StateError('disk full');
        }),
        throwsStateError,
      );
      expect(await repo.playlists(), [_list('p')]);
      expect((await repo.words(playlistId: 'p')).map((w) => w.id), ['a']);
      expect(await repo.word('b'), isNull);
    });

    test('returns the value of the action and keeps its writes', () async {
      final repo = lib();
      final n = await repo.transaction(() async {
        await repo.insertWords([_word('a'), _word('b')]);
        return (await repo.wordsByKey(['a', 'b'])).length;
      });
      expect(n, 2);
      expect(await repo.word('b'), isNotNull);
    });

    test('a nested failure undoes only the nested writes', () async {
      final repo = lib();
      await repo.transaction(() async {
        await repo.insertWords([_word('a')]);
        try {
          await repo.transaction(() async {
            await repo.insertWords([_word('b')]);
            throw StateError('inner');
          });
        } on StateError {
          // The outer action goes on.
        }
      });
      expect((await repo.wordsByKey(['a', 'b'])).keys, ['a']);
    });

    test('calls from outside wait and are not rolled back', () async {
      final repo = lib();
      final gate = Completer<void>();
      final tx = repo.transaction(() async {
        await repo.insertWords([_word('a')]);
        await gate.future;
        throw StateError('rolled back');
      });
      final outsideWrite = repo.insertWords([_word('b')]);
      final outsideRead = repo.wordsByKey(['a', 'b']);
      gate.complete();
      await expectLater(tx, throwsStateError);
      await outsideWrite;
      expect((await outsideRead).keys, ['b']);
      expect((await repo.wordsByKey(['a', 'b'])).keys, ['b']);
    });
  });
}

void _reviewContract(
  LibraryRepository Function() lib,
  ReviewRepository Function() rev,
) {
  group('reviews', () {
    // The SQLite block ties a card to its word.
    setUp(() => lib().insertWords([_word('a'), _word('b'), _word('c')]));

    test('stores cards by scope and word id', () async {
      final repo = rev();
      final pl = CardScope.playlist('p');
      await repo.saveCard(_card('a'));
      await repo.saveCard(_card('b'));
      await repo.saveCard(_card('a', level: 3));
      await repo.saveCard(_card('a', level: 4, scope: pl));
      expect((await repo.card('a'))?.level, 3);
      expect((await repo.card('a', scope: pl))?.level, 4);
      expect(await repo.card('b', scope: pl), isNull);
      expect(await repo.card('zz'), isNull);
      expect((await repo.cards()).keys, unorderedEquals(['a', 'b']));
      expect((await repo.cards(scope: pl)).keys, ['a']);
    });

    test('a card reads back equal', () async {
      final repo = rev();
      final card = ReviewCard(
        wordId: 'a',
        level: 4,
        dueAt: _t0.add(const Duration(days: 21)),
        lastReviewedAt: _t0,
        reviewCount: 7,
        lapseCount: 2,
        scope: CardScope.playlist('p'),
      );
      await repo.saveCard(card);
      expect(await repo.card('a', scope: card.scope), card);
    });

    test('looks up many cards at once', () async {
      final repo = rev();
      await repo.saveCard(_card('a'));
      await repo.saveCard(_card('b'));
      expect((await repo.cards(wordIds: ['b', 'zz', 'b'])).keys, ['b']);
      expect(await repo.cards(wordIds: const []), isEmpty);
    });

    test('returned maps and lists cannot be changed by callers', () async {
      final repo = rev();
      await repo.saveCard(_card('a'));
      await repo.addLog(_log('a', _t0));
      final cards = await repo.cards();
      expect(() => cards.clear(), throwsUnsupportedError);
      final logs = await repo.logs();
      expect(() => logs.clear(), throwsUnsupportedError);
    });

    test(
      'logs keep their order and fields, and filter by time and scope',
      () async {
        final repo = rev();
        final pl = CardScope.playlist('p');
        final a = _log('a', _t0);
        final b = _log('b', _t0.add(const Duration(hours: 1)), scope: pl);
        final c = _log(
          'a',
          _t0.add(const Duration(hours: 2)),
          answer: Answer.retry,
        );
        for (final l in [a, b, c]) {
          await repo.addLog(l);
        }
        expect((await repo.logs()).map(_logFields), [a, b, c].map(_logFields));
        expect(
          (await repo.logs(since: b.at)).map(_logFields),
          [b, c].map(_logFields),
        );
        expect(
          (await repo.logs(scope: CardScope.shared)).map(_logFields),
          [a, c].map(_logFields),
        );
        expect(
          (await repo.logs(since: b.at, scope: pl)).map(_logFields),
          [b].map(_logFields),
        );
      },
    );

    test('logs come oldest first even when added out of order', () async {
      final repo = rev();
      final late = _log('a', _t0.add(const Duration(hours: 1)));
      final early = _log('b', _t0);
      final sameAsEarly = _log('c', _t0);
      for (final l in [late, early, sameAsEarly]) {
        await repo.addLog(l);
      }
      expect((await repo.logs()).map((l) => l.wordId), ['b', 'c', 'a']);
    });

    test('a failed transaction keeps neither the card nor the log', () async {
      final repo = rev();
      await repo.saveCard(_card('a'));
      await expectLater(
        repo.transaction(() async {
          await repo.saveCard(_card('a', level: 4));
          await repo.saveCard(_card('b'));
          await repo.addLog(_log('a', _t0));
          throw StateError('disk full');
        }),
        throwsStateError,
      );
      expect((await repo.cards()).values, [_card('a')]);
      expect(await repo.logs(), isEmpty);
    });
  });
}

void _useCaseContract(
  LibraryRepository Function() lib,
  ReviewRepository Function() rev,
) {
  group('use cases', () {
    final now = DateTime(2026, 11, 5, 21);

    CaptureDraft page(List<String> heads) => CaptureDraft(
      entries: [
        for (final head in heads)
          CapturedEntry(
            headword: head,
            readings: const ['よみ'],
            pos: PartOfSpeech.noun,
            meaning: '뜻',
          ),
      ],
    );

    LibraryService library() =>
        LibraryService(library: lib(), clock: FixedClock(now));

    StudyService study(DateTime at) => StudyService(
      library: lib(),
      reviews: rev(),
      scheduler: const LeitnerFourStepScheduler(),
      clock: FixedClock(at),
    );

    test('adding another page keeps the learning state', () async {
      final first = await library().addDraft(
        page(['雨', '雪']),
        to: const NewPlaylist('A'),
      );
      final service = study(now);
      var session = await service.startSession();
      session = await service.answer(session, Answer.retry);
      session = await service.answer(session, Answer.known);
      final before = await rev().cards();
      expect(before, hasLength(2));

      final again = await library().addDraft(
        page(['風', '雨']),
        to: ExistingPlaylist(first.playlist.id),
      );
      expect((again.added, again.alreadyIn), (1, 1));
      expect(await lib().words(playlistId: first.playlist.id), hasLength(3));
      expect(await rev().cards(), before);
      expect((await rev().logs()).length, 2);
    });

    test('a word in two playlists is one word with one card', () async {
      final a = await library().addDraft(
        page(['雨', '雪']),
        to: const NewPlaylist('A'),
      );
      final service = study(now);
      final session = await service.startSession(
        scope: PlaylistOnly(a.playlist.id),
      );
      await service.answer(session, Answer.known);
      final b = await library().addDraft(
        page(['雨']),
        to: const NewPlaylist('B'),
      );
      expect((b.added, b.linked), (0, 1));
      final rain = (await lib().wordsByKey(['雨']))['雨']!;
      expect(await lib().playlistsOf([rain.id]), {
        rain.id: {a.playlist.id, b.playlist.id},
      });
      expect((await rev().cards()).keys, [rain.id]);
      final inB = await study(now).summary(scope: PlaylistOnly(b.playlist.id));
      expect((inB.newCount, inB.dueCount, inB.knownToday), (0, 0, 1));
    });

    test('a page of twelve words reads back in the photo\'s order', () async {
      const twelve = [
        '雨', '雪', '空', '海', '山', '川', '朝', '昼', '夜', '春', '夏', '秋', //
      ];
      final result = await library().addDraft(
        page(twelve),
        to: const NewPlaylist('A'),
      );
      expect(
        (await lib().words(
          playlistId: result.playlist.id,
        )).map((w) => w.headword),
        twelve,
      );
      final session = await study(now).startSession(goal: 12);
      expect(session.queue.map((i) => i.word.headword), twelve);
    });

    test('two playlists made at once keep different ids and places', () async {
      final made = await Future.wait([
        library().createPlaylist('A'),
        library().createPlaylist('B'),
      ]);
      expect(made[0].id, isNot(made[1].id));
      expect((await lib().playlists()).map((p) => (p.name, p.position)), [
        ('A', 0),
        ('B', 1),
      ]);
    });

    test('known today follows the study day boundary (04:00)', () async {
      final result = await library().addDraft(
        page(['雨', '雪']),
        to: const NewPlaylist('A'),
      );
      final ids = [
        for (final w in await lib().words(playlistId: result.playlist.id)) w.id,
      ];
      await rev().addLog(_log(ids[0], DateTime(2026, 11, 6, 3, 59, 59)));
      await rev().addLog(_log(ids[1], DateTime(2026, 11, 6, 4)));

      final summary = await study(DateTime(2026, 11, 6, 12)).summary();
      expect(summary.knownToday, 1);
      // Before 04:00 the study day is still the previous one.
      final lateNight = await study(DateTime(2026, 11, 6, 3, 59, 59)).summary();
      expect(lateNight.knownToday, 2);
    });
  });
}
