// Schema checks against the dumps in drift_schemas/. v4 (playlists) does not
// carry older data over: a v1, v2 or v3 file is emptied and starts as v4.
// When a version is added:
//   1. change the tables, bump ShioriDatabase.schemaVersion
//   2. dart run drift_dev make-migrations   (dump and steps file; delete the
//      example tests it writes to test/migrations/shiori_database/), then
//      dart run drift_dev schema generate drift_schemas/shiori_database/ \
//        test/migrations/generated/        (test helpers)
//   3. write the step in `onUpgrade`
//   4. add a case below for every older version: open it, migrate, validate,
//      and check what happened to the rows written in the old schema.
//   5. move the "unknown version" test (drift_storage_test.dart) along: it
//      uses schemaVersion + 1.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

/// The tables of v1 to v3.
const _oldTables = [
  'textbooks',
  'textbook_days',
  'words',
  'review_cards',
  'review_logs',
];

/// The tables of v4.
const _v4Tables = [
  'playlist_words',
  'playlists',
  'review_cards',
  'review_logs',
  'settings',
  'words',
];

/// Every row of [table] as column → value, in primary key order, without
/// the columns in [drop].
Future<List<Map<String, Object?>>> _rows(
  GeneratedDatabase db,
  String table, {
  Set<String> drop = const {},
}) async {
  final rows = await db
      .customSelect('SELECT * FROM $table ORDER BY 1, 2')
      .get();
  return [
    for (final r in rows)
      {
        for (final MapEntry(:key, :value) in r.data.entries)
          if (!drop.contains(key)) key: value,
      },
  ];
}

/// Every table, index and trigger in the file, by type and name.
Future<List<(String, String)>> _objects(GeneratedDatabase db) => db
    .customSelect(
      "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' "
      'ORDER BY type, name',
    )
    .map((r) => (r.read<String>('type'), r.read<String>('name')))
    .get();

Future<int> _userVersion(GeneratedDatabase db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );

Future<Map<String, int>> _counts(
  GeneratedDatabase db,
  List<String> tables,
) async => {
  for (final t in tables)
    t: (await db.customSelect('SELECT COUNT(*) AS n FROM $t').getSingle())
        .read<int>('n'),
};

Future<void> _insert(GeneratedDatabase db, String sql, List<Object?> args) =>
    db.customStatement(sql, args);

/// One textbook, two days, three words (one marked ★ in v1), cards and logs.
Future<void> _fillV1(v1.DatabaseAtV1 old, int at) async {
  Future<void> insert(String sql, List<Object?> args) =>
      _insert(old, sql, args);
  await insert(
    'INSERT INTO textbooks (id, title, created_at, template_id) '
    'VALUES (?, ?, ?, ?)',
    ['tb', '단어장', at, 'vocab.list'],
  );
  for (final (n, title) in [(1, '자연'), (2, '여행')]) {
    await insert(
      'INSERT INTO textbook_days (textbook_id, number, title) VALUES (?, ?, ?)',
      ['tb', n, title],
    );
  }
  for (final w in [
    ['tb:0001', 1, '0001', '雨', '["あめ"]', 'noun', '비', 1, null, null, 10],
    ['tb:0002', 1, '0002', '空', '["そら"]', null, '하늘', 0, null, null, null],
    [
      'tb:1211',
      2,
      '1211',
      '乗る',
      '["のる","じょう"]',
      'verb',
      '타다',
      0,
      '電車に乗る。',
      '전철을 타다.',
      140,
    ],
  ]) {
    await insert(
      'INSERT INTO words (id, textbook_id, day, no, headword, readings, pos, '
      'meaning, important, example_ja, example_ko, page, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [w.first, 'tb', ...w.skip(1), at],
    );
  }
  for (final (id, level) in [('tb:0001', 2), ('tb:1211', 0)]) {
    await insert(
      'INSERT INTO review_cards (word_id, level, due_at, last_reviewed_at, '
      'review_count, lapse_count) VALUES (?, ?, ?, ?, ?, ?)',
      [id, level, at + 1, at, 3, 1],
    );
  }
  for (final (id, answer) in [('tb:0001', 'known'), ('tb:1211', 'retry')]) {
    await insert(
      'INSERT INTO review_logs (word_id, answer, at, level_before, '
      'level_after, retries_in_session) VALUES (?, ?, ?, ?, ?, ?)',
      [id, answer, at, 1, 2, 1],
    );
  }
}

/// Two textbooks, three days, five words (with and without an example and a
/// day), three cards and four logs, written in the v2 schema.
Future<void> _fillV2(v2.DatabaseAtV2 old, int at) async {
  for (final (id, title, created, template) in [
    ('tb', '단어장', at, 'vocab.list'),
    ('tb2', '두 번째', at + 5, null),
  ]) {
    await _insert(
      old,
      'INSERT INTO textbooks (id, title, created_at, template_id) '
      'VALUES (?, ?, ?, ?)',
      [id, title, created, template],
    );
  }
  for (final (tb, n, title) in [
    ('tb', 1, '자연'),
    ('tb', 2, '여행'),
    ('tb2', 1, ''),
  ]) {
    await _insert(
      old,
      'INSERT INTO textbook_days (textbook_id, number, title) VALUES (?, ?, ?)',
      [tb, n, title],
    );
  }
  for (final w in [
    ['tb:0001', 'tb', 1, '0001', '雨', '["あめ"]', 'noun', '비', null, null, 10],
    ['tb:0002', 'tb', 1, '0002', '空', '["そら"]', null, '하늘', null, null, null],
    [
      'tb:1211',
      'tb',
      2,
      '1211',
      '乗る',
      '["のる","じょう"]',
      'verb',
      '타다',
      '電車に乗る。',
      '전철을 타다.',
      140,
    ],
    ['tb:p3-1', 'tb', null, null, '川', '[]', null, '강', null, null, 3],
    ['tb2:0001', 'tb2', 1, '0001', '山', '["やま"]', 'noun', '산', null, null, 1],
  ]) {
    await _insert(
      old,
      'INSERT INTO words (id, textbook_id, day, no, headword, readings, pos, '
      'meaning, example_ja, example_ko, page, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [...w, at],
    );
  }
  for (final (id, level, due) in [
    ('tb:0001', 2, at + 1),
    ('tb:1211', 1, at - 1),
    ('tb2:0001', 4, at + 7),
  ]) {
    await _insert(
      old,
      'INSERT INTO review_cards (word_id, level, due_at, last_reviewed_at, '
      'review_count, lapse_count) VALUES (?, ?, ?, ?, ?, ?)',
      [id, level, due, at, 3, 1],
    );
  }
  for (final (id, answer, after) in [
    ('tb:0001', 'known', 2),
    ('tb:1211', 'retry', 1),
    ('tb:1211', 'known', 1),
    ('tb2:0001', 'known', 4),
  ]) {
    await _insert(
      old,
      'INSERT INTO review_logs (word_id, answer, at, level_before, '
      'level_after, retries_in_session) VALUES (?, ?, ?, ?, ?, ?)',
      [id, answer, at, 1, after, 1],
    );
  }
}

/// What a learner's v3 file looks like after some weeks: two textbooks (one
/// read with a row template), days, 40 numbered and unnumbered words (some
/// hidden, some with an example), cards, logs, and an index the app did not
/// make.
Future<void> _fillV3(v3.DatabaseAtV3 old, int at) async {
  for (final (id, title, created, template) in [
    ('tb', 'JLPT 단어장', at, 'vocab.list'),
    ('tb-2', '내 단어장', at + 5, null),
  ]) {
    await _insert(
      old,
      'INSERT INTO textbooks (id, title, created_at, template_id) '
      'VALUES (?, ?, ?, ?)',
      [id, title, created, template],
    );
  }
  for (final n in [1, 2, 3]) {
    await _insert(
      old,
      'INSERT INTO textbook_days (textbook_id, number, title) VALUES (?, ?, ?)',
      ['tb', n, 'DAY $n'],
    );
  }
  for (var i = 0; i < 40; i++) {
    final book = i < 30 ? 'tb' : 'tb-2';
    final numbered = book == 'tb';
    await _insert(
      old,
      'INSERT INTO words (id, textbook_id, day, no, headword, readings, pos, '
      'meaning, example_ja, example_ko, page, created_at, hidden_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        numbered ? '$book:${i.toString().padLeft(4, '0')}' : '$book:w$at-$i',
        book,
        numbered ? 1 + i ~/ 10 : null,
        numbered ? i.toString().padLeft(4, '0') : null,
        '語$i',
        '["ご"]',
        i.isEven ? 'noun' : null,
        '말 $i',
        i % 7 == 0 ? '例文$i。' : null,
        i % 7 == 0 ? '예문 $i.' : null,
        numbered ? 10 + i ~/ 10 : null,
        at + i,
        i % 9 == 0 ? at + 100 : null,
      ],
    );
  }
  for (var i = 0; i < 25; i++) {
    await _insert(
      old,
      'INSERT INTO review_cards (word_id, level, due_at, last_reviewed_at, '
      'review_count, lapse_count) VALUES (?, ?, ?, ?, ?, ?)',
      ['tb:${i.toString().padLeft(4, '0')}', 1 + i % 4, at + i, at, i, i % 3],
    );
    await _insert(
      old,
      'INSERT INTO review_logs (word_id, answer, at, level_before, '
      'level_after, retries_in_session) VALUES (?, ?, ?, ?, ?, ?)',
      [
        'tb:${i.toString().padLeft(4, '0')}',
        i.isEven ? 'known' : 'retry',
        at + i,
        0,
        1 + i % 4,
        i % 2,
      ],
    );
  }
  await old.customStatement('CREATE INDEX words_by_meaning ON words (meaning)');
}

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the current schema matches the latest dump (v4)', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    expect(db.schemaVersion, 4);
    await db.validateDatabaseSchema();
  });

  test(
    'a new database is v4 with the playlist tables and no textbooks',
    () async {
      final db = ShioriDatabase.memory();
      addTearDown(db.close);
      expect(await _userVersion(db), 4);
      expect([
        for (final (type, name) in await _objects(db))
          if (type == 'table') name,
      ], _v4Tables);
    },
  );

  test('a v4 file opens and validates as v4', () async {
    final schema = await verifier.schemaAt(4);
    final db = ShioriDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
  });

  for (final from in [1, 2, 3]) {
    test('an empty v$from file becomes v4 and validates', () async {
      final schema = await verifier.schemaAt(from);
      final db = ShioriDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);
    });
  }

  group('an older file with data is emptied, not carried over', () {
    Future<void> expectEmptyV4(GeneratedDatabase db) async {
      final fresh = ShioriDatabase.memory();
      addTearDown(fresh.close);
      await fresh.customSelect('SELECT 1').get();
      expect(await _userVersion(db), 4);
      expect(await _objects(db), await _objects(fresh));
      expect(await _counts(db, _v4Tables), {for (final t in _v4Tables) t: 0});
    }

    /// The blocks work on the emptied file: add a page, study it.
    Future<void> expectWorking(ShioriDatabase db) async {
      final now = DateTime(2026, 11, 6, 15);
      final library = LibraryService(
        library: DriftLibraryRepository(db),
        clock: FixedClock(now),
      );
      final added = await library.addDraft(
        const CaptureDraft(
          entries: [
            CapturedEntry(
              headword: '語0',
              readings: ['ご'],
              pos: PartOfSpeech.noun,
              meaning: '말',
            ),
          ],
        ),
        to: const NewPlaylist(defaultPlaylistName),
      );
      expect(added.added, 1, reason: 'an old word does not count as known');
      final study = StudyService(
        library: DriftLibraryRepository(db),
        reviews: DriftReviewRepository(db),
        scheduler: const LeitnerFourStepScheduler(),
        clock: FixedClock(now),
      );
      final session = await study.startSession();
      expect(session.queue.single.isNew, isTrue);
      await study.answer(session, Answer.known);
      expect((await study.summary()).knownToday, 1);
    }

    test('v1', () async {
      final schema = await verifier.schemaAt(1);
      final old = v1.DatabaseAtV1(schema.newConnection());
      await _fillV1(old, DateTime(2026, 11, 5, 21).microsecondsSinceEpoch);
      expect((await _counts(old, _oldTables))['words'], 3);
      await old.close();

      final db = ShioriDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);
      await expectEmptyV4(db);
      await expectWorking(db);
    });

    test('v2', () async {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      await _fillV2(old, DateTime(2026, 11, 5, 21).microsecondsSinceEpoch);
      expect((await _counts(old, _oldTables))['words'], 5);
      await old.close();

      final db = ShioriDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);
      await expectEmptyV4(db);
      await expectWorking(db);
    });

    test('v3 file on disk, as a learner has it', () async {
      final dir = Directory.systemTemp.createTempSync('shiori_v3_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/shiori.sqlite');
      final old = v3.DatabaseAtV3(NativeDatabase(file));
      await _fillV3(old, DateTime(2026, 11, 5, 21).microsecondsSinceEpoch);
      expect(await _userVersion(old), 3);
      expect(await _counts(old, _oldTables), {
        'textbooks': 2,
        'textbook_days': 3,
        'words': 40,
        'review_cards': 25,
        'review_logs': 25,
      });
      await old.close();

      final db = ShioriDatabase.file(file);
      await expectEmptyV4(db);
      await expectWorking(db);
      await db.close();

      // Opened again, it is the v4 file with what was added after.
      final again = ShioriDatabase.file(file);
      addTearDown(again.close);
      expect(await _userVersion(again), 4);
      expect(
        (await DriftLibraryRepository(again).words()).single.headword,
        '語0',
      );
      expect(await DriftReviewRepository(again).cards(), hasLength(1));
    });

    test('a failure while emptying leaves the v3 file as it was', () async {
      final dir = Directory.systemTemp.createTempSync('shiori_v3_fail_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/shiori.sqlite');
      final old = v3.DatabaseAtV3(NativeDatabase(file));
      await _fillV3(old, DateTime(2026, 11, 5, 21).microsecondsSinceEpoch);
      final before = {for (final t in _oldTables) t: await _rows(old, t)};
      final objects = await _objects(old);
      await old.close();

      final failing = ShioriDatabase.file(
        file,
        onReset: () async => throw StateError('disk full'),
      );
      await expectLater(
        failing.customSelect('SELECT 1').get(),
        throwsA(predicate((e) => '$e'.contains('disk full'))),
      );
      await failing.close();

      final raw = v3.DatabaseAtV3(NativeDatabase(file));
      expect(await _userVersion(raw), 3);
      expect(await _objects(raw), objects);
      for (final t in _oldTables) {
        expect(await _rows(raw, t), before[t], reason: t);
      }
      await raw.close();

      // The next try (a new connection) empties it.
      final retry = ShioriDatabase.file(file);
      addTearDown(retry.close);
      await expectEmptyV4(retry);
    });
  });
}
