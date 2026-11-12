// Backups in the SQLite block (K1·K2·K3·K4·K8): every table read and
// replaced at once, what a failure half way leaves, and a bad file leaving
// the file as it was. Made-up words only.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

final _t0 = DateTime(2026, 10, 1, 9, 0, 0, 0, 3);
final _now = DateTime(2026, 11, 12, 22, 30);
const _app = BackupApp(version: '1.0.0', build: '7', schema: 5);

/// Made-up words: headword, reading, meaning.
const _made = [
  ('風車', 'かざぐるま', '바람개비'),
  ('雨傘', 'あまがさ', '우산'),
  ('夕焼け', 'ゆうやけ', '저녁노을'),
  ('小道', 'こみち', '오솔길'),
  ('木陰', 'こかげ', '나무 그늘'),
  ('星空', 'ほしぞら', '별하늘'),
];

/// Tables and the order they are compared in.
const _tables = {
  'words': 'id',
  'playlists': 'id',
  'playlist_words': 'playlist_id, word_id',
  'review_cards': 'scope, mode, word_id',
  'review_logs': 'id',
  'settings': 'key',
};

/// Every row of every table, sorted.
Future<Map<String, List<Map<String, Object?>>>> _dump(ShioriDatabase db) async {
  return {
    for (final MapEntry(key: table, value: order) in _tables.entries)
      table: [
        for (final row
            in await db
                .customSelect('SELECT * FROM $table ORDER BY $order')
                .get())
          row.data,
      ],
  };
}

/// Through the app's own repositories: 30 words (examples on some, two
/// readings on some, three hidden), 3 playlists with words in two of them,
/// cards in all four modes, presses (one on a word the library does not
/// hold) and options away from their defaults.
Future<void> _seed(
  ShioriDatabase db, {
  String tag = 'a',
  int words = 30,
}) async {
  final library = DriftLibraryRepository(db);
  final reviews = DriftReviewRepository(db);
  await library.insertWords([
    for (var i = 0; i < words; i++)
      Word(
        id: 'w-$tag-$i',
        headword: '${_made[i % 6].$1}$tag$i',
        readings: [_made[i % 6].$2, if (i % 7 == 0) '${_made[i % 6].$2}ー'],
        pos: i % 4 == 0 ? null : PartOfSpeech.values[i % 10],
        meaning: '${_made[i % 6].$3} $i',
        example: i.isEven
            ? Example(ja: '${_made[i % 6].$1}の例文$i。', ko: '예문 $i.')
            : null,
        createdAt: _t0.add(Duration(minutes: i)),
      ),
  ]);
  for (var p = 0; p < 3; p++) {
    await library.savePlaylist(
      Playlist(
        id: 'pl-$tag-$p',
        name: ['자연', '날씨', '길'][p],
        createdAt: _t0.add(Duration(hours: p)),
        position: p,
      ),
    );
    await library.addToPlaylist('pl-$tag-$p', [
      for (var i = p; i < words; i += 3) 'w-$tag-$i',
    ], at: _t0.add(Duration(days: p)));
  }
  // Words 0 and 1 in a second playlist too.
  await library.addToPlaylist('pl-$tag-2', ['w-$tag-0', 'w-$tag-1'], at: _t0);
  await library.hideWords([
    for (var i = 3; i < words; i += 10) 'w-$tag-$i',
  ], at: _t0.add(const Duration(days: 2, microseconds: 9)));
  for (var i = 0; i < 12 && i < words; i++) {
    await reviews.saveCard(
      ReviewCard(
        wordId: 'w-$tag-$i',
        mode: StudyMode.values[i % 4],
        level: 1 + i % 4,
        dueAt: _t0.add(Duration(days: 3 + i)),
        lastReviewedAt: _t0.add(Duration(days: 1, minutes: i)),
        reviewCount: i,
        lapseCount: i % 3,
      ),
    );
  }
  for (var i = 0; i < 20; i++) {
    await reviews.addLog(
      ReviewLog(
        wordId: i == 19 ? 'w-$tag-gone' : 'w-$tag-${i % 12}',
        mode: StudyMode.values[i % 4],
        answer: i % 3 == 0 ? Answer.retry : Answer.known,
        at: _t0.add(Duration(days: 1, minutes: i, microseconds: 7)),
        levelBefore: i % 4,
        levelAfter: 1 + i % 4,
        retriesInSession: i % 3 == 0 ? 1 : 0,
      ),
    );
  }
  await DriftStudyPreferencesRepository(db).save(
    const StudyPreferences(
      mode: StudyMode.choice,
      dailyGoal: DailyGoal.thirty,
      shuffle: false,
    ),
  );
}

/// [data] as a file and back, as a restore receives it.
BackupData _throughFile(BackupData data) => decodeBackup(
  encodeBackup(BackupFile(createdAt: _now, app: _app, data: data)),
).data;

/// A keeper that keeps nothing (the restore under test is the store's).
final class _NoKeeper implements BackupKeeper {
  @override
  Future<void> keep(Uint8List bytes) async {}

  @override
  Future<Uint8List?> read() async => null;

  @override
  Future<DateTime?> keptAt() async => null;

  @override
  Future<void> discard() async {}
}

void main() {
  test('K1 round trip: every table comes back the same, row for row', () async {
    final source = ShioriDatabase.memory();
    final target = ShioriDatabase.memory();
    addTearDown(source.close);
    addTearDown(target.close);
    await _seed(source);

    final data = await DriftBackupStore(source).read();
    await DriftBackupStore(target).replaceAll(_throughFile(data));

    final before = await _dump(source);
    expect(before['words'], hasLength(30));
    expect(before['playlists'], hasLength(3));
    expect(before['playlist_words'], hasLength(32));
    expect(before['review_cards'], hasLength(12));
    expect(
      {for (final c in before['review_cards']!) c['mode']},
      {'meaning', 'recall', 'listening', 'choice'},
    );
    expect(before['review_logs'], hasLength(20));
    expect([
      for (final w in before['words']!)
        if (w['hidden_at'] != null) w['id'],
    ], hasLength(3));
    expect(before['settings'], hasLength(5));
    expect(await _dump(target), before);
  });

  test('K1 the read holds what the repositories stored', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    await _seed(db);

    final data = await DriftBackupStore(db).read();

    expect(data.words, hasLength(30));
    expect(data.words.where((w) => w.hiddenAt != null), hasLength(3));
    expect(data.playlistWords, hasLength(32));
    expect(data.cards, hasLength(12));
    expect(data.logs, hasLength(20));
    expect(data.logs.map((l) => l.wordId), contains('w-a-gone'));
    expect(data.settings, {
      StudySettingKeys.recordMode: 'shared',
      StudySettingKeys.scopeMode: 'all_or_playlist',
      StudySettingKeys.mode: 'choice',
      StudySettingKeys.dailyGoal: '30',
      StudySettingKeys.shuffle: 'off',
    });
    final word = data.words.firstWhere((w) => w.id == 'w-a-0');
    final stored = await DriftLibraryRepository(db).word('w-a-0');
    expect(word.key, stored!.key);
    expect(word.readings, stored.readings);
    expect(word.exampleJa, stored.example!.ja);
  });

  test('K1 after a restore the repositories read the backup', () async {
    final source = ShioriDatabase.memory();
    final target = ShioriDatabase.memory();
    addTearDown(source.close);
    addTearDown(target.close);
    await _seed(source);

    await DriftBackupStore(
      target,
    ).replaceAll(_throughFile(await DriftBackupStore(source).read()));

    final library = DriftLibraryRepository(target);
    expect(
      await library.words(playlistId: 'pl-a-0'),
      await DriftLibraryRepository(source).words(playlistId: 'pl-a-0'),
    );
    expect(await library.hiddenWords(), hasLength(3));
    expect(
      await DriftReviewRepository(target).cards(mode: StudyMode.recall),
      await DriftReviewRepository(source).cards(mode: StudyMode.recall),
    );
    expect(
      await DriftStudyPreferencesRepository(target).load(),
      const StudyPreferences(
        mode: StudyMode.choice,
        dailyGoal: DailyGoal.thirty,
        shuffle: false,
      ),
    );
  });

  test('K1 a press after a restore comes after the restored ones', () async {
    final source = ShioriDatabase.memory();
    final target = ShioriDatabase.memory();
    addTearDown(source.close);
    addTearDown(target.close);
    await _seed(source);
    await DriftBackupStore(
      target,
    ).replaceAll(_throughFile(await DriftBackupStore(source).read()));

    await DriftReviewRepository(target).addLog(
      ReviewLog(
        wordId: 'w-a-0',
        answer: Answer.known,
        at: _now,
        levelBefore: 1,
        levelAfter: 2,
        retriesInSession: 0,
      ),
    );

    final ids = [
      for (final r in (await _dump(target))['review_logs']!) r['id']! as int,
    ];
    expect(ids, hasLength(21));
    expect(ids.last, greaterThan(20));
  });

  test('K2 replace: nothing of the data before is left', () async {
    final source = ShioriDatabase.memory();
    final target = ShioriDatabase.memory();
    addTearDown(source.close);
    addTearDown(target.close);
    await _seed(source);
    await _seed(target, tag: 'old', words: 12);
    await DriftStudyPreferencesRepository(
      target,
    ).save(const StudyPreferences(dailyGoal: DailyGoal.all));

    await DriftBackupStore(
      target,
    ).replaceAll(_throughFile(await DriftBackupStore(source).read()));

    final after = await _dump(target);
    expect(after, await _dump(source));
    for (final rows in after.values) {
      for (final row in rows) {
        expect(
          row.values.whereType<String>().join(' '),
          isNot(contains('old')),
        );
      }
    }
  });

  test('K2 replacing with an empty backup empties every table', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    await _seed(db);

    await DriftBackupStore(db).replaceAll(BackupData());

    expect((await _dump(db)).values.every((rows) => rows.isEmpty), isTrue);
  });

  test(
    'K3 a failure half way leaves the file byte for byte as it was',
    () async {
      final dir = Directory.systemTemp.createTempSync('shiori_backup_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/shiori.sqlite');
      final seeded = ShioriDatabase(NativeDatabase(file));
      await _seed(seeded);
      await seeded.close();
      final bytes = file.readAsBytesSync();

      final other = ShioriDatabase.memory();
      addTearDown(other.close);
      await _seed(other, tag: 'new', words: 18);
      final backup = _throughFile(await DriftBackupStore(other).read());

      final db = ShioriDatabase(NativeDatabase(file));
      final before = await _dump(db);
      var halfway = 0;
      final store = DriftBackupStore(
        db,
        onHalfway: () async {
          halfway++;
          // The old rows are gone and the new words are in, inside the
          // transaction.
          final inside = await _dump(db);
          expect(inside['words'], hasLength(18));
          expect(inside['review_logs'], isEmpty);
          throw StateError('stopped half way');
        },
      );

      await expectLater(store.replaceAll(backup), throwsStateError);

      expect(halfway, 1);
      expect(await _dump(db), before);
      await db.close();
      expect(File('${file.path}-journal').existsSync(), isFalse);
      expect(file.readAsBytesSync(), bytes);
    },
  );

  test('K4 a bad file through the service changes nothing', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    await _seed(db);
    final before = await _dump(db);
    final service = BackupService(
      store: DriftBackupStore(db),
      keeper: _NoKeeper(),
      clock: FixedClock(_now),
      app: () async => _app,
    );
    final good = encodeBackup(
      BackupFile(
        createdAt: _now,
        app: _app,
        data: await DriftBackupStore(db).read(),
      ),
    );

    for (final bad in [
      <int>[],
      good.sublist(0, good.length ~/ 2),
      '{"format":"shiori-backup","version":2}'.codeUnits,
    ]) {
      await expectLater(service.open(bad), throwsA(isA<BackupException>()));
    }

    expect(await _dump(db), before);
  });

  test('K8 the schema stays at v5', () {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    expect(db.schemaVersion, 5);
  });

  test('K8 the settings block and backups name the same option keys', () {
    expect(
      DriftStudyPreferencesRepository.recordModeKey,
      StudySettingKeys.recordMode,
    );
    expect(
      DriftStudyPreferencesRepository.scopeModeKey,
      StudySettingKeys.scopeMode,
    );
    expect(DriftStudyPreferencesRepository.modeKey, StudySettingKeys.mode);
    expect(
      DriftStudyPreferencesRepository.dailyGoalKey,
      StudySettingKeys.dailyGoal,
    );
    expect(
      DriftStudyPreferencesRepository.shuffleKey,
      StudySettingKeys.shuffle,
    );
  });
}
