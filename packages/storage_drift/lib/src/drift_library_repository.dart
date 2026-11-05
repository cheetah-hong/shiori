import 'package:drift/drift.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/src/database.dart';

/// Content storage in SQLite: textbooks, days and words.
final class DriftLibraryRepository implements LibraryRepository {
  DriftLibraryRepository(this._db);

  final ShioriDatabase _db;

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  @override
  Future<List<Textbook>> textbooks() async {
    final rows =
        await (_db.select(_db.textbooks)..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get();
    return List.unmodifiable(rows.map(_textbook));
  }

  @override
  Future<Textbook?> textbook(String id) async {
    final row = await (_db.select(
      _db.textbooks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _textbook(row);
  }

  @override
  Future<void> saveTextbook(Textbook textbook) => _db
      .into(_db.textbooks)
      .insertOnConflictUpdate(
        TextbookRow(
          id: textbook.id,
          title: textbook.title,
          createdAt: textbook.createdAt,
          templateId: textbook.templateId,
        ),
      );

  @override
  Future<List<TextbookDay>> days(String textbookId) async {
    final rows =
        await (_db.select(_db.textbookDays)
              ..where((d) => d.textbookId.equals(textbookId))
              ..orderBy([(d) => OrderingTerm.asc(d.number)]))
            .get();
    return List.unmodifiable(
      rows.map(
        (r) => TextbookDay(
          textbookId: r.textbookId,
          number: r.number,
          title: r.title,
        ),
      ),
    );
  }

  @override
  Future<void> saveDay(TextbookDay day) => _db
      .into(_db.textbookDays)
      .insertOnConflictUpdate(
        DayRow(
          textbookId: day.textbookId,
          number: day.number,
          title: day.title,
        ),
      );

  @override
  Future<List<Word>> words({String? textbookId, int? day}) async {
    final w = _db.words;
    final t = _db.textbooks;
    final query =
        _db.select(w).join([leftOuterJoin(t, t.id.equalsExp(w.textbookId))])
          ..orderBy([
            // Same order as the in-memory block: textbooks oldest first, then
            // day and number with blanks last, then creation time and id.
            OrderingTerm.asc(t.createdAt, nulls: NullsOrder.last),
            OrderingTerm.asc(w.textbookId),
            OrderingTerm.asc(w.day, nulls: NullsOrder.last),
            OrderingTerm.asc(w.no, nulls: NullsOrder.last),
            OrderingTerm.asc(w.createdAt),
            OrderingTerm.asc(w.id),
          ]);
    if (textbookId != null) query.where(w.textbookId.equals(textbookId));
    if (day != null) query.where(w.day.equals(day));
    final rows = await query.get();
    return List.unmodifiable(rows.map((r) => _word(r.readTable(w))));
  }

  @override
  Future<Word?> word(String id) async {
    final row = await (_db.select(
      _db.words,
    )..where((w) => w.id.equals(id))).getSingleOrNull();
    return row == null ? null : _word(row);
  }

  /// Updates existing rows in place (`ON CONFLICT DO UPDATE`): a word is
  /// never deleted and re-inserted, so nothing tied to its id is lost.
  @override
  Future<void> saveWords(List<Word> words) async {
    if (words.isEmpty) return;
    await _db.batch(
      (b) => b.insertAllOnConflictUpdate(_db.words, words.map(_wordRow)),
    );
  }
}

Textbook _textbook(TextbookRow r) => Textbook(
  id: r.id,
  title: r.title,
  createdAt: r.createdAt,
  templateId: r.templateId,
);

Word _word(WordRow r) {
  final ja = r.exampleJa, ko = r.exampleKo;
  return Word(
    id: r.id,
    textbookId: r.textbookId,
    day: r.day,
    no: r.no,
    headword: r.headword,
    readings: r.readings,
    pos: r.pos,
    meaning: r.meaning,
    important: r.important,
    example: ja != null && ko != null ? Example(ja: ja, ko: ko) : null,
    page: r.page,
    createdAt: r.createdAt,
  );
}

WordRow _wordRow(Word w) => WordRow(
  id: w.id,
  textbookId: w.textbookId,
  day: w.day,
  no: w.no,
  headword: w.headword,
  readings: w.readings,
  pos: w.pos,
  meaning: w.meaning,
  important: w.important,
  exampleJa: w.example?.ja,
  exampleKo: w.example?.ko,
  page: w.page,
  createdAt: w.createdAt,
);
