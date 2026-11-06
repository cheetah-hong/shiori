import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:shiori_core/shiori_core.dart' show Answer, PartOfSpeech;
import 'package:shiori_storage_drift/src/converters.dart';
import 'package:shiori_storage_drift/src/tables.dart';

part 'database.g.dart';

/// Called inside the transaction that empties a file of an older schema,
/// after the old tables are gone (tests use it to make that step fail).
typedef ResetHook = Future<void> Function();

/// The app's SQLite file: library words, playlists, learning state and
/// settings.
///
/// Changing a table means a new [schemaVersion]; see docs/verification.md
/// (저장소) for the dump and migration test steps.
@DriftDatabase(
  tables: [Words, Playlists, PlaylistWords, ReviewCards, ReviewLogs, Settings],
)
final class ShioriDatabase extends _$ShioriDatabase {
  ShioriDatabase(super.e, {ResetHook? onReset}) : _onReset = onReset;

  /// A database file, opened on a background isolate on first use.
  factory ShioriDatabase.file(File file, {ResetHook? onReset}) =>
      ShioriDatabase(NativeDatabase.createInBackground(file), onReset: onReset);

  /// A database that lives only as long as this object (tests).
  factory ShioriDatabase.memory() => ShioriDatabase(NativeDatabase.memory());

  final ResetHook? _onReset;

  @override
  int get schemaVersion => 4;

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
      // v1 to v3 held textbooks and days. v4 does not carry them over: the
      // file is emptied and starts as v4 (docs/verification.md, 21). All in
      // one transaction: a failure leaves the old file as it was.
      if (from < 4) await transaction(() => _reset(m));
    },
    // Journal mode and sync level stay at SQLite's defaults (rollback journal,
    // FULL): writes are small and durability matters more than speed.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
