// Behaviour tests for a record per study mode, run against every storage
// block from study_mode_contract_test.dart, so the in-memory block and the
// SQLite block mean the same thing.
import 'dart:async';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'repository_contract.dart';

void studyModeContract(
  String name,
  FutureOr<StorageUnderTest> Function() open,
) {
  group('$name study modes', () {
    late StorageUnderTest storage;
    ReviewRepository rev() => storage.reviews;
    final pl = CardScope.playlist('p');

    setUp(() async {
      storage = await open();
      // The SQLite block ties a card to its word.
      await storage.library.insertWords([
        for (final id in ['a', 'b', 'c']) _word(id),
      ]);
    });
    tearDown(() => storage.close());

    /// a in every mode (each at its own level), b in meaning and choice,
    /// a in [pl] as recall; one press per mode.
    Future<void> seed() async {
      final repo = rev();
      for (final (i, mode) in StudyMode.values.indexed) {
        await repo.saveCard(_card('a', mode, level: i + 1));
        await repo.addLog(_log('a', mode, _t0.add(Duration(minutes: i))));
      }
      await repo.saveCard(_card('b', StudyMode.meaning));
      await repo.saveCard(_card('b', StudyMode.choice, level: 3));
      await repo.saveCard(_card('a', StudyMode.recall, level: 4, scope: pl));
    }

    test('a word keeps one card per mode, side by side', () async {
      await seed();
      final repo = rev();
      for (final (i, mode) in StudyMode.values.indexed) {
        expect(
          await repo.card('a', mode: mode),
          _card('a', mode, level: i + 1),
          reason: '$mode',
        );
      }
      expect(await repo.card('b', mode: StudyMode.recall), isNull);
      expect(await repo.card('c', mode: StudyMode.meaning), isNull);
    });

    test('left out, the mode is meaning', () async {
      await seed();
      final repo = rev();
      expect(await repo.card('a'), _card('a', StudyMode.meaning, level: 1));
      expect((await repo.cards()).keys.toSet(), {'a', 'b'});
      expect((await repo.cards()).values.map((c) => c.mode).toSet(), {
        StudyMode.meaning,
      });
      // ReviewCard and ReviewLog default to meaning too.
      final card = ReviewCard(
        wordId: 'x',
        level: 1,
        dueAt: _t0,
        lastReviewedAt: _t0,
      );
      expect(card.mode, StudyMode.meaning);
      expect(_logWithoutMode().mode, StudyMode.meaning);
    });

    test('cards() reads one mode, by id or all of it', () async {
      await seed();
      final repo = rev();
      final choice = await repo.cards(mode: StudyMode.choice);
      expect(choice, {
        'a': _card('a', StudyMode.choice, level: 4),
        'b': _card('b', StudyMode.choice, level: 3),
      });
      expect(await repo.cards(wordIds: ['b', 'c'], mode: StudyMode.choice), {
        'b': _card('b', StudyMode.choice, level: 3),
      });
      expect(await repo.cards(mode: StudyMode.listening), {
        'a': _card('a', StudyMode.listening, level: 3),
      });
    });

    test('scope and mode together name a record', () async {
      await seed();
      final repo = rev();
      expect(
        await repo.card('a', scope: pl, mode: StudyMode.recall),
        _card('a', StudyMode.recall, level: 4, scope: pl),
      );
      expect(await repo.card('a', scope: pl), isNull);
      expect(await repo.cards(scope: pl, mode: StudyMode.recall), hasLength(1));
      expect(
        await repo.card('a', mode: StudyMode.recall),
        _card('a', StudyMode.recall, level: 2),
      );
    });

    test('saving a card replaces only its own mode', () async {
      await seed();
      final repo = rev();
      final moved = _card(
        'a',
        StudyMode.listening,
        level: 1,
      ).copyWith(dueAt: _t0.add(const Duration(days: 3)));
      await repo.saveCard(moved);
      expect(await repo.card('a', mode: StudyMode.listening), moved);
      expect(
        await repo.card('a', mode: StudyMode.choice),
        _card('a', StudyMode.choice, level: 4),
      );
      expect(await repo.cards(mode: StudyMode.listening), hasLength(1));
    });

    test('deleteCards removes the named mode only', () async {
      await seed();
      final repo = rev();
      final removed = await repo.deleteCards([
        'a',
        'b',
      ], mode: StudyMode.choice);
      expect(removed.toSet(), {
        _card('a', StudyMode.choice, level: 4),
        _card('b', StudyMode.choice, level: 3),
      });
      expect(await repo.cards(mode: StudyMode.choice), isEmpty);
      expect(await repo.card('a'), _card('a', StudyMode.meaning, level: 1));
      expect(await repo.card('b'), _card('b', StudyMode.meaning));
      expect(
        await repo.card('a', scope: pl, mode: StudyMode.recall),
        isNotNull,
      );
    });

    test('deleteCards without a mode leaves the other modes', () async {
      await seed();
      final repo = rev();
      expect(await repo.deleteCards(['a']), [
        _card('a', StudyMode.meaning, level: 1),
      ]);
      expect(
        await repo.card('a', mode: StudyMode.recall),
        _card('a', StudyMode.recall, level: 2),
      );
    });

    test(
      'deleteAllCards: one mode, one scope and mode, or everything',
      () async {
        await seed();
        final repo = rev();
        expect(await repo.deleteAllCards(mode: StudyMode.choice), 2);
        expect(await repo.cards(mode: StudyMode.choice), isEmpty);
        expect(await repo.cards(), hasLength(2));
        expect(await repo.deleteAllCards(scope: pl, mode: StudyMode.recall), 1);
        expect(
          await repo.card('a', mode: StudyMode.recall),
          _card('a', StudyMode.recall, level: 2),
        );
        // a: meaning, recall, listening; b: meaning.
        expect(await repo.deleteAllCards(), 4);
        for (final mode in StudyMode.values) {
          expect(await repo.cards(mode: mode), isEmpty, reason: '$mode');
        }
        expect(await repo.logs(), hasLength(4), reason: 'presses stay');
      },
    );

    test(
      'deleteAllCards(scope:) without a mode takes every mode of it',
      () async {
        await seed();
        final repo = rev();
        expect(await repo.deleteAllCards(scope: CardScope.shared), 6);
        expect(
          await repo.card('a', scope: pl, mode: StudyMode.recall),
          isNotNull,
        );
      },
    );

    test('logs keep their mode and can be read by mode', () async {
      await seed();
      final repo = rev();
      final all = await repo.logs();
      expect(all.map((l) => l.mode), StudyMode.values);
      final listening = await repo.logs(mode: StudyMode.listening);
      expect(listening.single.at, _t0.add(const Duration(minutes: 2)));
      expect(
        await repo.logs(
          since: _t0.add(const Duration(minutes: 1)),
          mode: StudyMode.meaning,
        ),
        isEmpty,
      );
      expect(
        await repo.logs(scope: CardScope.shared, mode: StudyMode.choice),
        hasLength(1),
      );
      expect(await repo.logs(scope: pl, mode: StudyMode.choice), isEmpty);
    });

    test('a failed transaction undoes cards of every mode', () async {
      await seed();
      final repo = rev();
      await expectLater(
        repo.transaction(() async {
          await repo.saveCard(_card('c', StudyMode.listening, level: 2));
          await repo.deleteCards(['a'], mode: StudyMode.recall);
          throw StateError('stop');
        }),
        throwsStateError,
      );
      expect(await repo.card('c', mode: StudyMode.listening), isNull);
      expect(
        await repo.card('a', mode: StudyMode.recall),
        _card('a', StudyMode.recall, level: 2),
      );
    });
  });
}

final _t0 = DateTime(2026, 11, 11, 21, 30, 15, 123, 456);

Word _word(String id) =>
    Word(id: id, headword: id, readings: const [], meaning: '', createdAt: _t0);

ReviewCard _card(
  String id,
  StudyMode mode, {
  int level = 1,
  CardScope scope = CardScope.shared,
}) => ReviewCard(
  wordId: id,
  level: level,
  dueAt: _t0.add(Duration(days: level)),
  lastReviewedAt: _t0,
  reviewCount: level,
  lapseCount: level - 1,
  scope: scope,
  mode: mode,
);

ReviewLog _log(String id, StudyMode mode, DateTime at) => ReviewLog(
  wordId: id,
  answer: Answer.known,
  at: at,
  levelBefore: 0,
  levelAfter: 4,
  retriesInSession: 0,
  mode: mode,
);

ReviewLog _logWithoutMode() => ReviewLog(
  wordId: 'x',
  answer: Answer.retry,
  at: _t0,
  levelBefore: 1,
  levelAfter: 1,
  retriesInSession: 1,
);
