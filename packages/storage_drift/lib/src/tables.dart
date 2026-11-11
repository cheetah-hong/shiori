// Table declarations: read by the drift code generator, never run, so they
// are left out of test coverage.
// coverage:ignore-file
import 'package:drift/drift.dart';
import 'package:shiori_core/shiori_core.dart'
    show Answer, PartOfSpeech, StudyMode;
import 'package:shiori_storage_drift/src/converters.dart';

// ------------------------------------------------------------- content

/// Library words, each once: [key] (`Word.key`, from the headword) is
/// unique. Playlists point at them through [PlaylistWords].
@DataClassName('WordRow')
class Words extends Table {
  TextColumn get id => text()();

  /// What makes two words the same word (`wordKey`). Unique.
  TextColumn get key => text().unique()();
  TextColumn get headword => text()();

  /// JSON array: always read and written with the word, never queried alone.
  TextColumn get readings => text().map(const StringListConverter())();
  TextColumn get pos => textEnum<PartOfSpeech>().nullable()();
  TextColumn get meaning => text()();

  /// The example sentence and its translation come as a pair or not at all.
  TextColumn get exampleJa => text().nullable()();
  TextColumn get exampleKo => text().nullable()();
  IntColumn get createdAt => integer().map(const UtcMicrosConverter())();

  /// When the learner hid the word (이미 알아요); null while it is shown.
  /// Per word: hidden in every playlist that holds it.
  IntColumn get hiddenAt =>
      integer().nullable().map(const UtcMicrosConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((example_ja IS NULL) = (example_ko IS NULL))',
  ];
}

/// The learner's playlists, in [position] order on the home screen.
@DataClassName('PlaylistRow')
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer().map(const UtcMicrosConverter())();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (length(trim(name)) > 0)'];
}

/// Which words a playlist holds, in [position] order. The primary key keeps
/// a word once per playlist. Deleting a playlist removes its rows; the
/// words stay.
@DataClassName('PlaylistWordRow')
@TableIndex(name: 'playlist_words_by_word', columns: {#wordId})
class PlaylistWords extends Table {
  TextColumn get playlistId =>
      text().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get wordId =>
      text().references(Words, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  IntColumn get addedAt => integer().map(const UtcMicrosConverter())();

  @override
  Set<Column<Object>> get primaryKey => {playlistId, wordId};
}

// ------------------------------------------------------------- learning state

/// One card per word, scope and study mode: scope `''` is the record every
/// playlist shares (the only scope used now), `p:<playlist id>` a word's
/// record inside one playlist (`CardScope`); [mode] is the way of studying
/// (`StudyMode`, stored by name). A card goes with its word.
@DataClassName('CardRow')
class ReviewCards extends Table {
  TextColumn get scope => text()();

  /// Cards written before modes existed (schema v4) were all 뜻 맞히기; the
  /// repository always names the mode.
  TextColumn get mode =>
      textEnum<StudyMode>().withDefault(const Constant('meaning'))();
  TextColumn get wordId =>
      text().references(Words, #id, onDelete: KeyAction.cascade)();
  IntColumn get level => integer()();
  IntColumn get dueAt => integer().map(const UtcMicrosConverter())();
  IntColumn get lastReviewedAt => integer().map(const UtcMicrosConverter())();
  IntColumn get reviewCount => integer()();
  IntColumn get lapseCount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {scope, mode, wordId};
}

/// Every button press, in the order it was made (append only). History: no
/// foreign key, a press stays when its word goes.
@DataClassName('LogRow')
@TableIndex(name: 'review_logs_by_time', columns: {#at})
class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get scope => text()();

  /// Presses logged before modes existed (schema v4) were all 뜻 맞히기.
  TextColumn get mode =>
      textEnum<StudyMode>().withDefault(const Constant('meaning'))();
  TextColumn get wordId => text()();
  TextColumn get answer => textEnum<Answer>()();
  IntColumn get at => integer().map(const UtcMicrosConverter())();
  IntColumn get levelBefore => integer()();
  IntColumn get levelAfter => integer()();
  IntColumn get retriesInSession => integer()();
}

// ------------------------------------------------------------- settings

/// The learner's options as key → value (`StudyPreferences`), so a new
/// option needs no new schema.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
