import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/ports/repositories.dart';
import 'package:shiori_core/src/storage/in_memory_transactions.dart';

typedef _LibraryState = (
  Map<String, Textbook>,
  Map<String, TextbookDay>,
  Map<String, Word>,
);

/// Keeps the library in memory (lost when the app quits). Used by tests;
/// the app stores it in SQLite (`packages/storage_drift`).
///
/// Unlike the SQLite block it does not check that a day's or word's textbook
/// exists (tests save words on their own); `LibraryService` checks it first.
final class InMemoryLibraryRepository implements LibraryRepository {
  final Map<String, Textbook> _textbooks = {};
  final Map<String, TextbookDay> _days = {};
  final Map<String, Word> _words = {};

  late final _tx = InMemoryTransactions<_LibraryState>(
    snapshot: () => (Map.of(_textbooks), Map.of(_days), Map.of(_words)),
    restore: (state) {
      final (textbooks, days, words) = state;
      _textbooks
        ..clear()
        ..addAll(textbooks);
      _days
        ..clear()
        ..addAll(days);
      _words
        ..clear()
        ..addAll(words);
    },
  );

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _tx.transaction(action);

  @override
  Future<List<Textbook>> textbooks() =>
      _tx.run(() => List<Textbook>.unmodifiable(_sortedTextbooks()));

  @override
  Future<Textbook?> textbook(String id) => _tx.run(() => _textbooks[id]);

  @override
  Future<void> saveTextbook(Textbook textbook) =>
      _tx.run(() => _textbooks[textbook.id] = textbook);

  @override
  Future<List<TextbookDay>> days(String textbookId) =>
      _tx.run(() => _daysOf(textbookId));

  List<TextbookDay> _daysOf(String textbookId) {
    final days = _days.values.where((d) => d.textbookId == textbookId).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return List.unmodifiable(days);
  }

  @override
  Future<void> saveDay(TextbookDay day) => _tx.run(() => _days[day.key] = day);

  @override
  Future<List<Word>> words({String? textbookId, int? day}) =>
      _tx.run(() => _wordsOf(textbookId, day));

  List<Word> _wordsOf(String? textbookId, int? day) {
    final rank = {for (final (i, t) in _sortedTextbooks().indexed) t.id: i};
    final words =
        _words.values
            .where(
              (w) =>
                  (textbookId == null || w.textbookId == textbookId) &&
                  (day == null || w.day == day),
            )
            .toList()
          ..sort((a, b) => _compareWords(a, b, rank));
    return List.unmodifiable(words);
  }

  @override
  Future<Word?> word(String id) => _tx.run(() => _words[id]);

  @override
  Future<void> saveWords(List<Word> words) => _tx.run(() {
    for (final w in words) {
      _words[w.id] = w;
    }
  });

  List<Textbook> _sortedTextbooks() => _textbooks.values.toList()
    ..sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
}

const int _last = 1 << 30;

int _compareWords(Word a, Word b, Map<String, int> textbookRank) {
  final byBook = (textbookRank[a.textbookId] ?? _last).compareTo(
    textbookRank[b.textbookId] ?? _last,
  );
  if (byBook != 0) return byBook;
  final byBookId = a.textbookId.compareTo(b.textbookId);
  if (byBookId != 0) return byBookId;
  final byDay = (a.day ?? _last).compareTo(b.day ?? _last);
  if (byDay != 0) return byDay;
  final byNo = (a.no ?? '\u{10FFFF}').compareTo(b.no ?? '\u{10FFFF}');
  if (byNo != 0) return byNo;
  final byTime = a.createdAt.compareTo(b.createdAt);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}
