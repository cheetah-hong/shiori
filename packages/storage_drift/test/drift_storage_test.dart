import 'dart:io';

import 'package:drift/native.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:shiori_storage_drift/src/converters.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime(2026, 11, 5, 21, 0, 0, 0, 7);

  Word word(String id, {String headword = '雨'}) => Word(
    id: id,
    headword: headword,
    readings: const ['あめ'],
    meaning: '비',
    createdAt: t0,
  );

  Playlist list(String id, {int position = 0}) =>
      Playlist(id: id, name: '목록 $id', createdAt: t0, position: position);

  group('tables', () {
    late ShioriDatabase db;
    late DriftLibraryRepository library;
    late DriftReviewRepository reviews;

    setUp(() async {
      db = ShioriDatabase.memory();
      library = DriftLibraryRepository(db);
      reviews = DriftReviewRepository(db);
      await library.savePlaylist(list('pl'));
    });

    tearDown(() => db.close());

    test(
      'words, playlists, learning state and settings, no textbooks',
      () async {
        final tables = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name NOT LIKE 'sqlite_%' ORDER BY name",
            )
            .map((r) => r.read<String>('name'))
            .get();
        expect(tables, [
          'playlist_words',
          'playlists',
          'review_cards',
          'review_logs',
          'settings',
          'words',
        ]);
      },
    );

    test(
      'foreign keys are on: an entry needs its playlist and its word',
      () async {
        final on = await db.customSelect('PRAGMA foreign_keys').getSingle();
        expect(on.read<int>('foreign_keys'), 1);
        await library.insertWords([word('w1')]);
        await expectLater(
          db.customStatement(
            'INSERT INTO playlist_words (playlist_id, word_id, position, '
            "added_at) VALUES ('missing', 'w1', 0, 0)",
          ),
          throwsA(isA<SqliteException>()),
        );
        await expectLater(
          db.customStatement(
            'INSERT INTO playlist_words (playlist_id, word_id, position, '
            "added_at) VALUES ('pl', 'missing', 0, 0)",
          ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('a word is once per playlist (primary key)', () async {
      await library.insertWords([word('w1')]);
      await library.addToPlaylist('pl', ['w1'], at: t0);
      await expectLater(
        db.customStatement(
          'INSERT INTO playlist_words (playlist_id, word_id, position, '
          "added_at) VALUES ('pl', 'w1', 5, 0)",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a word key is unique in the table itself', () async {
      await library.insertWords([word('w1')]);
      await expectLater(
        db.customStatement(
          'INSERT INTO words (id, key, headword, readings, meaning, '
          "created_at) VALUES ('w2', '雨', '雨', '[]', '', 0)",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a blank playlist name is refused by the table', () async {
      await expectLater(
        db.customStatement(
          'INSERT INTO playlists (id, name, created_at, position) '
          "VALUES ('x', '   ', 0, 1)",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a card needs its word; deleting a playlist keeps both', () async {
      await expectLater(
        reviews.saveCard(
          ReviewCard(wordId: 'gone', level: 1, dueAt: t0, lastReviewedAt: t0),
        ),
        throwsA(isA<SqliteException>()),
      );
      await library.insertWords([word('w1')]);
      await library.addToPlaylist('pl', ['w1'], at: t0);
      final card = ReviewCard(
        wordId: 'w1',
        level: 3,
        dueAt: t0.add(const Duration(days: 7)),
        lastReviewedAt: t0,
        reviewCount: 2,
      );
      await reviews.saveCard(card);
      await library.deletePlaylist('pl');
      expect(await db.select(db.playlistWords).get(), isEmpty);
      expect(await library.word('w1'), word('w1'));
      expect(await reviews.card('w1'), card);
    });

    test(
      'cards are stored by scope; the shared scope is an empty key',
      () async {
        await library.insertWords([word('w1')]);
        await reviews.saveCard(
          ReviewCard(wordId: 'w1', level: 1, dueAt: t0, lastReviewedAt: t0),
        );
        await reviews.saveCard(
          ReviewCard(
            wordId: 'w1',
            level: 2,
            dueAt: t0,
            lastReviewedAt: t0,
            scope: CardScope.playlist('pl'),
          ),
        );
        final rows = await db
            .customSelect(
              'SELECT scope, level FROM review_cards ORDER BY scope',
            )
            .map((r) => (r.read<String>('scope'), r.read<int>('level')))
            .get();
        expect(rows, [('', 1), ('p:pl', 2)]);
      },
    );

    test('a stored scope that is not one fails loudly', () async {
      await library.insertWords([word('w1')]);
      await db.customStatement(
        'INSERT INTO review_cards (scope, word_id, level, due_at, '
        "last_reviewed_at, review_count, lapse_count) VALUES ('x', 'w1', 1, "
        '0, 0, 0, 0)',
      );
      await expectLater(
        reviews.cards(scope: CardScope.fromKey('p:x')),
        completion(isEmpty),
      );
      await expectLater(reviews.logs(), completion(isEmpty));
      await db.customStatement(
        'INSERT INTO review_logs (scope, word_id, answer, at, level_before, '
        "level_after, retries_in_session) VALUES ('x', 'w1', 'known', 0, 0, "
        '1, 0)',
      );
      await expectLater(reviews.logs(), throwsFormatException);
    });

    test('an example must have both sentence and translation', () async {
      await expectLater(
        db.customStatement(
          'INSERT INTO words (id, key, headword, readings, meaning, '
          "example_ja, created_at) VALUES ('w9', 'x', 'x', "
          "'[]', '', 'ja only', 0)",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('times are stored as UTC microseconds since the epoch', () async {
      await library.insertWords([word('w1')]);
      final raw = await db
          .customSelect("SELECT created_at FROM words WHERE id = 'w1'")
          .getSingle();
      expect(raw.read<int>('created_at'), t0.toUtc().microsecondsSinceEpoch);
      expect((await library.word('w1'))?.createdAt, t0);
    });

    test('the stored key is the word key of the headword', () async {
      await library.insertWords([word('w1', headword: '丈夫だ')]);
      final raw = await db
          .customSelect("SELECT key FROM words WHERE id = 'w1'")
          .getSingle();
      expect(raw.read<String>('key'), '丈夫');
    });

    test('broken readings fail loudly instead of reading as empty', () async {
      await db.customStatement(
        'INSERT INTO words (id, key, headword, readings, meaning, '
        "created_at) VALUES ('w9', 'x', 'x', '{\"a\":1}', '', 0)",
      );
      await expectLater(library.word('w9'), throwsFormatException);
    });
  });

  group('converters', () {
    test('readings round trip in order, and reject non-string items', () {
      const c = StringListConverter();
      expect(c.fromSql(c.toSql(const ['あ', 'い'])), ['あ', 'い']);
      expect(c.fromSql('[]'), isEmpty);
      expect(() => c.fromSql('[1]'), throwsFormatException);
      expect(() => c.fromSql('not json'), throwsFormatException);
    });

    test('times keep microseconds and read back as local time', () {
      const c = UtcMicrosConverter();
      final utc = DateTime.utc(2026, 1, 1, 0, 0, 0, 0, 1);
      final back = c.fromSql(c.toSql(utc));
      expect(back.isAtSameMomentAs(utc), isTrue);
      expect(back.isUtc, isFalse);
      expect(c.fromSql(c.toSql(t0)), t0);
    });
  });

  group('file', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('shiori_db_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'a v4 file keeps words, playlists, learning state and settings',
      () async {
        final file = File('${dir.path}/shiori.sqlite');
        final first = ShioriDatabase.file(file);
        final lib1 = DriftLibraryRepository(first);
        final rev1 = DriftReviewRepository(first);
        await lib1.savePlaylist(list('pl'));
        await lib1.insertWords([word('w1')]);
        await lib1.addToPlaylist('pl', ['w1'], at: t0);
        await lib1.hideWords(['w1'], at: t0);
        final card = ReviewCard(
          wordId: 'w1',
          level: 4,
          dueAt: t0.add(const Duration(days: 21)),
          lastReviewedAt: t0,
          reviewCount: 1,
        );
        await rev1.transaction(() async {
          await rev1.saveCard(card);
          await rev1.addLog(
            ReviewLog(
              wordId: 'w1',
              answer: Answer.known,
              at: t0,
              levelBefore: 0,
              levelAfter: 4,
              retriesInSession: 0,
            ),
          );
        });
        const prefs = StudyPreferences(recordMode: RecordMode.perPlaylist);
        await DriftStudyPreferencesRepository(first).save(prefs);
        await first.close();

        final second = ShioriDatabase.file(file);
        addTearDown(second.close);
        final lib2 = DriftLibraryRepository(second);
        expect(await lib2.word('w1'), word('w1').withHiddenAt(t0));
        expect(await lib2.playlists(), [list('pl')]);
        expect((await lib2.words(playlistId: 'pl')).single.id, 'w1');
        final rev2 = DriftReviewRepository(second);
        expect(await rev2.card('w1'), card);
        expect((await rev2.logs()).single.at, t0);
        expect(await DriftStudyPreferencesRepository(second).load(), prefs);
        final version = await second
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 5);
      },
    );

    test('a file from an unknown schema version is refused', () async {
      final file = File('${dir.path}/newer.sqlite');
      // One past the version this build writes.
      final current = ShioriDatabase.memory();
      final next = current.schemaVersion + 1;
      await current.close();
      final newer = ShioriDatabase(
        NativeDatabase(file, setup: (raw) => raw.userVersion = next),
      );
      await expectLater(
        newer.customSelect('SELECT 1').get(),
        throwsA(isA<UnsupportedError>()),
      );
      await newer.close();
    });
  });
}
