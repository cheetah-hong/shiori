/// The tables of a backup file (format version 1): each is
/// `{"columns": [...], "rows": [[...], ...]}`, the columns named once and
/// fixed per version. Every cell is checked when read.
library;

import 'package:shiori_core/src/backup/backup_codec.dart';
import 'package:shiori_core/src/backup/backup_data.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/models/study_mode.dart';

const List<String> wordColumns = [
  'id',
  'key',
  'headword',
  'readings',
  'pos',
  'meaning',
  'exampleJa',
  'exampleKo',
  'createdAt',
  'hiddenAt',
];

const List<String> playlistColumns = ['id', 'name', 'createdAt', 'position'];

const List<String> playlistWordColumns = [
  'playlistId',
  'wordId',
  'position',
  'addedAt',
];

const List<String> cardColumns = [
  'scope',
  'mode',
  'wordId',
  'level',
  'dueAt',
  'lastReviewedAt',
  'reviewCount',
  'lapseCount',
];

const List<String> logColumns = [
  'id',
  'scope',
  'mode',
  'wordId',
  'answer',
  'at',
  'levelBefore',
  'levelAfter',
  'retriesInSession',
];

/// Longest text a cell may hold, and the bounds of ids and keys.
const int maxTextLength = 10000;
const int maxIdLength = 256;
const int maxReadings = 32;

/// Largest press id and position a file may hold: far above any real count,
/// and far enough below SQLite's largest row id that the press log can
/// always take a next id (an id at the very top would stop every later
/// press from being saved).
const int maxSerial = 1 << 40;

/// The names version 1 takes in its enum cells, fixed with the version: a
/// new study mode, answer or part of speech is a new backup version, so an
/// older app says the file is newer instead of damaged.
const List<String> v1StudyModes = ['meaning', 'recall', 'listening', 'choice'];
const List<String> v1Answers = ['retry', 'known'];

/// The study options version 1 takes, key → stored values (as
/// `StudySettingKeys`).
const Map<String, List<String>> v1Settings = {
  'study.record_mode': ['shared', 'per_playlist'],
  'study.scope_mode': ['all_or_playlist', 'playlist_only'],
  'study.mode': v1StudyModes,
  'study.daily_goal': ['10', '20', '30', '50', 'all'],
  'study.shuffle': ['off'],
};
const List<String> v1PartsOfSpeech = [
  'noun',
  'verb',
  'adjective',
  'iAdjective',
  'naAdjective',
  'adverb',
  'conjunction',
  'interjection',
  'prenominal',
  'particle',
];

/// Times are kept from 2000 up to (not including) 2200.
final int _firstTime = DateTime.utc(2000).microsecondsSinceEpoch;
final int _endTime = DateTime.utc(2200).microsecondsSinceEpoch;

int _micros(DateTime t) => t.microsecondsSinceEpoch;

Map<String, Object?> _table(List<String> columns, List<List<Object?>> rows) => {
  'columns': columns,
  'rows': rows,
};

Map<String, Object?> wordsTable(List<BackupWord> words) => _table(wordColumns, [
  for (final w in words)
    [
      w.id,
      w.key,
      w.headword,
      w.readings,
      w.pos?.name,
      w.meaning,
      w.exampleJa,
      w.exampleKo,
      _micros(w.createdAt),
      w.hiddenAt == null ? null : _micros(w.hiddenAt!),
    ],
]);

Map<String, Object?> playlistsTable(List<BackupPlaylist> playlists) => _table(
  playlistColumns,
  [
    for (final p in playlists) [p.id, p.name, _micros(p.createdAt), p.position],
  ],
);

Map<String, Object?> playlistWordsTable(List<BackupPlaylistWord> entries) =>
    _table(playlistWordColumns, [
      for (final e in entries)
        [e.playlistId, e.wordId, e.position, _micros(e.addedAt)],
    ]);

Map<String, Object?> cardsTable(List<ReviewCard> cards) => _table(cardColumns, [
  for (final c in cards)
    [
      c.scope.key,
      c.mode.name,
      c.wordId,
      c.level,
      _micros(c.dueAt),
      _micros(c.lastReviewedAt),
      c.reviewCount,
      c.lapseCount,
    ],
]);

Map<String, Object?> logsTable(List<BackupLog> logs) => _table(logColumns, [
  for (final l in logs)
    [
      l.id,
      l.scope.key,
      l.mode.name,
      l.wordId,
      l.answer.name,
      _micros(l.at),
      l.levelBefore,
      l.levelAfter,
      l.retriesInSession,
    ],
]);

Never _invalid(String detail) =>
    throw BackupException(BackupProblem.invalid, detail);

/// The rows of table [name] in [document], each handed to [read] as a
/// checked [CellReader].
List<T> readTable<T>(
  Map<String, Object?> document,
  String name,
  List<String> columns,
  T Function(CellReader row) read,
) {
  final table = document[name];
  if (table is! Map<String, Object?> ||
      table.length != 2 ||
      !table.containsKey('columns') ||
      !table.containsKey('rows')) {
    _invalid('$name: not columns and rows');
  }
  final named = table['columns'];
  if (named is! List<Object?> ||
      named.length != columns.length ||
      [
        for (var i = 0; i < columns.length; i++) named[i] == columns[i],
      ].any((same) => !same)) {
    _invalid('$name: columns');
  }
  final rows = table['rows'];
  if (rows is! List<Object?>) _invalid('$name: rows');
  return List.unmodifiable([
    for (final (i, row) in rows.indexed)
      read(CellReader._(name, i, columns, row)),
  ]);
}

/// One row of a table, read cell by cell with its type and range checked.
final class CellReader {
  CellReader._(this._table, this._index, List<String> columns, Object? row)
    : _cells = _checked(_table, _index, columns, row),
      _columns = columns;

  final String _table;
  final int _index;
  final List<String> _columns;
  final List<Object?> _cells;

  static List<Object?> _checked(
    String table,
    int index,
    List<String> columns,
    Object? row,
  ) {
    if (row is! List<Object?> || row.length != columns.length) {
      _invalid('$table[$index]: not a row of ${columns.length} cells');
    }
    return row;
  }

  Object? _cell(String column) => _cells[_columns.indexOf(column)];

  Never _bad(String column, String why) =>
      _invalid('$_table[$_index].$column: $why');

  /// Text of at most [maxTextLength] characters ([maxIdLength] and not
  /// empty for an [id]).
  String text(String column, {bool id = false}) {
    final value = _cell(column);
    if (value is! String) _bad(column, 'not text');
    if (id && (value.isEmpty || value.length > maxIdLength)) {
      _bad(column, 'id length');
    }
    if (value.length > maxTextLength) _bad(column, 'too long');
    return value;
  }

  /// [text], or null.
  String? textOrNull(String column) =>
      _cell(column) == null ? null : text(column);

  /// A list of texts (a word's readings).
  List<String> texts(String column) {
    final value = _cell(column);
    if (value is! List<Object?> || value.length > maxReadings) {
      _bad(column, 'not a list of texts');
    }
    return [
      for (final v in value)
        if (v is String && v.length <= maxTextLength)
          v
        else
          _bad(column, 'not a list of texts'),
    ];
  }

  /// A whole number from [min] to [max].
  int whole(String column, {int min = 0, int? max}) {
    final value = _cell(column);
    if (value is! int) _bad(column, 'not a whole number');
    if (value < min || (max != null && value > max)) {
      _bad(column, 'out of range');
    }
    return value;
  }

  /// A time (UTC microseconds) from 2000 to before 2200, read as local time.
  DateTime time(String column) {
    final value = _cell(column);
    if (value is! int) _bad(column, 'not a time');
    if (value < _firstTime || value >= _endTime) _bad(column, 'out of range');
    return DateTime.fromMicrosecondsSinceEpoch(value);
  }

  /// [time], or null.
  DateTime? timeOrNull(String column) =>
      _cell(column) == null ? null : time(column);

  /// The value of [values] named by the cell, one of the version's
  /// [names].
  T named<T extends Enum>(String column, List<T> values, List<String> names) {
    final value = _cell(column);
    final found = value is String && names.contains(value)
        ? values.asNameMap()[value]
        : null;
    if (found == null) _bad(column, 'unknown value');
    return found;
  }

  /// [named], or null.
  T? namedOrNull<T extends Enum>(
    String column,
    List<T> values,
    List<String> names,
  ) => _cell(column) == null ? null : named(column, values, names);

  CardScope scope(String column) {
    try {
      return CardScope.fromKey(text(column));
    } on FormatException {
      _bad(column, 'not a scope');
    }
  }

  BackupWord word() {
    final exampleJa = textOrNull('exampleJa');
    final exampleKo = textOrNull('exampleKo');
    if ((exampleJa == null) != (exampleKo == null)) {
      _bad('exampleKo', 'example without its translation');
    }
    return BackupWord(
      id: text('id', id: true),
      key: text('key', id: true),
      headword: text('headword'),
      readings: texts('readings'),
      pos: namedOrNull('pos', PartOfSpeech.values, v1PartsOfSpeech),
      meaning: text('meaning'),
      exampleJa: exampleJa,
      exampleKo: exampleKo,
      createdAt: time('createdAt'),
      hiddenAt: timeOrNull('hiddenAt'),
    );
  }

  BackupPlaylist playlist() {
    final name = text('name');
    if (name.trim().isEmpty) _bad('name', 'empty');
    return BackupPlaylist(
      id: text('id', id: true),
      name: name,
      createdAt: time('createdAt'),
      position: whole('position', max: maxSerial),
    );
  }

  BackupPlaylistWord playlistWord() => BackupPlaylistWord(
    playlistId: text('playlistId', id: true),
    wordId: text('wordId', id: true),
    position: whole('position', max: maxSerial),
    addedAt: time('addedAt'),
  );

  ReviewCard card(int maxLevel) => ReviewCard(
    scope: scope('scope'),
    mode: named('mode', StudyMode.values, v1StudyModes),
    wordId: text('wordId', id: true),
    level: whole('level', max: maxLevel),
    dueAt: time('dueAt'),
    lastReviewedAt: time('lastReviewedAt'),
    reviewCount: whole('reviewCount'),
    lapseCount: whole('lapseCount'),
  );

  BackupLog log(int maxLevel) => BackupLog(
    id: whole('id', min: 1, max: maxSerial),
    scope: scope('scope'),
    mode: named('mode', StudyMode.values, v1StudyModes),
    wordId: text('wordId', id: true),
    answer: named('answer', Answer.values, v1Answers),
    at: time('at'),
    levelBefore: whole('levelBefore', max: maxLevel),
    levelAfter: whole('levelAfter', max: maxLevel),
    retriesInSession: whole('retriesInSession'),
  );
}
