// The app on the database file a learner already has: a v3 file (textbooks,
// DAYs) is emptied and the app starts clean on v4; a failure while emptying
// leaves the old file and the home screen can try again; the v4 file keeps
// what was added. The file is a real SQLite file in a temporary folder.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/startup.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/harness.dart';

/// A v3 file as the app wrote it: two textbooks, DAYs, words (one hidden),
/// cards and logs.
void _writeV3(File file) {
  final db = sqlite3.open(file.path);
  db.execute('''
    CREATE TABLE textbooks (id TEXT NOT NULL, title TEXT NOT NULL,
      created_at INTEGER NOT NULL, template_id TEXT NULL, PRIMARY KEY (id));
    CREATE TABLE textbook_days (textbook_id TEXT NOT NULL REFERENCES
      textbooks (id), number INTEGER NOT NULL, title TEXT NOT NULL,
      PRIMARY KEY (textbook_id, number));
    CREATE TABLE words (id TEXT NOT NULL, textbook_id TEXT NOT NULL
      REFERENCES textbooks (id), day INTEGER NULL, "no" TEXT NULL,
      headword TEXT NOT NULL, readings TEXT NOT NULL, pos TEXT NULL,
      meaning TEXT NOT NULL, example_ja TEXT NULL, example_ko TEXT NULL,
      page INTEGER NULL, created_at INTEGER NOT NULL, hidden_at INTEGER NULL,
      PRIMARY KEY (id),
      CHECK ((example_ja IS NULL) = (example_ko IS NULL)));
    CREATE TABLE review_cards (word_id TEXT NOT NULL, level INTEGER NOT NULL,
      due_at INTEGER NOT NULL, last_reviewed_at INTEGER NOT NULL,
      review_count INTEGER NOT NULL, lapse_count INTEGER NOT NULL,
      PRIMARY KEY (word_id));
    CREATE TABLE review_logs (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      word_id TEXT NOT NULL, answer TEXT NOT NULL, at INTEGER NOT NULL,
      level_before INTEGER NOT NULL, level_after INTEGER NOT NULL,
      retries_in_session INTEGER NOT NULL);
    CREATE INDEX words_by_place ON words (textbook_id, day, "no");
    CREATE INDEX review_logs_by_time ON review_logs (at);
    INSERT INTO textbooks VALUES ('tb', 'JLPT 단어장', 1, 'vocab.list'),
      ('tb-2', '내 단어장', 2, NULL);
    INSERT INTO textbook_days VALUES ('tb', 1, '자연, 몸');
    INSERT INTO words VALUES
      ('tb:0001', 'tb', 1, '0001', '雨', '["あめ"]', 'noun', '비', NULL, NULL,
        10, 1, NULL),
      ('tb:0002', 'tb', 1, '0002', '雪', '["ゆき"]', 'noun', '눈', NULL, NULL,
        10, 1, 5),
      ('tb-2:w9-0000', 'tb-2', NULL, NULL, '空', '["そら"]', NULL, '하늘',
        NULL, NULL, NULL, 2, NULL);
    INSERT INTO review_cards VALUES ('tb:0001', 2, 3, 1, 1, 0);
    INSERT INTO review_logs (word_id, answer, at, level_before, level_after,
      retries_in_session) VALUES ('tb:0001', 'known', 1, 0, 2, 0);
    PRAGMA user_version = 3;
  ''');
  db.close();
}

int _userVersion(File file) {
  final db = sqlite3.open(file.path);
  try {
    return db.select('PRAGMA user_version').single.values.single! as int;
  } finally {
    db.close();
  }
}

int _count(File file, String table) {
  final db = sqlite3.open(file.path);
  try {
    return db.select('SELECT COUNT(*) AS n FROM $table').single['n'] as int;
  } finally {
    db.close();
  }
}

/// The test blocks without their in-memory storage: the app's own drift
/// blocks run on [database].
List<Override> _overrides(TestBlocks blocks, Override database) => [
  database,
  clockProvider.overrideWith((ref) => blocks.clock),
  devSamplesEnabledProvider.overrideWithValue(true),
  sampleRecognizerProvider.overrideWithValue(blocks.sampleRecognizer),
  bundledDictionaryProvider.overrideWith(
    (ref) async => const BundledDictionary.unavailable('no dictionary'),
  ),
  bundledGlossaryProvider.overrideWith(
    (ref) async => const BundledGlossary.unavailable('no glossary'),
  ),
];

Widget _app(TestBlocks blocks, Override database) => ProviderScope(
  retry: (_, _) => null,
  overrides: _overrides(blocks, database),
  child: const ShioriApp(),
);

/// Opens [file] on this isolate (widget tests run on a fake clock).
ShioriDatabase _open(File file, {ResetHook? onReset}) =>
    ShioriDatabase(NativeDatabase(file), onReset: onReset);

Future<void> _addSample(WidgetTester tester) async {
  await tester.tap(find.text('페이지 등록'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('DAY 01 자연, 몸').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('DAY 01 자연, 몸').first);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(RegExp(r'^단어 \d+개 추가$')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('만들고 추가'));
  await tester.pumpAndSettle();
}

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('shiori_v3_app_');
    file = File('${dir.path}/shiori.sqlite');
    _writeV3(file);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets(
    'a v3 file starts as an empty v4: the home is empty, capture and add work',
    (tester) async {
      usePhoneSize(tester);
      final blocks = TestBlocks();
      final database = (await tester.runAsync(
        () => appDatabaseOverride(locate: () async => file, open: _open),
      ))!;
      await tester.pumpWidget(_app(blocks, database));
      await tester.pumpAndSettle();

      expect(find.text('페이지를 등록하고 재생목록에 단어를 모아 보세요'), findsOneWidget);
      expect(find.text('먼저 페이지를 등록해 주세요'), findsOneWidget);
      expect(find.text('JLPT 단어장'), findsNothing);
      expect(_userVersion(file), 5);
      expect(_count(file, 'words'), 0);

      await _addSample(tester);
      expect(find.text('내 단어장'), findsOneWidget);
      expect(find.textContaining("'내 단어장'에 단어"), findsOneWidget);
      expect(_count(file, 'words'), greaterThan(0));
      expect(_count(file, 'playlist_words'), _count(file, 'words'));

      // The app is closed and opened again on the same v4 file.
      final words = _count(file, 'words');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final again = (await tester.runAsync(
        () => appDatabaseOverride(locate: () async => file, open: _open),
      ))!;
      await tester.pumpWidget(_app(blocks, again));
      await tester.pumpAndSettle();
      expect(find.text('내 단어장'), findsOneWidget);
      expect(find.text('단어 $words개'), findsOneWidget);
      expect(_count(file, 'words'), words);
    },
  );

  testWidgets(
    'a failure while emptying keeps the v3 file and the home can try again',
    (tester) async {
      usePhoneSize(tester);
      final blocks = TestBlocks();
      var opens = 0;
      ShioriDatabase open(File f) {
        opens++;
        return _open(
          f,
          onReset: opens == 1
              ? () async => throw const FileSystemException('disk full')
              : null,
        );
      }

      final database = (await tester.runAsync(
        () => appDatabaseOverride(locate: () async => file, open: open),
      ))!;
      await tester.pumpWidget(_app(blocks, database));
      await tester.pumpAndSettle();

      expect(find.textContaining('불러오지 못했어요'), findsWidgets);
      expect(find.text('다시 불러오기'), findsWidgets);
      expect(_userVersion(file), 3, reason: 'the old file is as it was');
      expect(_count(file, 'words'), 3);
      expect(_count(file, 'textbooks'), 2);

      await tester.tap(find.text('다시 불러오기').first);
      await tester.pumpAndSettle();

      expect(opens, 2, reason: 'a new connection, not the failed one');
      expect(find.textContaining('불러오지 못했어요'), findsNothing);
      expect(find.text('페이지를 등록하고 재생목록에 단어를 모아 보세요'), findsOneWidget);
      expect(_userVersion(file), 5);
      expect(_count(file, 'words'), 0);
    },
  );
}
