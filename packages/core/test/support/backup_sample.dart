import 'dart:convert';

import 'package:shiori_core/shiori_core.dart';

/// Thursday 12 November 2026, 22:30 on the device.
final backupNow = DateTime(2026, 11, 12, 22, 30);

const sampleApp = BackupApp(version: '1.0.0', build: '7', schema: 5);

/// Made-up words: headword, reading, meaning.
const _made = [
  ('風車', 'かざぐるま', '바람개비'),
  ('雨傘', 'あまがさ', '우산'),
  ('夕焼け', 'ゆうやけ', '저녁노을'),
  ('小道', 'こみち', '오솔길'),
  ('木陰', 'こかげ', '나무 그늘'),
  ('星空', 'ほしぞら', '별하늘'),
  ('波音', 'なみおと', '파도 소리'),
  ('春風', 'はるかぜ', '봄바람'),
  ('雪道', 'ゆきみち', '눈길'),
  ('朝霧', 'あさぎり', '아침 안개'),
];

/// 30 words (examples on some, no part of speech on some, two readings on
/// some, three hidden), 3 playlists with a word in two of them, cards in
/// all four modes, presses (one on a word the library no longer holds) and
/// options away from their defaults.
BackupData sampleBackupData() {
  final t0 = DateTime.utc(2026, 10, 1, 9).toLocal();
  final words = [
    for (var i = 0; i < 30; i++)
      BackupWord(
        id: 'w-sample-$i',
        key: '${_made[i % 10].$1}$i',
        headword: '${_made[i % 10].$1}$i',
        readings: [_made[i % 10].$2, if (i % 7 == 0) '${_made[i % 10].$2}ー'],
        pos: i % 4 == 0 ? null : PartOfSpeech.values[i % 10],
        meaning: '${_made[i % 10].$3} $i',
        exampleJa: i.isEven ? '${_made[i % 10].$1}の例文$i。' : null,
        exampleKo: i.isEven ? '${_made[i % 10].$3} 예문 $i.' : null,
        createdAt: t0.add(Duration(minutes: i)),
        hiddenAt: i % 10 == 3 ? t0.add(const Duration(days: 2)) : null,
      ),
  ];
  final playlists = [
    for (var p = 0; p < 3; p++)
      BackupPlaylist(
        id: 'pl-sample-$p',
        name: ['자연', '날씨', '길'][p],
        createdAt: t0.add(Duration(hours: p)),
        position: p,
      ),
  ];
  final entries = [
    for (var i = 0; i < 30; i++)
      BackupPlaylistWord(
        playlistId: 'pl-sample-${i % 3}',
        wordId: 'w-sample-$i',
        position: i ~/ 3,
        addedAt: t0.add(Duration(minutes: i, seconds: 5)),
      ),
    // Words 0 and 1 are in a second playlist too.
    BackupPlaylistWord(
      playlistId: 'pl-sample-2',
      wordId: 'w-sample-0',
      position: 10,
      addedAt: t0.add(const Duration(days: 1)),
    ),
    BackupPlaylistWord(
      playlistId: 'pl-sample-0',
      wordId: 'w-sample-1',
      position: 10,
      addedAt: t0.add(const Duration(days: 1, seconds: 1)),
    ),
  ];
  final cards = [
    for (var i = 0; i < 12; i++)
      ReviewCard(
        wordId: 'w-sample-$i',
        mode: StudyMode.values[i % 4],
        level: 1 + i % 4,
        dueAt: t0.add(Duration(days: 3 + i)),
        lastReviewedAt: t0.add(Duration(days: 1, minutes: i)),
        reviewCount: i,
        lapseCount: i % 3,
      ),
  ];
  final logs = [
    for (var i = 0; i < 20; i++)
      BackupLog(
        id: i + 1,
        wordId: 'w-sample-${i % 12}',
        mode: StudyMode.values[i % 4],
        answer: i % 3 == 0 ? Answer.retry : Answer.known,
        at: t0.add(Duration(days: 1, minutes: i, microseconds: 7)),
        levelBefore: i % 4,
        levelAfter: 1 + i % 4,
        retriesInSession: i % 3 == 0 ? 1 : 0,
      ),
    // A press on a word deleted since: history keeps it.
    BackupLog(
      id: 25,
      wordId: 'w-gone',
      answer: Answer.known,
      at: t0.add(const Duration(days: 1, hours: 1)),
      levelBefore: 0,
      levelAfter: 4,
      retriesInSession: 0,
    ),
  ];
  return BackupData(
    words: words,
    playlists: playlists,
    playlistWords: entries,
    cards: cards,
    logs: logs,
    settings: const {
      StudySettingKeys.recordMode: 'shared',
      StudySettingKeys.scopeMode: 'all_or_playlist',
      StudySettingKeys.mode: 'choice',
      StudySettingKeys.dailyGoal: '30',
      StudySettingKeys.shuffle: 'off',
    },
  );
}

BackupFile sampleBackupFile() =>
    BackupFile(createdAt: backupNow, app: sampleApp, data: sampleBackupData());

/// The sample file as decoded JSON, to change before encoding it again.
Map<String, Object?> sampleDocument() =>
    jsonDecode(utf8.decode(encodeBackup(sampleBackupFile())))
        as Map<String, Object?>;

List<int> bytesOf(Object? document) => utf8.encode(jsonEncode(document));

/// The table [name] of [document].
Map<String, Object?> tableOf(Map<String, Object?> document, String name) =>
    document[name]! as Map<String, Object?>;

/// The rows of table [name] (changeable).
List<Object?> rowsOf(Map<String, Object?> document, String name) =>
    tableOf(document, name)['rows']! as List<Object?>;

/// Sets [column] of row [row] of table [name] to [value].
void setCell(
  Map<String, Object?> document,
  String name,
  int row,
  String column,
  Object? value,
) {
  final columns = (tableOf(document, name)['columns']! as List).cast<String>();
  (rowsOf(document, name)[row]! as List<Object?>)[columns.indexOf(column)] =
      value;
}

/// Row [row] of table [name] by column name.
Object? cell(
  Map<String, Object?> document,
  String name,
  int row,
  String column,
) {
  final columns = (tableOf(document, name)['columns']! as List).cast<String>();
  return (rowsOf(document, name)[row]! as List<Object?>)[columns.indexOf(
    column,
  )];
}
