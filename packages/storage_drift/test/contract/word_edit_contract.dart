// E2s: changing a stored word (`LibraryRepository.updateWord`), run against
// every storage block from contract_test.dart so the in-memory block and the
// SQLite block mean the same thing. Made-up words.
import 'dart:async';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'repository_contract.dart';

// Local times with microseconds, the shape the app's clock gives.
final _t0 = DateTime(2026, 11, 14, 9, 30, 15, 123, 456);
final _hideAt = DateTime(2026, 11, 14, 10, 0, 0, 0, 7);

Word _word(
  String id,
  String head, {
  String meaning = '뜻',
  DateTime? createdAt,
  DateTime? hiddenAt,
  Example? example,
}) => Word(
  id: id,
  headword: head,
  readings: const ['しご'],
  pos: PartOfSpeech.noun,
  meaning: meaning,
  example: example,
  createdAt: createdAt ?? _t0,
  hiddenAt: hiddenAt,
);

void wordEditContract(String name, FutureOr<StorageUnderTest> Function() open) {
  group('$name updateWord', () {
    late StorageUnderTest storage;
    LibraryRepository lib() => storage.library;
    HiddenWordRepository hid() => storage.library as HiddenWordRepository;

    setUp(() async {
      storage = await open();
      await lib().savePlaylist(
        Playlist(id: 'a', name: 'a', createdAt: _t0, position: 0),
      );
      await lib().savePlaylist(
        Playlist(id: 'b', name: 'b', createdAt: _t0, position: 1),
      );
      await lib().insertWords([
        _word(
          'w1',
          '試語甲',
          example: const Example(ja: '例。', ko: '예.'),
        ),
        _word('w2', '試語乙'),
      ]);
      await lib().addToPlaylist('a', ['w1', 'w2'], at: _t0);
      await lib().addToPlaylist('b', ['w1'], at: _t0);
    });
    tearDown(() => storage.close());

    test('replaces the content and the key; id and time stay', () async {
      await lib().updateWord(
        Word(
          id: 'w1',
          headword: '試語戊',
          readings: const ['しごぼ', 'しごも'],
          pos: PartOfSpeech.verb,
          meaning: '고친 뜻',
          example: const Example(ja: '新しい例。', ko: '새 예.'),
          createdAt: DateTime(2000),
        ),
      );

      final w = await lib().word('w1');
      expect(w!.headword, '試語戊');
      expect(w.key, wordKey('試語戊'));
      expect(w.readings, ['しごぼ', 'しごも']);
      expect(w.pos, PartOfSpeech.verb);
      expect(w.meaning, '고친 뜻');
      expect(w.example, const Example(ja: '新しい例。', ko: '새 예.'));
      expect(w.createdAt, _t0, reason: 'creation time as stored');
      expect((await lib().wordsByKey([wordKey('試語戊')])).keys, [wordKey('試語戊')]);
      expect(await lib().wordsByKey([wordKey('試語甲')]), isEmpty);
    });

    test('every playlist shows the change, in the same place', () async {
      await lib().updateWord(_word('w1', '試語戊', meaning: '고친 뜻'));
      for (final list in ['a', 'b']) {
        final first = (await lib().words(playlistId: list)).first;
        expect((first.id, first.meaning), ('w1', '고친 뜻'), reason: list);
      }
      expect((await lib().words(playlistId: 'a')).map((w) => w.id), [
        'w1',
        'w2',
      ]);
    });

    test('an example can be taken away and class cleared', () async {
      await lib().updateWord(
        Word(
          id: 'w1',
          headword: '試語甲',
          readings: const [],
          meaning: '뜻',
          createdAt: _t0,
        ),
      );
      final w = await lib().word('w1');
      expect(w!.example, isNull);
      expect(w.pos, isNull);
      expect(w.readings, isEmpty);
    });

    test('the hidden state stays as stored, whatever the word says', () async {
      await hid().hideWords(['w1'], at: _hideAt);
      await lib().updateWord(_word('w1', '試語戊'));
      expect((await lib().word('w1'))!.hiddenAt, _hideAt);

      await lib().updateWord(_word('w2', '試語己', hiddenAt: _hideAt));
      expect((await lib().word('w2'))!.isHidden, isFalse);
    });

    test('the learning state goes with the id', () async {
      final card = ReviewCard(
        wordId: 'w1',
        mode: StudyMode.recall,
        level: 3,
        dueAt: _t0.add(const Duration(days: 7)),
        lastReviewedAt: _t0,
        reviewCount: 2,
      );
      await storage.reviews.saveCard(card);
      await lib().updateWord(_word('w1', '試語戊'));
      expect(await storage.reviews.card('w1', mode: StudyMode.recall), card);
    });

    test('its own key again is no clash (試語甲だ is 試語甲)', () async {
      await lib().updateWord(_word('w1', '試語甲だ'));
      expect((await lib().word('w1'))!.headword, '試語甲だ');
    });

    test('another word\'s key is refused and nothing is written', () async {
      final before = await lib().words();
      await expectLater(
        lib().updateWord(_word('w1', '試語乙', meaning: '바뀌면 안 됨')),
        throwsA(
          isA<DuplicateWordException>().having((e) => e.keys, 'keys', [
            wordKey('試語乙'),
          ]),
        ),
      );
      expect(await lib().words(), before);
    });

    test('an unknown id is refused', () async {
      await expectLater(
        lib().updateWord(_word('nope', '試語戊')),
        throwsA(
          isA<WordNotFoundException>().having((e) => e.wordIds, 'wordIds', [
            'nope',
          ]),
        ),
      );
      expect(await lib().word('nope'), isNull);
    });

    test('an outer transaction that throws undoes the update', () async {
      final before = await lib().word('w1');
      await expectLater(
        lib().transaction(() async {
          await lib().updateWord(_word('w1', '試語戊'));
          expect((await lib().word('w1'))!.headword, '試語戊');
          throw StateError('later step failed');
        }),
        throwsA(isA<StateError>()),
      );
      expect(await lib().word('w1'), before);
      expect(await lib().wordsByKey([wordKey('試語戊')]), isEmpty);
    });
  });
}
