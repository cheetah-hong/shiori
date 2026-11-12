// 설정 › 백업 on a simulator: the rows, the question before a restore, the
// restore done with 복원 전으로 되돌리기, and two files that cannot be
// restored.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/backup_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. In-memory database, a picker that
// hands over made-up files, and the kept copy in a temporary folder. The
// share sheet and the Files picker are system screens: they are shot by
// hand (docs/verification.md, 37).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/backup_files.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

/// Everyday words (headword, reading, meaning).
const _words = [
  ('水', 'みず', '물'),
  ('火', 'ひ', '불'),
  ('山', 'やま', '산'),
  ('川', 'かわ', '강'),
  ('空', 'そら', '하늘'),
  ('海', 'うみ', '바다'),
  ('雨', 'あめ', '비'),
  ('雪', 'ゆき', '눈'),
  ('花', 'はな', '꽃'),
  ('木', 'き', '나무'),
  ('鳥', 'とり', '새'),
  ('魚', 'さかな', '물고기'),
];

/// The backup the picker hands over: 12 words in two playlists, 30 presses.
BackupData _backup(DateTime at) => BackupData(
  words: [
    for (final (i, (headword, reading, meaning)) in _words.indexed)
      BackupWord(
        id: 'w$i',
        key: headword,
        headword: headword,
        readings: [reading],
        meaning: meaning,
        createdAt: at.add(Duration(seconds: i)),
      ),
  ],
  playlists: [
    BackupPlaylist(id: 'nature', name: '자연', createdAt: at, position: 0),
    BackupPlaylist(id: 'life', name: '생활', createdAt: at, position: 1),
  ],
  playlistWords: [
    for (var i = 0; i < _words.length; i++)
      BackupPlaylistWord(
        playlistId: i < 8 ? 'nature' : 'life',
        wordId: 'w$i',
        position: i,
        addedAt: at,
      ),
  ],
  cards: [
    for (var i = 0; i < 6; i++)
      ReviewCard(
        wordId: 'w$i',
        level: 2,
        dueAt: at.add(const Duration(days: 3)),
        lastReviewedAt: at,
        reviewCount: 2,
      ),
  ],
  logs: [
    for (var i = 0; i < 30; i++)
      BackupLog(
        id: i + 1,
        wordId: 'w${i % 6}',
        answer: i.isEven ? Answer.known : Answer.retry,
        at: at.add(Duration(minutes: i)),
        levelBefore: 1,
        levelAfter: 2,
        retriesInSession: 0,
      ),
  ],
  settings: const {StudySettingKeys.dailyGoal: '20'},
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  /// Pumps until [finder] shows up (providers load asynchronously on device).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('백업 rows, the restore question, done, and refused files', (
    tester,
  ) async {
    final now = DateTime.now();
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await DriftLibraryRepository(database).insertWords([
      Word(
        id: 'now0',
        headword: '鍵',
        readings: const ['かぎ'],
        meaning: '열쇠',
        createdAt: now,
      ),
    ]);
    final kept = Directory.systemTemp.createTempSync('shiori_kept_');
    addTearDown(() => kept.deleteSync(recursive: true));
    var picked = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          backupKeeperProvider.overrideWithValue(
            FileBackupKeeper(directory: () async => kept),
          ),
          backupPickerProvider.overrideWithValue(() async => picked),
        ],
        child: const ShioriApp(),
      ),
    );

    await waitFor(tester, find.byTooltip('설정'));
    await tap(tester, find.byTooltip('설정'));
    await waitFor(tester, find.text('카드 순서 섞기'));
    await tester.scrollUntilVisible(
      find.text('사진·사전·목소리는 백업에 들어가지 않아요(앱에 같이 있어요).'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(tester, '120_settings_backup');

    picked = encodeBackup(
      BackupFile(
        createdAt: now.subtract(const Duration(days: 2)),
        app: const BackupApp(version: '1.0.0', build: '1', schema: 5),
        data: _backup(now.subtract(const Duration(days: 30))),
      ),
    );
    await tap(tester, find.text('백업에서 복원'));
    await waitFor(tester, find.text('백업에서 복원할까요?'));
    await shot(tester, '123_restore_question');

    await tap(tester, find.text('복원'));
    await waitFor(tester, find.text('복원 전으로 되돌리기'));
    await shot(tester, '124_restore_done');

    picked = utf8.encode('{"format":"shiori-backup","version":2}');
    await tester.pump(const Duration(seconds: 5));
    await tap(tester, find.text('백업에서 복원'));
    await waitFor(tester, find.text('복원하지 못했어요'));
    await shot(tester, '125_restore_newer');
    await tap(tester, find.text('확인'));

    final damaged =
        jsonDecode(
              utf8.decode(
                encodeBackup(
                  BackupFile(
                    createdAt: now,
                    app: const BackupApp(
                      version: '1.0.0',
                      build: '1',
                      schema: 5,
                    ),
                    data: _backup(now),
                  ),
                ),
              ),
            )
            as Map<String, Object?>;
    final rows =
        (damaged['reviewCards']! as Map<String, Object?>)['rows']! as List;
    (rows.first as List)[2] = 'w-missing';
    picked = utf8.encode(jsonEncode(damaged));
    await tap(tester, find.text('백업에서 복원'));
    await waitFor(tester, find.text('복원하지 못했어요'));
    await shot(tester, '126_restore_damaged');
  });
}
