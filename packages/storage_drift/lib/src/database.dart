import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift/internal/versioned_schema.dart';
import 'package:shiori_core/shiori_core.dart' show Answer, PartOfSpeech;
import 'package:shiori_storage_drift/src/converters.dart';
import 'package:shiori_storage_drift/src/database.steps.dart';
import 'package:shiori_storage_drift/src/tables.dart';

part 'database.g.dart';

/// The app's SQLite file: content tables and learning-state tables.
///
/// Changing a table means a new [schemaVersion]; see docs/verification.md
/// (저장소) for the dump and migration test steps.
@DriftDatabase(
  tables: [Textbooks, TextbookDays, Words, ReviewCards, ReviewLogs],
)
final class ShioriDatabase extends _$ShioriDatabase {
  ShioriDatabase(super.e);

  /// A database file, opened on a background isolate on first use.
  factory ShioriDatabase.file(File file) =>
      ShioriDatabase(NativeDatabase.createInBackground(file));

  /// A database that lives only as long as this object (tests).
  factory ShioriDatabase.memory() => ShioriDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // A newer schema (a file written by a newer app) is not guessed at.
      if (from > to) {
        throw UnsupportedError(
          'database schema $from cannot be opened by schema $to',
        );
      }
      // All steps or none: a step that fails leaves the old file as it was.
      await transaction(
        () => VersionedSchema.runMigrationSteps(
          migrator: m,
          from: from,
          to: to,
          steps: migrationSteps(from1To2: _from1To2),
        ),
      );
    },
    // Journal mode and sync level stay at SQLite's defaults (rollback journal,
    // FULL): writes are small and durability matters more than speed.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// v2: `words.important` (the textbook's ★) is gone. The table is rebuilt
/// without it; every other column and row is copied as it was.
Future<void> _from1To2(Migrator m, Schema2 schema) =>
    m.alterTable(TableMigration(schema.words));
