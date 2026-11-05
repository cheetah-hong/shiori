import 'dart:io';

import 'package:drift/native.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:shiori_storage_drift/src/converters.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime(2026, 11, 5, 21, 0, 0, 0, 7);

  Word word(String id, {String tb = 'tb'}) => Word(
    id: id,
    textbookId: tb,
    headword: '雨',
    readings: const ['あめ'],
    meaning: '비',
    createdAt: t0,
  );

  group('tables', () {
    late ShioriDatabase db;
    late DriftLibraryRepository library;
    late DriftReviewRepository reviews;

    setUp(() async {
      db = ShioriDatabase.memory();
      library = DriftLibraryRepository(db);
      reviews = DriftReviewRepository(db);
      await library.saveTextbook(
        Textbook(id: 'tb', title: '단어장', createdAt: t0),
      );
    });

    tearDown(() => db.close());

    test('content and learning state are separate tables', () async {
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name",
          )
          .map((r) => r.read<String>('name'))
          .get();
      expect(tables, [
        'review_cards',
        'review_logs',
        'textbook_days',
        'textbooks',
        'words',
      ]);
    });

    test('foreign keys are on: a word needs its textbook', () async {
      final on = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(on.read<int>('foreign_keys'), 1);
      await expectLater(
        library.saveWords([word('x:1', tb: 'missing')]),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        library.saveDay(
          const TextbookDay(textbookId: 'missing', number: 1, title: ''),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'rewriting a word keeps its card, even with foreign keys on',
      () async {
        await library.saveWords([word('tb:0001')]);
        final card = ReviewCard(
          wordId: 'tb:0001',
          level: 3,
          dueAt: t0.add(const Duration(days: 7)),
          lastReviewedAt: t0,
          reviewCount: 2,
        );
        await reviews.saveCard(card);
        for (var i = 0; i < 3; i++) {
          await library.saveWords([word('tb:0001'), word('tb:0002')]);
        }
        expect(await reviews.card('tb:0001'), card);
        final rows = await db.select(db.words).get();
        expect(rows.length, 2);
      },
    );

    test('a card does not need a word row (state outlives content)', () async {
      final card = ReviewCard(
        wordId: 'gone:1',
        level: 1,
        dueAt: t0,
        lastReviewedAt: t0,
      );
      await reviews.saveCard(card);
      expect(await reviews.card('gone:1'), card);
    });

    test('an example must have both sentence and translation', () async {
      await expectLater(
        db.customStatement(
          'INSERT INTO words (id, textbook_id, headword, readings, meaning, '
          "important, example_ja, created_at) VALUES ('tb:9', 'tb', 'x', "
          "'[]', '', 0, 'ja only', 0)",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('times are stored as UTC microseconds since the epoch', () async {
      await library.saveWords([word('tb:0001')]);
      final raw = await db
          .customSelect("SELECT created_at FROM words WHERE id = 'tb:0001'")
          .getSingle();
      expect(raw.read<int>('created_at'), t0.toUtc().microsecondsSinceEpoch);
      expect((await library.word('tb:0001'))?.createdAt, t0);
    });

    test('broken readings fail loudly instead of reading as empty', () async {
      await db.customStatement(
        'INSERT INTO words (id, textbook_id, headword, readings, meaning, '
        "important, created_at) VALUES ('tb:9', 'tb', 'x', '{\"a\":1}', '', "
        '0, 0)',
      );
      await expectLater(library.word('tb:9'), throwsFormatException);
    });
  });

  group('converters', () {
    test('readings round trip in order, and reject non-string items', () {
      const c = StringListConverter();
      expect(c.fromSql(c.toSql(const ['あ', 'い'])), ['あ', 'い']);
      expect(c.fromSql('[]'), isEmpty);
      expect(() => c.fromSql('[1]'), throwsFormatException);
      expect(() => c.fromSql('not json'), throwsFormatException);
    });

    test('times keep microseconds and read back as local time', () {
      const c = UtcMicrosConverter();
      final utc = DateTime.utc(2026, 1, 1, 0, 0, 0, 0, 1);
      final back = c.fromSql(c.toSql(utc));
      expect(back.isAtSameMomentAs(utc), isTrue);
      expect(back.isUtc, isFalse);
      expect(c.fromSql(c.toSql(t0)), t0);
    });
  });

  group('file', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('shiori_db_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('words and learning state survive closing and reopening', () async {
      final file = File('${dir.path}/shiori.sqlite');
      final first = ShioriDatabase.file(file);
      final lib1 = DriftLibraryRepository(first);
      final rev1 = DriftReviewRepository(first);
      await lib1.saveTextbook(Textbook(id: 'tb', title: '단어장', createdAt: t0));
      await lib1.saveWords([word('tb:0001')]);
      final card = ReviewCard(
        wordId: 'tb:0001',
        level: 4,
        dueAt: t0.add(const Duration(days: 21)),
        lastReviewedAt: t0,
        reviewCount: 1,
      );
      await rev1.transaction(() async {
        await rev1.saveCard(card);
        await rev1.addLog(
          ReviewLog(
            wordId: 'tb:0001',
            answer: Answer.known,
            at: t0,
            levelBefore: 0,
            levelAfter: 4,
            retriesInSession: 0,
          ),
        );
      });
      await first.close();

      final second = ShioriDatabase.file(file);
      addTearDown(second.close);
      expect(
        await DriftLibraryRepository(second).word('tb:0001'),
        word('tb:0001'),
      );
      final rev2 = DriftReviewRepository(second);
      expect(await rev2.card('tb:0001'), card);
      expect((await rev2.logs()).single.at, t0);
    });

    test('a file from an unknown schema version is refused', () async {
      final file = File('${dir.path}/newer.sqlite');
      final newer = ShioriDatabase(
        NativeDatabase(file, setup: (raw) => raw.userVersion = 2),
      );
      await expectLater(
        newer.customSelect('SELECT 1').get(),
        throwsA(isA<UnsupportedError>()),
      );
      await newer.close();
    });
  });
}
