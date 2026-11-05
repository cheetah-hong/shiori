import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/ports/repositories.dart';

/// First storage block: keeps the library in memory (lost when the app quits).
/// Next block: drift (SQLite) behind the same interface.
final class InMemoryLibraryRepository implements LibraryRepository {
  final Map<String, Textbook> _textbooks = {};
  final Map<String, TextbookDay> _days = {};
  final Map<String, Word> _words = {};

  @override
  Future<List<Textbook>> textbooks() async =>
      List.unmodifiable(_sortedTextbooks());

  @override
  Future<Textbook?> textbook(String id) async => _textbooks[id];

  @override
  Future<void> saveTextbook(Textbook textbook) async =>
      _textbooks[textbook.id] = textbook;

  @override
  Future<List<TextbookDay>> days(String textbookId) async {
    final days = _days.values.where((d) => d.textbookId == textbookId).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return List.unmodifiable(days);
  }

  @override
  Future<void> saveDay(TextbookDay day) async => _days[day.key] = day;

  @override
  Future<List<Word>> words({String? textbookId, int? day}) async {
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
  Future<Word?> word(String id) async => _words[id];

  @override
  Future<void> saveWords(List<Word> words) async {
    for (final w in words) {
      _words[w.id] = w;
    }
  }

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
