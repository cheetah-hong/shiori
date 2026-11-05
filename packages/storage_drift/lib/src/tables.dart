// Table declarations: read by the drift code generator, never run, so they
// are left out of test coverage.
// coverage:ignore-file
import 'package:drift/drift.dart';
import 'package:shiori_core/shiori_core.dart' show Answer, PartOfSpeech;
import 'package:shiori_storage_drift/src/converters.dart';

// ------------------------------------------------------------- content

@DataClassName('TextbookRow')
class Textbooks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get createdAt => integer().map(const UtcMicrosConverter())();
  TextColumn get templateId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DayRow')
class TextbookDays extends Table {
  TextColumn get textbookId => text().references(Textbooks, #id)();
  IntColumn get number => integer()();
  TextColumn get title => text()();

  @override
  Set<Column<Object>> get primaryKey => {textbookId, number};
}

/// Words, keyed `textbookId:number`. Saving a page again updates rows in
/// place (`ON CONFLICT DO UPDATE`), never deletes them.
@DataClassName('WordRow')
@TableIndex(name: 'words_by_place', columns: {#textbookId, #day, #no})
class Words extends Table {
  TextColumn get id => text()();
  TextColumn get textbookId => text().references(Textbooks, #id)();
  IntColumn get day => integer().nullable()();
  TextColumn get no => text().nullable()();
  TextColumn get headword => text()();

  /// JSON array: always read and written with the word, never queried alone.
  TextColumn get readings => text().map(const StringListConverter())();
  TextColumn get pos => textEnum<PartOfSpeech>().nullable()();
  TextColumn get meaning => text()();
  BoolColumn get important => boolean()();

  /// The example sentence and its translation come as a pair or not at all.
  TextColumn get exampleJa => text().nullable()();
  TextColumn get exampleKo => text().nullable()();
  IntColumn get page => integer().nullable()();
  IntColumn get createdAt => integer().map(const UtcMicrosConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((example_ja IS NULL) = (example_ko IS NULL))',
  ];
}

// ------------------------------------------------------------- learning state

/// One card per word. No foreign key to [Words]: the learning state belongs
/// to the word id and must outlive any rewrite of the word's content.
@DataClassName('CardRow')
class ReviewCards extends Table {
  TextColumn get wordId => text()();
  IntColumn get level => integer()();
  IntColumn get dueAt => integer().map(const UtcMicrosConverter())();
  IntColumn get lastReviewedAt => integer().map(const UtcMicrosConverter())();
  IntColumn get reviewCount => integer()();
  IntColumn get lapseCount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {wordId};
}

/// Every button press, in the order it was made (append only).
@DataClassName('LogRow')
@TableIndex(name: 'review_logs_by_time', columns: {#at})
class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get wordId => text()();
  TextColumn get answer => textEnum<Answer>()();
  IntColumn get at => integer().map(const UtcMicrosConverter())();
  IntColumn get levelBefore => integer()();
  IntColumn get levelAfter => integer()();
  IntColumn get retriesInSession => integer()();
}
