import 'package:shiori_core/shiori_core.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

/// Schema version written by tools/dict/build_examples.py
/// (`PRAGMA user_version`).
const int exampleSchemaVersion = 1;

/// Ids asked in one query: well under SQLite's limit of bound parameters.
const int _idsPerQuery = 500;

/// The file is not an example sentence database this package can read.
final class ExampleFormatException implements Exception {
  const ExampleFormatException(this.message);

  final String message;

  @override
  String toString() => 'ExampleFormatException: $message';
}

/// Tatoeba sentences by JMdict entry from the example SQLite file: at most
/// one sentence per entry and reading (reading '' = any).
///
/// Calls are synchronous and take well under a millisecond.
final class TatoebaExamples implements ExampleSentences {
  TatoebaExamples._(this._db, this._meta);

  /// Opens the database at [path] read-only.
  ///
  /// Throws [ExampleFormatException] when the file was not built by
  /// build_examples.py with schema [exampleSchemaVersion].
  factory TatoebaExamples.open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    var opened = false;
    try {
      final examples = TatoebaExamples.fromDatabase(db);
      opened = true;
      return examples;
    } finally {
      if (!opened) db.close();
    }
  }

  /// Uses an already open database (tests load the SQL fixture in memory).
  factory TatoebaExamples.fromDatabase(CommonDatabase db) {
    try {
      final version = db.select('PRAGMA user_version').first.columnAt(0);
      if (version != exampleSchemaVersion) {
        throw ExampleFormatException(
          'schema $version, expected $exampleSchemaVersion; rebuild the file',
        );
      }
      final meta = {
        for (final row in db.select('SELECT key, value FROM meta'))
          row.columnAt(0) as String: row.columnAt(1) as String,
      };
      db.select(
        'SELECT entry, reading, sentence, ja, ko, en, surface '
        'FROM example LIMIT 1',
      );
      return TatoebaExamples._(db, meta);
    } on SqliteException catch (e) {
      throw ExampleFormatException('not an example database: ${e.message}');
    }
  }

  final CommonDatabase _db;
  final Map<String, String> _meta;

  /// The Tatoeba export the sentences are from (YYYY-MM-DD).
  String get edition => _meta['tatoeba.edition'] ?? '';

  /// Day the file was built.
  String get builtOn => _meta['built_on'] ?? '';

  /// Licence of the sentences.
  String get license => _meta['tatoeba.license'] ?? '';

  @override
  Future<List<StoredExample>> lookup(Iterable<int> entryIds) async {
    final ids = entryIds.toSet().toList();
    final byEntry = <int, List<StoredExample>>{};
    for (var i = 0; i < ids.length; i += _idsPerQuery) {
      final part = ids.sublist(
        i,
        i + _idsPerQuery > ids.length ? ids.length : i + _idsPerQuery,
      );
      final rows = _db.select(
        'SELECT entry, reading, sentence, ja, ko, en, surface FROM example '
        'WHERE entry IN (${List.filled(part.length, '?').join(',')}) '
        'ORDER BY entry, reading',
        part,
      );
      for (final r in rows) {
        final row = StoredExample(
          entryId: r.columnAt(0) as int,
          reading: r.columnAt(1) as String,
          sentenceId: r.columnAt(2) as int,
          ja: r.columnAt(3) as String,
          ko: r.columnAt(4) as String?,
          en: r.columnAt(5) as String?,
          surface: r.columnAt(6) as String?,
        );
        (byEntry[row.entryId] ??= []).add(row);
      }
    }
    return [for (final id in ids) ...?byEntry[id]];
  }

  void close() => _db.close();
}
