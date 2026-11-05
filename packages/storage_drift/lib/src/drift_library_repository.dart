import 'package:drift/drift.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/src/chunks.dart';
import 'package:shiori_storage_drift/src/database.dart';

/// Content storage in SQLite: textbooks, days and words, and which words
/// the learner hid (`words.hidden_at`).
final class DriftLibraryRepository
    implements LibraryRepository, HiddenWordRepository {
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
  Future<List<Word>> words({String? textbookId, int? day}) =>
      _words(textbookId: textbookId, day: day);

  Future<List<Word>> _words({
    String? textbookId,
    int? day,
    bool hiddenOnly = false,
  }) async {
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
    if (hiddenOnly) query.where(w.hiddenAt.isNotNull());
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

  /// One query: textbooks left-joined to their words, grouped by textbook and
  /// day. A textbook without words comes back as one row counting 0.
  @override
  Future<List<TextbookStats>> textbookStats() async {
    final t = _db.textbooks;
    final w = _db.words;
    final count = w.id.count();
    // COUNT of a column counts the rows where it is not NULL.
    final hidden = w.hiddenAt.count();
    final query =
        _db.select(t).join([
            leftOuterJoin(w, w.textbookId.equalsExp(t.id), useColumns: false),
          ])
          ..addColumns([w.day, count, hidden])
          ..groupBy([t.id, w.day])
          ..orderBy([
            // Same order as textbooks(), then days ascending.
            OrderingTerm.asc(t.createdAt),
            OrderingTerm.asc(t.id),
            OrderingTerm.asc(w.day, nulls: NullsOrder.last),
          ]);
    final books = <String, TextbookRow>{};
    final counts = <String, int>{};
    final hiddenCounts = <String, int>{};
    final days = <String, List<int>>{};
    for (final row in await query.get()) {
      final book = row.readTable(t);
      final day = row.read(w.day);
      books[book.id] = book;
      counts[book.id] = (counts[book.id] ?? 0) + (row.read(count) ?? 0);
      hiddenCounts[book.id] =
          (hiddenCounts[book.id] ?? 0) + (row.read(hidden) ?? 0);
      days[book.id] = [...?days[book.id], ?day];
    }
    return List.unmodifiable([
      for (final book in books.values)
        TextbookStats(
          textbook: _textbook(book),
          wordCount: counts[book.id] ?? 0,
          hiddenCount: hiddenCounts[book.id] ?? 0,
          days: List.unmodifiable(days[book.id] ?? const <int>[]),
        ),
    ]);
  }

  /// Updates existing rows in place (`ON CONFLICT DO UPDATE`): a word is
  /// never deleted and re-inserted, so nothing tied to its id is lost.
  /// `hidden_at` is left out of the row, so an insert stores the word shown
  /// and an update keeps what was stored.
  @override
  Future<void> saveWords(List<Word> words) async {
    if (words.isEmpty) return;
    await _db.batch(
      (b) => b.insertAllOnConflictUpdate(_db.words, words.map(_wordContent)),
    );
  }

  /// Only rows still shown are written, so a word keeps the time it was
  /// first hidden.
  @override
  Future<void> hideWords(Iterable<String> wordIds, {required DateTime at}) =>
      _setHidden(wordIds, at);

  @override
  Future<void> unhideWords(Iterable<String> wordIds) =>
      _setHidden(wordIds, null);

  @override
  Future<List<Word>> hiddenWords({String? textbookId}) =>
      _words(textbookId: textbookId, hiddenOnly: true);

  /// Checks every id, then writes, in one transaction: an unknown id or a
  /// failed write leaves every word as it was.
  Future<void> _setHidden(Iterable<String> wordIds, DateTime? at) async {
    final ids = wordIds.toSet().toList();
    if (ids.isEmpty) return;
    final w = _db.words;
    await _db.transaction(() async {
      final found = <String>{};
      for (final chunk in chunked(ids)) {
        final rows =
            await (_db.selectOnly(w)
                  ..addColumns([w.id])
                  ..where(w.id.isIn(chunk)))
                .map((r) => r.read(w.id))
                .get();
        found.addAll(rows.nonNulls);
      }
      final missing = [
        for (final id in ids)
          if (!found.contains(id)) id,
      ];
      if (missing.isNotEmpty) throw WordNotFoundException(missing);
      for (final chunk in chunked(ids)) {
        await (_db.update(w)..where(
              (r) =>
                  r.id.isIn(chunk) &
                  (at == null ? r.hiddenAt.isNotNull() : r.hiddenAt.isNull()),
            ))
            .write(WordsCompanion(hiddenAt: Value(at)));
      }
    });
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
    example: ja != null && ko != null ? Example(ja: ja, ko: ko) : null,
    page: r.page,
    createdAt: r.createdAt,
    hiddenAt: r.hiddenAt,
  );
}

/// Every content column of [w], set even when null (so an update clears a
/// value the page no longer has); `hidden_at` is absent (not content).
WordsCompanion _wordContent(Word w) => WordsCompanion(
  id: Value(w.id),
  textbookId: Value(w.textbookId),
  day: Value(w.day),
  no: Value(w.no),
  headword: Value(w.headword),
  readings: Value(w.readings),
  pos: Value(w.pos),
  meaning: Value(w.meaning),
  exampleJa: Value(w.example?.ja),
  exampleKo: Value(w.example?.ko),
  page: Value(w.page),
  createdAt: Value(w.createdAt),
);
