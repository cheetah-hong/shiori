import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:shiori_core/shiori_core.dart'
    show Answer, PartOfSpeech, StudyMode;
import 'package:shiori_storage_drift/src/converters.dart';
import 'package:shiori_storage_drift/src/database.steps.dart';
import 'package:shiori_storage_drift/src/tables.dart';

part 'database.g.dart';

/// Called inside the transaction that empties a file of an older schema,
/// after the old tables are gone (tests use it to make that step fail).
typedef ResetHook = Future<void> Function();

/// Called inside the transaction that carries a v4 file over, after the
/// tables are changed and the new version is written (tests use it to make
/// that step fail, or to look inside it).
typedef MigrateHook = Future<void> Function();

/// The app's SQLite file: library words, playlists, learning state and
/// settings.
///
/// Changing a table means a new [schemaVersion]; see docs/verification.md
/// (저장소) for the dump and migration test steps.
@DriftDatabase(
  tables: [Words, Playlists, PlaylistWords, ReviewCards, ReviewLogs, Settings],
)
final class ShioriDatabase extends _$ShioriDatabase {
  ShioriDatabase(super.e, {ResetHook? onReset, MigrateHook? onMigrate})
    : _onReset = onReset,
      _onMigrate = onMigrate;

  /// A database file, opened on a background isolate on first use.
  factory ShioriDatabase.file(
    File file, {
    ResetHook? onReset,
    MigrateHook? onMigrate,
  }) => ShioriDatabase(
    NativeDatabase.createInBackground(file),
    onReset: onReset,
    onMigrate: onMigrate,
  );

  /// A database that lives only as long as this object (tests).
  factory ShioriDatabase.memory() => ShioriDatabase(NativeDatabase.memory());

  final ResetHook? _onReset;

  final MigrateHook? _onMigrate;

  /// v4 → v5: cards and presses get a study mode. Every card and press so far
  /// was 뜻 맞히기 (`StudyMode.meaning`); the card table is rebuilt for its new
  /// primary key (scope, mode, word), keeping every row.
  OnUpgrade get _steps => stepByStep(
    // Files older than v4 are emptied in `onUpgrade` and never come here.
    from1To2: _emptiedInstead,
    from2To3: _emptiedInstead,
    from3To4: _emptiedInstead,
    from4To5: (m, schema) async {
      await m.alterTable(
        TableMigration(
          schema.reviewCards,
          newColumns: [schema.reviewCards.mode],
          columnTransformer: {
            schema.reviewCards.mode: Constant(StudyMode.meaning.name),
          },
        ),
      );
      await m.addColumn(schema.reviewLogs, schema.reviewLogs.mode);
    },
  );

  @override
  int get schemaVersion => 5;

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
      // v1 to v3 held textbooks and days. v4 did not carry them over: the
      // file is emptied and starts as the current schema
      // (docs/verification.md, 21). All in one transaction: a failure leaves
      // the old file as it was.
      if (from < 4) {
        await transaction(() => _reset(m));
        return;
      }
      // From v4 on every step keeps the learner's data, also in one
      // transaction. drift writes the new version after this callback,
      // outside it; written here too, the tables and the version land
      // together, so a stop in between cannot leave a v5 file marked v4
      // (which the step could not run on twice).
      await transaction(() async {
        await _steps(m, from, to);
        await customStatement('PRAGMA user_version = $to');
        await _onMigrate?.call();
      });
    },
    // Journal mode and sync level stay at SQLite's defaults (rollback journal,
    // FULL): writes are small and durability matters more than speed.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static Future<void> _emptiedInstead(Migrator m, Object schema) =>
      throw StateError('a file older than v4 is emptied, not migrated');

  /// Drops every table, index, view and trigger the file holds (whatever an
  /// older version made), then creates the v4 schema.
  Future<void> _reset(Migrator m) async {
    final objects = await customSelect(
      "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' "
      "AND type IN ('table', 'view', 'trigger')",
    ).get();
    for (final o in objects) {
      final type = o.read<String>('type').toUpperCase();
      final name = o.read<String>('name').replaceAll('"', '""');
      // Indexes go with their tables.
      await customStatement('DROP $type IF EXISTS "$name"');
    }
    await _onReset?.call();
    await m.createAll();
  }
}
