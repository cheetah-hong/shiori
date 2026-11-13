// E1·E2: changing a saved word (단어 고치기). The change shows in every
// playlist that holds the word; its learning state (all four modes) and
// hidden state stay; a headword that names another library word is refused
// and nothing changes; 「저장된 단어로 바꾸기」 puts the stored word in its
// places and keeps the word being changed (and its record) in the library;
// both can be undone. Made-up words, a fixed clock.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/library_seed.dart';

void main() {
  final now = DateTime(2026, 11, 14, 9);
  late InMemoryLibraryRepository repo;
  late InMemoryReviewRepository reviews;
  late LibraryService service;

  Word word(String id, String head, {String meaning = '뜻', DateTime? at}) =>
      Word(
        id: id,
        headword: head,
        readings: const ['しご'],
        pos: PartOfSpeech.noun,
        meaning: meaning,
        createdAt: at ?? now,
      );

  ReviewCard card(String wordId, StudyMode mode, int level) => ReviewCard(
    wordId: wordId,
    mode: mode,
    level: level,
    dueAt: now.add(const Duration(days: 3)),
    lastReviewedAt: now,
    reviewCount: level,
  );

  ReviewLog press(String wordId, StudyMode mode) => ReviewLog(
    wordId: wordId,
    mode: mode,
    answer: Answer.known,
    at: now,
    levelBefore: 0,
    levelAfter: 4,
    retriesInSession: 0,
  );

  WordEdit edit(
    String head, {
    List<String> readings = const ['しごこう'],
    PartOfSpeech? pos = PartOfSpeech.verb,
    String meaning = '새 뜻',
    Example? example,
  }) => WordEdit(
    headword: head,
    readings: readings,
    pos: pos,
    meaning: meaning,
    example: example,
  );

  setUp(() async {
    repo = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    service = LibraryService(library: repo, clock: FixedClock(now));
    await seedPlaylist(repo, 'a', [
      word('w1', '試語甲', meaning: '시험 낱말 하나'),
      word('w2', '試語乙'),
      word('w3', '試語丙'),
    ], at: now);
    await seedPlaylist(repo, 'b', [
      word('w1', '試語甲'),
      word('w4', '試語丁'),
    ], at: now);
  });

  group('E1 changing a word', () {
    test('every field is saved and every playlist shows it', () async {
      final result = await service.editWord(
        'w1',
        edit(
          '  試語戊 ',
          readings: const [' しごぼ ', ''],
          meaning: ' 고친 뜻 ',
          example: const Example(ja: '試語戊を読む。', ko: '시험 낱말을 읽는다.'),
        ),
      );

      final after = await repo.word('w1');
      expect(after!.headword, '試語戊');
      expect(after.key, wordKey('試語戊'));
      expect(after.readings, ['しごぼ']);
      expect(after.pos, PartOfSpeech.verb);
      expect(after.meaning, '고친 뜻');
      expect(after.example, const Example(ja: '試語戊を読む。', ko: '시험 낱말을 읽는다.'));
      expect(after.id, 'w1');
      expect(after.createdAt, now);
      expect(result.after, after);
      expect(result.before.headword, '試語甲');
      expect(result.keyChanged, isTrue);
      for (final list in ['a', 'b']) {
        final shown = await repo.words(playlistId: list);
        expect(shown.firstWhere((w) => w.id == 'w1'), after, reason: list);
      }
      expect(
        (await repo.words(playlistId: 'a')).map((w) => w.id),
        ['w1', 'w2', 'w3'],
        reason: 'the word keeps its place',
      );
    });

    test('a hidden word can be changed and stays hidden', () async {
      final hiddenAt = now.subtract(const Duration(days: 1));
      await repo.hideWords(['w2'], at: hiddenAt);

      await service.editWord('w2', edit('試語乙', meaning: '숨긴 단어의 새 뜻'));

      final after = await repo.word('w2');
      expect(after!.meaning, '숨긴 단어의 새 뜻');
      expect(after.hiddenAt, hiddenAt);
    });

    test(
      'the learning state of all four modes and the press log stay',
      () async {
        for (final (i, mode) in StudyMode.values.indexed) {
          await reviews.saveCard(card('w1', mode, i + 1));
          await reviews.addLog(press('w1', mode));
        }

        await service.editWord('w1', edit('試語戊'));

        for (final (i, mode) in StudyMode.values.indexed) {
          expect((await reviews.card('w1', mode: mode))?.level, i + 1);
        }
        expect(await reviews.logs(), hasLength(4));
      },
    );

    test(
      'a changed key and 「학습 기록 처음부터」 take every mode, keep the log',
      () async {
        final study = StudyService(
          library: repo,
          reviews: reviews,
          scheduler: const LeitnerFourStepScheduler(),
          clock: FixedClock(now),
          settings: const StudySettings(),
        );
        for (final mode in StudyMode.values) {
          await reviews.saveCard(card('w1', mode, 2));
          await reviews.addLog(press('w1', mode));
        }

        final result = await service.editWord('w1', edit('試語戊'));
        expect(result.keyChanged, isTrue);
        final removed = await study.resetWords([result.after.id]);

        expect(removed, hasLength(4));
        for (final mode in StudyMode.values) {
          expect(await reviews.card('w1', mode: mode), isNull);
        }
        expect(await reviews.logs(), hasLength(4));
        expect((await repo.word('w1'))!.headword, '試語戊');
      },
    );

    test('the same key is no clash: 試語甲だ is 試語甲', () async {
      final result = await service.editWord('w1', edit('試語甲だ'));
      expect(result.keyChanged, isFalse);
      expect((await repo.word('w1'))!.headword, '試語甲だ');
    });

    test(
      'blank or non-Japanese headwords and a blank meaning are refused',
      () async {
        final before = await repo.word('w1');
        for (final (bad, message) in [
          (edit('  '), '표제어를 써 주세요'),
          (edit('hello'), '표제어는 가나나 한자로 써 주세요'),
          (edit('사과'), '표제어는 가나나 한자로 써 주세요'),
          (edit('試語戊', meaning: '  '), '뜻을 써 주세요'),
        ]) {
          await expectLater(
            service.editWord('w1', bad),
            throwsA(
              isA<LibraryException>().having(
                (e) => e.message,
                'message',
                message,
              ),
            ),
            reason: '$bad',
          );
        }
        expect(await repo.word('w1'), before);
      },
    );

    test('an unknown word is a LibraryException', () async {
      await expectLater(
        service.editWord('nope', edit('試語戊')),
        throwsA(isA<LibraryException>()),
      );
    });

    test('undoing puts the word back as it was', () async {
      final before = await repo.word('w1');
      final result = await service.editWord('w1', edit('試語戊'));

      await service.undoEdit(result);

      expect(await repo.word('w1'), before);
    });

    test('undoing after another word took the key is refused', () async {
      final result = await service.editWord('w1', edit('試語戊'));
      await service.editWord('w2', edit('試語甲'));

      await expectLater(
        service.undoEdit(result),
        throwsA(
          isA<WordKeyTakenException>().having(
            (e) => e.existing.id,
            'existing',
            'w2',
          ),
        ),
      );
      expect((await repo.word('w1'))!.headword, '試語戊');
    });

    test('headwordProblem and meaningProblem say what the screen shows', () {
      expect(headwordProblem('試語'), isNull);
      expect(headwordProblem('しご'), isNull);
      expect(headwordProblem('Tシャツ'), isNull);
      expect(headwordProblem(' '), '표제어를 써 주세요');
      expect(headwordProblem('abc'), '표제어는 가나나 한자로 써 주세요');
      expect(meaningProblem('뜻'), isNull);
      expect(meaningProblem(' '), '뜻을 써 주세요');
    });
  });

  group('E2 a headword another word has', () {
    test('is refused with that word, and nothing changes', () async {
      final before = await repo.words();
      await expectLater(
        service.editWord('w1', edit('試語乙')),
        throwsA(
          isA<WordKeyTakenException>().having(
            (e) => e.existing.id,
            'existing',
            'w2',
          ),
        ),
      );
      expect(await repo.words(), before);
    });

    test('also when only its width or a printed だ differs', () async {
      await expectLater(
        service.editWord('w1', edit('試語乙だ')),
        throwsA(isA<WordKeyTakenException>()),
      );
    });

    test('a write that fails inside the transaction leaves nothing', () async {
      final failing = _FailingUpdate(repo);
      final s = LibraryService(library: failing, clock: FixedClock(now));
      final before = await repo.words();

      await expectLater(
        s.editWord('w1', edit('試語戊')),
        throwsA(isA<StateError>()),
      );
      expect(await repo.words(), before);
    });

    test(
      'a clash the repository finds is a WordKeyTakenException too',
      () async {
        // The service's own check passes (it sees no word with the key); the
        // repository's does not.
        final racing = _BlindKeys(repo);
        final s = LibraryService(library: racing, clock: FixedClock(now));

        await expectLater(
          s.editWord('w1', edit('試語乙')),
          throwsA(
            isA<WordKeyTakenException>().having(
              (e) => e.existing.id,
              'existing',
              'w2',
            ),
          ),
        );
        expect((await repo.word('w1'))!.headword, '試語甲');
      },
    );

    group('저장된 단어로 바꾸기', () {
      setUp(() async {
        // w5 is the word being fixed: in 'a' (after w3) and in 'c' alone;
        // the stored 試語乙 (w2) is in 'a' already, not in 'c'.
        await seedPlaylist(repo, 'c', [word('w5', '試語乙乙')], at: now);
        await repo.addToPlaylist('a', [
          'w5',
        ], at: now.add(const Duration(hours: 1)));
      });

      test(
        'the stored word takes its places; the word stays in the library',
        () async {
          await reviews.saveCard(card('w5', StudyMode.meaning, 3));
          final entriesC = await _entries(repo, 'c');

          final r = await service.replaceWithExisting('w5', 'w2');

          expect(r.wordId, 'w5');
          expect(r.existingId, 'w2');
          expect(r.playlistCount, 2);
          expect(
            (await repo.words(playlistId: 'a')).map((w) => w.id),
            ['w1', 'w2', 'w3'],
            reason: "'a' held both: it just loses w5",
          );
          expect((await repo.words(playlistId: 'c')).map((w) => w.id), ['w2']);
          final inC = (await _entries(repo, 'c')).single;
          expect(
            (inC.position, inC.addedAt),
            (entriesC.single.position, entriesC.single.addedAt),
            reason: 'same place and time',
          );
          expect(await repo.word('w5'), isNotNull);
          expect(await repo.playlistsOf(['w5']), isEmpty);
          expect((await reviews.card('w5'))?.level, 3);
          expect(r.linked.map((e) => (e.playlistId, e.wordId)), [('c', 'w2')]);
        },
      );

      test('a hidden stored word stays hidden', () async {
        await repo.hideWords(['w2'], at: now);
        await service.replaceWithExisting('w5', 'w2');
        expect((await repo.word('w2'))!.isHidden, isTrue);
        expect((await repo.words(playlistId: 'c')).single.id, 'w2');
      });

      test('undoing puts both lists back', () async {
        final beforeA = await _entries(repo, 'a');
        final beforeC = await _entries(repo, 'c');

        final r = await service.replaceWithExisting('w5', 'w2');
        await service.undoReplace(r);

        expect(await _entries(repo, 'a'), beforeA);
        expect(await _entries(repo, 'c'), beforeC);
      });

      test('an unknown word changes nothing', () async {
        final beforeA = await _entries(repo, 'a');
        await expectLater(
          service.replaceWithExisting('w5', 'nope'),
          throwsA(isA<LibraryException>()),
        );
        expect(await _entries(repo, 'a'), beforeA);
      });
    });
  });
}

/// The entries of [playlistId] as stored, in its order.
Future<List<PlaylistEntry>> _entries(
  LibraryRepository repo,
  String playlistId,
) async {
  final words = await repo.words(playlistId: playlistId);
  final removed = await repo.removeFromPlaylist(playlistId, [
    for (final w in words) w.id,
  ]);
  await repo.restoreEntries(removed);
  return removed;
}

/// Updates the word, then fails: the transaction must undo the update.
final class _FailingUpdate extends _Forwarding {
  _FailingUpdate(super.inner);

  @override
  Future<void> updateWord(Word word) async {
    await inner.updateWord(word);
    throw StateError('disk full');
  }
}

/// Finds no word by key, as if another write landed between the service's
/// check and its update.
final class _BlindKeys extends _Forwarding {
  _BlindKeys(super.inner);

  @override
  Future<Map<String, Word>> wordsByKey(Iterable<String> keys) async => const {};
}

class _Forwarding implements LibraryRepository {
  _Forwarding(this.inner);

  final InMemoryLibraryRepository inner;

  @override
  Future<void> updateWord(Word word) => inner.updateWord(word);

  @override
  Future<Map<String, Word>> wordsByKey(Iterable<String> keys) =>
      inner.wordsByKey(keys);

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      inner.transaction(action);

  @override
  Future<Word?> word(String id) => inner.word(id);

  @override
  Future<List<Word>> words({String? playlistId}) =>
      inner.words(playlistId: playlistId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
