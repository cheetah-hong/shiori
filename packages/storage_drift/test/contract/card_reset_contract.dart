// Behaviour tests for removing learning state (처음부터 다시 학습, 전체
// 초기화), run against every storage block from contract_test.dart, so the
// in-memory block and the SQLite block mean the same thing.
import 'dart:async';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'repository_contract.dart';

void cardResetContract(
  String name,
  FutureOr<StorageUnderTest> Function() open,
) {
  group('$name card reset', () {
    late StorageUnderTest storage;
    LibraryRepository lib() => storage.library;
    ReviewRepository rev() => storage.reviews;
    final pl = CardScope.playlist('p');

    setUp(() async {
      storage = await open();
      // The SQLite block ties a card to its word.
      await lib().insertWords([
        for (final id in ['a', 'b', 'c']) _word(id),
      ]);
    });
    tearDown(() => storage.close());

    /// a and b in the shared scope (a with every field set), a in [pl],
    /// and one press for each.
    Future<void> seed() async {
      final repo = rev();
      await repo.saveCard(_full('a'));
      await repo.saveCard(_card('b'));
      await repo.saveCard(_card('a', level: 4, scope: pl));
      await repo.addLog(_log('a', _t0));
      await repo.addLog(_log('b', _t0.add(const Duration(minutes: 1))));
    }

    test('deleteCards removes only the named cards of that scope and '
        'returns them', () async {
      await seed();
      final repo = rev();

      final removed = await repo.deleteCards(['a']);

      expect(removed, [_full('a')]);
      expect(await repo.card('a'), isNull);
      expect(await repo.card('b'), _card('b'));
      expect(await repo.card('a', scope: pl), _card('a', level: 4, scope: pl));
    });

    test('deleteCards in a playlist scope leaves the shared card', () async {
      await seed();
      final repo = rev();

      final removed = await repo.deleteCards(['a'], scope: pl);

      expect(removed, [_card('a', level: 4, scope: pl)]);
      expect(await repo.card('a', scope: pl), isNull);
      expect(await repo.card('a'), _full('a'));
    });

    test('ids without a card, unknown ids and repeats', () async {
      await seed();
      final repo = rev();

      expect(await repo.deleteCards(['a', 'a', 'zz', 'c']), [_full('a')]);
      expect(await repo.deleteCards(const []), isEmpty);
      expect(await repo.deleteCards(['a']), isEmpty);
      expect((await repo.cards()).keys, ['b']);
    });

    test('the returned list cannot be changed by callers', () async {
      await seed();
      final removed = await rev().deleteCards(['a', 'b']);
      expect(removed, hasLength(2));
      expect(() => removed.clear(), throwsUnsupportedError);
    });

    test('many cards at once (more than one query chunk)', () async {
      final ids = [for (var i = 0; i < 1201; i++) 'w$i'];
      await lib().insertWords([for (final id in ids) _word(id)]);
      final repo = rev();
      for (final id in ids) {
        await repo.saveCard(_card(id));
      }

      final removed = await repo.deleteCards(ids.take(1200));

      expect(removed.map((c) => c.wordId), unorderedEquals(ids.take(1200)));
      expect((await repo.cards(wordIds: ids)).keys, ['w1200']);
    });

    test('deleteAllCards with a scope removes that scope only and counts '
        'it', () async {
      await seed();
      final repo = rev();

      expect(await repo.deleteAllCards(scope: CardScope.shared), 2);

      expect(await repo.cards(), isEmpty);
      expect((await repo.cards(scope: pl)).keys, ['a']);
    });

    test('deleteAllCards without a scope removes every scope', () async {
      await seed();
      final repo = rev();

      expect(await repo.deleteAllCards(), 3);

      expect(await repo.cards(), isEmpty);
      expect(await repo.cards(scope: pl), isEmpty);
      expect(await repo.deleteAllCards(), 0);
    });

    test('the press log and the words stay', () async {
      await seed();
      final repo = rev();
      final before = (await repo.logs()).map(_logFields).toList();

      await repo.deleteCards(['a', 'b']);
      await repo.deleteAllCards();

      expect((await repo.logs()).map(_logFields), before);
      expect(await lib().word('a'), isNotNull);
      expect(await lib().word('b'), isNotNull);
    });

    test('a removed card can be saved again', () async {
      await seed();
      final repo = rev();
      final removed = await repo.deleteCards(['a']);

      for (final c in removed) {
        await repo.saveCard(c);
      }

      expect(await repo.card('a'), _full('a'));
    });

    test('a failed transaction brings the removed cards back', () async {
      await seed();
      final repo = rev();

      await expectLater(
        repo.transaction(() async {
          await repo.deleteCards(['a']);
          await repo.deleteAllCards();
          throw StateError('disk full');
        }),
        throwsStateError,
      );

      expect(
        (await repo.cards()).values,
        unorderedEquals([_full('a'), _card('b')]),
      );
      expect((await repo.cards(scope: pl)).keys, ['a']);
      expect(await repo.logs(), hasLength(2));
    });
  });
}

// Local times with microseconds, the shape the app's clock gives.
final _t0 = DateTime(2026, 11, 5, 9, 30, 15, 123, 456);

Word _word(String id) =>
    Word(id: id, headword: id, readings: const [], meaning: '', createdAt: _t0);

ReviewCard _card(String id, {int level = 1, CardScope? scope}) => ReviewCard(
  wordId: id,
  level: level,
  dueAt: _t0.add(const Duration(minutes: 30)),
  lastReviewedAt: _t0,
  scope: scope ?? CardScope.shared,
);

ReviewCard _full(String id) => ReviewCard(
  wordId: id,
  level: 3,
  dueAt: _t0.add(const Duration(days: 7)),
  lastReviewedAt: _t0.subtract(const Duration(days: 3)),
  reviewCount: 5,
  lapseCount: 2,
);

ReviewLog _log(String id, DateTime at) => ReviewLog(
  wordId: id,
  answer: Answer.known,
  at: at,
  levelBefore: 0,
  levelAfter: 4,
  retriesInSession: 0,
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
