import 'package:dict_jmdict/src/form_lookup.dart' as forms;
import 'package:dict_jmdict/src/models.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

/// Schema version written by tools/dict/build_jmdict_db.py (`PRAGMA user_version`).
const int jmdictSchemaVersion = 1;

/// The file is not a JMdict database this package can read.
final class JmdictFormatException implements Exception {
  const JmdictFormatException(this.message);

  final String message;

  @override
  String toString() => 'JmdictFormatException: $message';
}

/// Read-only lookups over the JMdict SQLite file.
///
/// Calls are synchronous: a few indexed queries per call.
final class JmdictDictionary {
  JmdictDictionary._(this._db, this.info);

  /// Opens the database at [path] read-only.
  ///
  /// Throws [JmdictFormatException] when the file was not built by
  /// build_jmdict_db.py with schema [jmdictSchemaVersion].
  factory JmdictDictionary.open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    var opened = false;
    try {
      final dict = JmdictDictionary.fromDatabase(db);
      opened = true;
      return dict;
    } finally {
      if (!opened) db.close();
    }
  }

  /// Uses an already open database (tests load the SQL fixture in memory).
  factory JmdictDictionary.fromDatabase(CommonDatabase db) {
    final int version;
    final Map<String, String> meta;
    try {
      version = db.select('PRAGMA user_version').first.columnAt(0) as int;
      meta = {
        for (final row in db.select('SELECT key, value FROM meta'))
          row.columnAt(0) as String: row.columnAt(1) as String,
      };
    } on SqliteException catch (e) {
      throw JmdictFormatException('not a JMdict database: ${e.message}');
    }
    if (version != jmdictSchemaVersion) {
      throw JmdictFormatException(
        'schema $version, expected $jmdictSchemaVersion; rebuild the file',
      );
    }
    return JmdictDictionary._(db, DictionaryInfo(Map.unmodifiable(meta)));
  }

  final CommonDatabase _db;
  final Map<String, CommonPreparedStatement> _statements = {};
  bool _closed = false;

  /// Source, version and licence of the data.
  final DictionaryInfo info;

  /// Entries spelled as each of [forms], in one query per kind of form.
  ///
  /// A kanji form matches the entry's kanji forms; a kana form matches its
  /// readings in either script. Search-only spellings (sK, sk) never match.
  /// Forms with no entry are left out.
  Map<String, List<forms.FormEntry>> lookupForms(Iterable<String> spellings) {
    _ensureOpen();
    return forms.lookupForms(
      spellings,
      (sql, args) => [for (final row in _select(sql, args)) row.values],
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final s in _statements.values) {
      s.close();
    }
    _statements.clear();
    _db.close();
  }

  // ------------------------------------------------------------ queries

  void _ensureOpen() {
    if (_closed) throw StateError('JmdictDictionary is closed');
  }

  ResultSet _select(String sql, List<Object?> args) {
    _ensureOpen();
    return (_statements[sql] ??= _db.prepare(sql)).select(args);
  }
}
