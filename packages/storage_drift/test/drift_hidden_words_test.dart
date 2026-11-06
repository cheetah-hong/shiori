// Hiding words in the SQLite block: what only a real database can show
// (a write that fails half way, a file closed and opened again).
import 'dart:io';

import 'package:drift/native.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime(2026, 11, 5, 21, 0, 0, 0, 7);
  final hideAt = DateTime(2026, 11, 5, 22, 15, 0, 0, 3);

  Word word(String id) => Word(
    id: id,
    headword: '語$id',
    readings: const ['ご'],
    meaning: '말',
    createdAt: t0,
  );

  final card = ReviewCard(
    wordId: 'tb:a',
    level: 3,
    dueAt: t0.add(const Duration(days: 7)),
    lastReviewedAt: t0,
    reviewCount: 2,
    lapseCount: 1,
  );

  Future<(DriftLibraryRepository, DriftReviewRepository)> seed(
    ShioriDatabase db,
  ) async {
    final library = DriftLibraryRepository(db);
    final reviews = DriftReviewRepository(db);
    await library.savePlaylist(
      Playlist(id: 'tb', name: '단어장', createdAt: t0, position: 0),
    );
    await library.insertWords([word('tb:a'), word('tb:b'), word('tb:c')]);
    await library.addToPlaylist('tb', ['tb:a', 'tb:b', 'tb:c'], at: t0);
    await reviews.saveCard(card);
    await reviews.addLog(
      ReviewLog(
        wordId: 'tb:a',
        answer: Answer.known,
        at: t0,
        levelBefore: 2,
        levelAfter: 3,
        retriesInSession: 0,
      ),
    );
    return (library, reviews);
  }

  test('a write that fails half way hides nothing and leaves cards and logs '
      'alone', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    final (library, reviews) = await seed(db);
    // A storage error on the second word, after the first one was written.
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_on_c BEFORE UPDATE OF hidden_at ON words "
      "WHEN NEW.id = 'tb:c' BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );

    await expectLater(
      library.hideWords(['tb:a', 'tb:c'], at: hideAt),
      throwsA(isA<SqliteException>()),
    );
    expect(await library.hiddenWords(), isEmpty);
    expect((await library.word('tb:a'))?.isHidden, isFalse);
    expect(await reviews.cards(), {'tb:a': card});
    expect((await reviews.logs()).single.levelAfter, 3);

    // Through the use case: 이미 알아요 on that card fails the same way and
    // only the word hidden before stays hidden.
    await library.hideWords(['tb:b'], at: hideAt);
    final service = StudyService(
      library: library,
      reviews: reviews,
      scheduler: const LeitnerFourStepScheduler(),
      clock: FixedClock(hideAt),
    );
    final session = await service.startSession();
    expect(session.current?.word.id, 'tb:c');
    await expectLater(service.hide(session), throwsA(isA<SqliteException>()));
    expect((await library.hiddenWords()).map((w) => w.id), ['tb:b']);
    expect(await reviews.cards(), {'tb:a': card});
    expect(await reviews.logs(), hasLength(1));
  });

  test('the hidden state stays after the file is closed and opened', () async {
    final dir = Directory.systemTemp.createTempSync('shiori_hidden_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/shiori.sqlite');

    final first = ShioriDatabase(NativeDatabase(file));
    final (library, _) = await seed(first);
    await library.hideWords(['tb:b'], at: hideAt);
    await first.close();

    final second = ShioriDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final reopened = DriftLibraryRepository(second);
    expect((await reopened.word('tb:b'))?.hiddenAt, hideAt);
    expect((await reopened.hiddenWords()).map((w) => w.id), ['tb:b']);
    expect(await DriftReviewRepository(second).cards(), {'tb:a': card});
  });
}
