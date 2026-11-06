import 'dart:async';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime(2026, 11, 5);

  Word word(String id, {DateTime? at}) => Word(
    id: id,
    headword: id,
    readings: const [],
    meaning: '',
    createdAt: at ?? t0,
  );

  Playlist list(String id, {int position = 0}) =>
      Playlist(id: id, name: id, createdAt: t0, position: position);

  group('InMemoryLibraryRepository', () {
    test('a failed transaction leaves the library as it was', () async {
      final repo = InMemoryLibraryRepository();
      await repo.savePlaylist(list('p'));
      await repo.insertWords([word('a')]);
      await repo.addToPlaylist('p', ['a'], at: t0);
      await expectLater(
        repo.transaction(() async {
          await repo.savePlaylist(list('q', position: 1));
          await repo.insertWords([word('b')]);
          await repo.addToPlaylist('q', ['a', 'b'], at: t0);
          await repo.removeFromPlaylist('p', ['a']);
          await repo.hideWords(['a'], at: t0);
          expect((await repo.words()).length, 2, reason: 'sees its writes');
          throw StateError('disk full');
        }),
        throwsStateError,
      );
      expect(await repo.playlists(), [list('p')]);
      expect((await repo.words(playlistId: 'p')).map((w) => w.id), ['a']);
      expect(await repo.word('b'), isNull);
      expect((await repo.word('a'))?.isHidden, isFalse);
    });

    test('a transaction returns its value and keeps its writes', () async {
      final repo = InMemoryLibraryRepository();
      final n = await repo.transaction(() async {
        await repo.insertWords([word('a'), word('b')]);
        return (await repo.wordsByKey(['a', 'b'])).length;
      });
      expect(n, 2);
      expect(await repo.word('b'), isNotNull);
    });

    test('a nested transaction that fails undoes only its writes', () async {
      final repo = InMemoryLibraryRepository();
      await repo.transaction(() async {
        await repo.insertWords([word('a')]);
        try {
          await repo.transaction(() async {
            await repo.insertWords([word('b')]);
            throw StateError('inner');
          });
        } on StateError {
          // The outer action goes on.
        }
      });
      expect((await repo.wordsByKey(['a', 'b'])).keys, ['a']);
    });

    test('calls from outside wait for a running transaction', () async {
      final repo = InMemoryLibraryRepository();
      final gate = Completer<void>();
      final tx = repo.transaction(() async {
        await repo.insertWords([word('a')]);
        await gate.future;
        throw StateError('rolled back');
      });
      final outsideWrite = repo.insertWords([word('b')]);
      final outsideRead = repo.wordsByKey(['a', 'b']);
      gate.complete();
      await expectLater(tx, throwsStateError);
      await outsideWrite;
      // Queued behind the transaction: never sees the rolled-back word.
      expect((await outsideRead).keys, ['b']);
    });

    test('returned collections cannot be changed by callers', () async {
      final repo = InMemoryLibraryRepository();
      await repo.savePlaylist(list('p'));
      await repo.insertWords([word('a')]);
      await repo.addToPlaylist('p', ['a'], at: t0);
      final words = await repo.words();
      expect(() => words.add(word('b')), throwsUnsupportedError);
      final lists = await repo.playlists();
      expect(() => lists.add(list('q')), throwsUnsupportedError);
      final byKey = await repo.wordsByKey(['a']);
      expect(() => byKey['b'] = word('b'), throwsUnsupportedError);
      final of = await repo.playlistsOf(['a']);
      expect(() => of['a']!.add('q'), throwsUnsupportedError);
    });
  });

  group('InMemoryStudyPreferencesRepository', () {
    test('starts with the defaults and keeps what is saved', () async {
      final repo = InMemoryStudyPreferencesRepository();
      expect(await repo.load(), const StudyPreferences());
      const per = StudyPreferences(
        recordMode: RecordMode.perPlaylist,
        scopeMode: StudyScopeMode.playlistOnly,
      );
      await repo.save(per);
      expect(await repo.load(), per);
    });
  });

  group('InMemoryReviewRepository', () {
    ReviewCard card(String id) =>
        ReviewCard(wordId: id, level: 1, dueAt: t0, lastReviewedAt: t0);

    test('stores cards by scope and word id', () async {
      final repo = InMemoryReviewRepository();
      final pl = CardScope.playlist('p');
      await repo.saveCard(card('a'));
      await repo.saveCard(
        ReviewCard(
          wordId: 'a',
          level: 4,
          dueAt: t0,
          lastReviewedAt: t0,
          scope: pl,
        ),
      );
      expect((await repo.card('a'))?.level, 1);
      expect((await repo.card('a', scope: pl))?.level, 4);
      expect((await repo.cards()).values.single.scope, CardScope.shared);
      expect((await repo.cards(scope: pl)).values.single.level, 4);
      expect(await repo.card('a', scope: CardScope.playlist('q')), isNull);
    });

    test('stores cards by word id', () async {
      final repo = InMemoryReviewRepository();
      await repo.saveCard(card('a'));
      await repo.saveCard(card('b'));
      await repo.saveCard(card('a').copyWith(level: 3));
      expect((await repo.card('a'))?.level, 3);
      expect((await repo.cards()).keys, unorderedEquals(['a', 'b']));
      expect((await repo.cards(wordIds: ['b', 'zz'])).keys, ['b']);
    });

    test('a failed transaction keeps neither the card nor the log', () async {
      final repo = InMemoryReviewRepository();
      await repo.saveCard(card('a'));
      await expectLater(
        repo.transaction(() async {
          await repo.saveCard(card('a').copyWith(level: 4));
          await repo.saveCard(card('b'));
          await repo.addLog(
            ReviewLog(
              wordId: 'a',
              answer: Answer.known,
              at: t0,
              levelBefore: 1,
              levelAfter: 4,
              retriesInSession: 0,
            ),
          );
          throw StateError('disk full');
        }),
        throwsStateError,
      );
      expect((await repo.cards()).values, [card('a')]);
      expect(await repo.logs(), isEmpty);
    });

    test('logs filter by scope', () async {
      final repo = InMemoryReviewRepository();
      for (final scope in [CardScope.shared, CardScope.playlist('p')]) {
        await repo.addLog(
          ReviewLog(
            wordId: 'a',
            answer: Answer.known,
            at: t0,
            levelBefore: 0,
            levelAfter: 4,
            retriesInSession: 0,
            scope: scope,
          ),
        );
      }
      expect((await repo.logs()).length, 2);
      expect(
        (await repo.logs(scope: CardScope.shared)).single.scope,
        CardScope.shared,
      );
      expect(
        (await repo.logs(scope: CardScope.playlist('p'))).single.scope,
        CardScope.playlist('p'),
      );
    });

    test('logs filter by time', () async {
      final repo = InMemoryReviewRepository();
      for (final h in [1, 5, 9]) {
        await repo.addLog(
          ReviewLog(
            wordId: 'a',
            answer: Answer.known,
            at: t0.add(Duration(hours: h)),
            levelBefore: 0,
            levelAfter: 4,
            retriesInSession: 0,
          ),
        );
      }
      expect((await repo.logs()).length, 3);
      expect(
        (await repo.logs(since: t0.add(const Duration(hours: 5)))).length,
        2,
      );
    });
  });
}
