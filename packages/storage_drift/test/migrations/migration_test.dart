// Schema checks against the dumps in drift_schemas/. When a version is added:
//   1. change the tables, bump ShioriDatabase.schemaVersion
//   2. dart run drift_dev make-migrations   (dump and steps file), then
//      dart run drift_dev schema generate drift_schemas/shiori_database/ \
//        test/migrations/generated/        (test helpers)
//   3. write the step in `onUpgrade` (`stepByStep`)
//   4. add a case below for every older version: open it, migrate, validate,
//      and check that rows written in the old schema are still there.
//   5. move the "unknown version" test (drift_storage_test.dart) along: it
//      uses schemaVersion + 1.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

const _tables = [
  'textbooks',
  'textbook_days',
  'words',
  'review_cards',
  'review_logs',
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

Future<List<String>> _columns(GeneratedDatabase db, String table) async => [
  for (final r in await db.customSelect('PRAGMA table_info($table)').get())
    r.read<String>('name'),
];

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

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the current schema matches the latest dump (v3)', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    expect(db.schemaVersion, 3);
    await db.validateDatabaseSchema();
  });

  test('a new database is v3: words have hidden_at, no important', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 3);
    final columns = await _columns(db, 'words');
    expect(columns, isNot(contains('important')));
    expect(columns, contains('hidden_at'));
  });

  test('a v3 file opens and validates as v3', () async {
    final schema = await verifier.schemaAt(3);
    final db = ShioriDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);
  });

  for (final from in [1, 2]) {
    test('a v$from file migrates to v3 and validates', () async {
      final schema = await verifier.schemaAt(from);
      final db = ShioriDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 3);
    });
  }

  test('v1 → v3 drops only important and hides nothing: every row and other '
      'cell stays', () async {
    final schema = await verifier.schemaAt(1);
    final at = DateTime(2026, 11, 5, 21).microsecondsSinceEpoch;
    final old = v1.DatabaseAtV1(schema.newConnection());
    await _fillV1(old, at);
    final before = {
      for (final t in _tables) t: await _rows(old, t, drop: {'important'}),
    };
    expect(before['words'], hasLength(3));
    await old.close();

    final db = ShioriDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);
    expect(await _columns(db, 'words'), isNot(contains('important')));
    for (final t in _tables) {
      expect(await _rows(db, t, drop: {'hidden_at'}), before[t], reason: t);
    }
    expect(
      (await _rows(db, 'words')).map((r) => r['hidden_at']),
      everyElement(isNull),
    );

    // And through the blocks.
    final library = DriftLibraryRepository(db);
    final rain = await library.word('tb:0001');
    expect(
      (rain?.headword, rain?.pos, rain?.page, rain?.isHidden),
      ('雨', PartOfSpeech.noun, 10, false),
    );
    expect(rain?.readings, ['あめ']);
    final ride = await library.word('tb:1211');
    expect(ride?.readings, ['のる', 'じょう']);
    expect(ride?.example, const Example(ja: '電車に乗る。', ko: '전철을 타다.'));
    expect(await library.days('tb'), hasLength(2));
    final reviews = DriftReviewRepository(db);
    expect((await reviews.card('tb:0001'))?.level, 2);
    expect(await reviews.logs(), hasLength(2));
  });

  test('v2 → v3 adds hidden_at only: every row and value stays and no word '
      'is hidden', () async {
    final schema = await verifier.schemaAt(2);
    final at = DateTime(2026, 11, 5, 21, 30, 0, 0, 7).microsecondsSinceEpoch;
    final old = v2.DatabaseAtV2(schema.newConnection());
    await _fillV2(old, at);
    final before = {for (final t in _tables) t: await _rows(old, t)};
    expect(before['textbooks'], hasLength(2));
    expect(before['words'], hasLength(5));
    expect(before['review_cards'], hasLength(3));
    expect(before['review_logs'], hasLength(4));
    final oldColumns = await _columns(old, 'words');
    await old.close();

    final db = ShioriDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 3);
    expect(await _columns(db, 'words'), [...oldColumns, 'hidden_at']);
    for (final t in _tables) {
      expect(await _rows(db, t, drop: {'hidden_at'}), before[t], reason: t);
    }
    expect(
      (await _rows(db, 'words')).map((r) => r['hidden_at']),
      everyElement(isNull),
    );

    // And through the blocks: nothing hidden, cards and logs as they were.
    final library = DriftLibraryRepository(db);
    final words = await library.words();
    expect(words, hasLength(5));
    expect(words.where((w) => w.isHidden), isEmpty);
    expect(await library.hiddenWords(), isEmpty);
    expect(
      (await library.textbookStats()).map(
        (s) => (s.textbook.id, s.wordCount, s.hiddenCount),
      ),
      [('tb', 4, 0), ('tb2', 1, 0)],
    );
    final ride = await library.word('tb:1211');
    expect(ride?.example, const Example(ja: '電車に乗る。', ko: '전철을 타다.'));
    expect(ride?.createdAt, DateTime.fromMicrosecondsSinceEpoch(at));
    final reviews = DriftReviewRepository(db);
    final cards = await reviews.cards();
    expect(
      {for (final c in cards.values) c.wordId: (c.level, c.reviewCount)},
      {'tb:0001': (2, 3), 'tb:1211': (1, 3), 'tb2:0001': (4, 3)},
    );
    expect(
      (await reviews.logs()).map((l) => (l.wordId, l.answer, l.levelAfter)),
      [
        ('tb:0001', Answer.known, 2),
        ('tb:1211', Answer.retry, 1),
        ('tb:1211', Answer.known, 1),
        ('tb2:0001', Answer.known, 4),
      ],
    );
  });
}
