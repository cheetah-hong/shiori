import 'dart:convert';
import 'dart:typed_data';

import 'package:shiori_core/src/backup/backup_data.dart';
import 'package:shiori_core/src/backup/backup_rows.dart';
import 'package:shiori_core/src/models/study_setting_keys.dart';

/// What every backup file says it is (`format`).
const String backupFormat = 'shiori-backup';

/// The backup file layout this build writes and reads (`version`). It is
/// the file's own version, apart from the database schema: it goes up when
/// the tables or columns a backup carries change, or a value a cell takes
/// is added (a study option or one of its values, a study mode, an answer,
/// a part of speech), with a step in `backupUpgrades` from the version
/// before.
const int backupVersion = 1;

/// The largest backup file written or read (64 MiB): a restore never reads
/// more, and an export never makes a file a restore would refuse.
const int backupMaxBytes = 64 * 1024 * 1024;

/// Highest memory level a card or press may hold (four review steps).
const int backupMaxLevel = 4;

/// The app that made a backup.
final class BackupApp {
  const BackupApp({
    required this.version,
    required this.build,
    required this.schema,
  });

  /// As shown to the learner, `1.0.0`.
  final String version;

  /// The build number, `1`.
  final String build;

  /// The database schema of that app (kept for diagnosis only).
  final int schema;

  @override
  bool operator ==(Object other) =>
      other is BackupApp &&
      other.version == version &&
      other.build == build &&
      other.schema == schema;

  @override
  int get hashCode => Object.hash(version, build, schema);
}

/// A backup: when and by which app it was made, and what it holds.
final class BackupFile {
  const BackupFile({
    required this.createdAt,
    required this.app,
    required this.data,
  });

  final DateTime createdAt;
  final BackupApp app;
  final BackupData data;

  /// What the restore question shows.
  BackupSummary get summary => BackupSummary(
    words: data.words.length,
    playlists: data.playlists.length,
    presses: data.logs.length,
    createdAt: createdAt,
    appVersion: app.version,
  );
}

/// The counts a restore asks about, read from the file's rows.
final class BackupSummary {
  const BackupSummary({
    required this.words,
    required this.playlists,
    required this.presses,
    required this.createdAt,
    required this.appVersion,
  });

  final int words;
  final int playlists;

  /// Button presses (학습 기록).
  final int presses;
  final DateTime createdAt;
  final String appVersion;
}

/// Why a file cannot be restored. Nothing is changed in any case.
enum BackupProblem {
  /// No bytes, or only spaces.
  empty,

  /// Over [backupMaxBytes] (or the limit given).
  tooLarge,

  /// Not UTF-8 JSON with an object at the top.
  notJson,

  /// JSON, but not a Shiori backup (`format`).
  notBackup,

  /// Made by a newer app (`version` above [backupVersion]).
  newerVersion,

  /// A missing, unknown or wrongly typed field, or a value out of range.
  invalid,

  /// Two rows with the same key.
  duplicate,

  /// A playlist entry or card naming a word or playlist the file lacks.
  danglingReference,
}

/// A backup file that cannot be read or restored.
final class BackupException implements Exception {
  const BackupException(this.problem, [this.detail = '']);

  final BackupProblem problem;

  /// Where in the file (table, row, column), for the log only.
  final String detail;

  @override
  String toString() => 'BackupException(${problem.name}: $detail)';
}

/// Steps from an older backup version to the next, applied to the decoded
/// JSON before it is checked: `backupUpgrades[1]` would turn a version 1
/// file into version 2. Empty while version 1 is the only one.
final Map<int, Map<String, Object?> Function(Map<String, Object?>)>
backupUpgrades = Map.unmodifiable({});

/// The keys at the top of a version 1 file.
const Set<String> _topKeys = {
  'format',
  'version',
  'createdAt',
  'app',
  'words',
  'playlists',
  'playlistWords',
  'reviewCards',
  'reviewLogs',
  'settings',
};

/// [file] as backup file bytes (UTF-8 JSON). A [BackupException]
/// ([BackupProblem.tooLarge]) when they would be over [maxBytes].
///
/// Study options this build does not know (a newer app's rows) are left
/// out: a file never carries a key a restore would refuse.
Uint8List encodeBackup(BackupFile file, {int maxBytes = backupMaxBytes}) {
  final data = file.data;
  final bytes = utf8.encode(
    jsonEncode({
      'format': backupFormat,
      'version': backupVersion,
      'createdAt': _isoWithOffset(file.createdAt),
      'app': {
        'version': file.app.version,
        'build': file.app.build,
        'schema': file.app.schema,
      },
      'words': wordsTable(data.words),
      'playlists': playlistsTable(data.playlists),
      'playlistWords': playlistWordsTable(data.playlistWords),
      'reviewCards': cardsTable(data.cards),
      'reviewLogs': logsTable(data.logs),
      'settings': {
        for (final MapEntry(:key, :value) in data.settings.entries)
          if (StudySettingKeys.isKnown(key, value)) key: value,
      },
    }),
  );
  if (bytes.length > maxBytes) {
    throw BackupException(BackupProblem.tooLarge, '${bytes.length} bytes');
  }
  return bytes;
}

/// The backup in [bytes], every row checked before anything is returned.
/// A [BackupException] for the first problem found.
BackupFile decodeBackup(
  List<int> bytes, {
  int maxBytes = backupMaxBytes,
  int maxLevel = backupMaxLevel,
}) {
  if (bytes.length > maxBytes) {
    throw BackupException(BackupProblem.tooLarge, '${bytes.length} bytes');
  }
  if (bytes.every(_isSpace)) {
    throw const BackupException(BackupProblem.empty);
  }
  final document = _upgraded(_header(_json(bytes)));
  if (!_sameKeys(document.keys, _topKeys)) {
    throw const BackupException(BackupProblem.invalid, 'top-level keys');
  }
  final data = BackupData(
    words: readTable(document, 'words', wordColumns, (r) => r.word()),
    playlists: readTable(
      document,
      'playlists',
      playlistColumns,
      (r) => r.playlist(),
    ),
    playlistWords: readTable(
      document,
      'playlistWords',
      playlistWordColumns,
      (r) => r.playlistWord(),
    ),
    cards: readTable(
      document,
      'reviewCards',
      cardColumns,
      (r) => r.card(maxLevel),
    ),
    logs: readTable(document, 'reviewLogs', logColumns, (r) => r.log(maxLevel)),
    settings: _settings(document['settings']),
  );
  _checkKeys(data);
  return BackupFile(
    createdAt: _createdAt(document['createdAt']),
    app: _app(document['app']),
    data: data,
  );
}

/// `shiori-backup-YYYYMMDD-HHMM.json`, from [at] as it reads on the device.
String backupFileName(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'shiori-backup-${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}.json';
}

bool _isSpace(int byte) =>
    byte == 0x20 || byte == 0x09 || byte == 0x0a || byte == 0x0d;

bool _sameKeys(Iterable<String> keys, Set<String> expected) =>
    keys.length == expected.length && keys.every(expected.contains);

Never _invalid(String detail) =>
    throw BackupException(BackupProblem.invalid, detail);

/// The decoded JSON object; not UTF-8 or not JSON is [BackupProblem.notJson].
Map<String, Object?> _json(List<int> bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (e) {
    throw BackupException(BackupProblem.notJson, e.message);
  }
  if (decoded is! Map<String, Object?>) {
    throw const BackupException(BackupProblem.notJson, 'not an object');
  }
  return decoded;
}

/// [document] when it is a Shiori backup of a version this build reads.
Map<String, Object?> _header(Map<String, Object?> document) {
  if (document['format'] != backupFormat) {
    throw const BackupException(BackupProblem.notBackup);
  }
  final version = document['version'];
  if (version is! int || version < 1) _invalid('version');
  if (version > backupVersion) {
    throw BackupException(BackupProblem.newerVersion, 'version $version');
  }
  return document;
}

/// [document] brought up to [backupVersion] by [backupUpgrades].
Map<String, Object?> _upgraded(Map<String, Object?> document) {
  var upgraded = document;
  for (var v = document['version']! as int; v < backupVersion; v++) {
    final step = backupUpgrades[v];
    if (step == null) _invalid('no step from version $v');
    upgraded = step(upgraded);
  }
  return upgraded;
}

DateTime _createdAt(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) _invalid('createdAt');
  return parsed.toLocal();
}

BackupApp _app(Object? value) {
  if (value is! Map<String, Object?> ||
      !_sameKeys(value.keys, const {'version', 'build', 'schema'})) {
    _invalid('app');
  }
  final version = value['version'];
  final build = value['build'];
  final schema = value['schema'];
  if (version is! String ||
      build is! String ||
      schema is! int ||
      version.length > maxIdLength ||
      build.length > maxIdLength ||
      schema < 1) {
    _invalid('app');
  }
  return BackupApp(version: version, build: build, schema: schema);
}

Map<String, String> _settings(Object? value) {
  if (value is! Map<String, Object?>) _invalid('settings');
  return {
    for (final MapEntry(:key, :value) in value.entries)
      if (value is String && (v1Settings[key]?.contains(value) ?? false))
        key: value
      else
        key: _invalid('settings.$key'),
  };
}

/// Keys are unique and every entry and card names a word (and playlist) the
/// file holds. Presses may name a word that is gone (history).
void _checkKeys(BackupData data) {
  void unique<T>(String table, Iterable<T> keys) {
    final seen = <T>{};
    for (final key in keys) {
      if (!seen.add(key)) {
        throw BackupException(BackupProblem.duplicate, '$table: $key');
      }
    }
  }

  unique('words.id', data.words.map((w) => w.id));
  unique('words.key', data.words.map((w) => w.key));
  unique('playlists.id', data.playlists.map((p) => p.id));
  unique(
    'playlistWords',
    data.playlistWords.map((e) => (e.playlistId, e.wordId)),
  );
  unique('reviewCards', data.cards.map((c) => (c.scope, c.mode, c.wordId)));
  unique('reviewLogs.id', data.logs.map((l) => l.id));

  final words = {for (final w in data.words) w.id};
  final playlists = {for (final p in data.playlists) p.id};
  void known(String where, String id, Set<String> ids) {
    if (!ids.contains(id)) {
      throw BackupException(BackupProblem.danglingReference, where);
    }
  }

  for (final (i, e) in data.playlistWords.indexed) {
    known('playlistWords[$i].playlistId', e.playlistId, playlists);
    known('playlistWords[$i].wordId', e.wordId, words);
  }
  for (final (i, c) in data.cards.indexed) {
    known('reviewCards[$i].wordId', c.wordId, words);
  }
}

/// [t] in ISO 8601 with its offset from UTC (`Z` for UTC).
String _isoWithOffset(DateTime t) {
  if (t.isUtc) return t.toIso8601String();
  final offset = t.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.toIso8601String()}$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}
