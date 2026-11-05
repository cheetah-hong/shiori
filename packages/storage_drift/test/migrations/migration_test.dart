// Schema checks against the dumps in drift_schemas/. When a version is added:
//   1. change the tables, bump ShioriDatabase.schemaVersion
//   2. dart run drift_dev make-migrations   (dump and steps file), then
//      dart run drift_dev schema generate drift_schemas/shiori_database/ \
//        test/migrations/generated/        (test helpers)
//   3. write the step in `onUpgrade` (`stepByStep`)
//   4. add a case below for every older version: open it, migrate, validate,
//      and check that rows written in the old schema are still there.
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

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

/// One textbook, two days, three words (one marked ★ in v1), cards and logs.
Future<void> _fillV1(v1.DatabaseAtV1 old, int at) async {
  Future<void> insert(String sql, List<Object?> args) =>
      old.customStatement(sql, args);
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

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the current schema matches the latest dump (v2)', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    expect(db.schemaVersion, 2);
    await db.validateDatabaseSchema();
  });

  test('a new database is v2 and its words have no important column', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 2);
    expect(await _columns(db, 'words'), isNot(contains('important')));
  });

  test('a v2 file opens and validates as v2', () async {
    final schema = await verifier.schemaAt(2);
    final db = ShioriDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);
  });

  test('a v1 file migrates to v2 and validates', () async {
    final schema = await verifier.schemaAt(1);
    final db = ShioriDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);
  });

  test(
    'v1 → v2 drops only important: every row and other cell stays',
    () async {
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
      await verifier.migrateAndValidate(db, 2);
      expect(await _columns(db, 'words'), isNot(contains('important')));
      for (final t in _tables) {
        expect(await _rows(db, t), before[t], reason: t);
      }

      // And through the blocks.
      final library = DriftLibraryRepository(db);
      final rain = await library.word('tb:0001');
      expect(
        (rain?.headword, rain?.pos, rain?.page),
        ('雨', PartOfSpeech.noun, 10),
      );
      expect(rain?.readings, ['あめ']);
      final ride = await library.word('tb:1211');
      expect(ride?.readings, ['のる', 'じょう']);
      expect(ride?.example, const Example(ja: '電車に乗る。', ko: '전철을 타다.'));
      expect(await library.days('tb'), hasLength(2));
      final reviews = DriftReviewRepository(db);
      expect((await reviews.card('tb:0001'))?.level, 2);
      expect(await reviews.logs(), hasLength(2));
    },
  );
}
