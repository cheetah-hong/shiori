// Schema checks against the dumps in drift_schemas/. When a version is added:
//   1. bump ShioriDatabase.schemaVersion and write the step in `onUpgrade`
//   2. dart run drift_dev make-migrations   (dump, steps file, helpers)
//   3. add a case below for every older version: open it, migrate, validate,
//      and check that rows written in the old schema are still readable.
import 'package:drift_dev/api/migrations_native.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the current schema matches the latest dump (v1)', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    expect(db.schemaVersion, 1);
    await db.validateDatabaseSchema();
  });

  test('a v1 file opens and validates as v1', () async {
    final schema = await verifier.schemaAt(1);
    final db = ShioriDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 1);
  });

  test('rows written by a v1 file read back through the blocks', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    final at = DateTime(2026, 11, 5, 21).microsecondsSinceEpoch;
    await old.customStatement(
      'INSERT INTO textbooks (id, title, created_at) VALUES (?, ?, ?)',
      ['tb', '단어장', at],
    );
    await old.customStatement(
      'INSERT INTO words (id, textbook_id, day, no, headword, readings, pos, '
      'meaning, important, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      ['tb:0001', 'tb', 1, '0001', '雨', '["あめ"]', 'noun', '비', 1, at],
    );
    await old.customStatement(
      'INSERT INTO review_cards (word_id, level, due_at, last_reviewed_at, '
      'review_count, lapse_count) VALUES (?, ?, ?, ?, ?, ?)',
      ['tb:0001', 2, at, at, 1, 1],
    );
    await old.close();

    final db = ShioriDatabase(schema.newConnection());
    addTearDown(db.close);
    final word = await DriftLibraryRepository(db).word('tb:0001');
    expect((word?.headword, word?.pos), ('雨', PartOfSpeech.noun));
    expect(word?.readings, ['あめ']);
    expect((await DriftReviewRepository(db).card('tb:0001'))?.level, 2);
  });
}
