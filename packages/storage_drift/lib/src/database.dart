import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:shiori_core/shiori_core.dart' show Answer, PartOfSpeech;
import 'package:shiori_storage_drift/src/converters.dart';
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Version 2 plugs in here: `stepByStep(from1To2: ...)` from the generated
    // steps file. Until then any other version is a file this build cannot
    // read (for example one written by a newer app); fail instead of guessing.
    onUpgrade: (m, from, to) async => throw UnsupportedError(
      'database schema $from cannot be opened by schema $to',
    ),
    // Journal mode and sync level stay at SQLite's defaults (rollback journal,
    // FULL): writes are small and durability matters more than speed.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
