import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/models/review.dart';

/// Block slot: textbooks, days and words (content).
///
/// First block: `InMemoryLibraryRepository`. Next: drift (SQLite).
abstract interface class LibraryRepository {
  /// Oldest first.
  Future<List<Textbook>> textbooks();

  Future<Textbook?> textbook(String id);

  Future<void> saveTextbook(Textbook textbook);

  /// Ordered by day number.
  Future<List<TextbookDay>> days(String textbookId);

  Future<void> saveDay(TextbookDay day);

  /// Ordered by textbook, day and word number.
  Future<List<Word>> words({String? textbookId, int? day});

  Future<Word?> word(String id);

  /// Inserts or replaces by id.
  Future<void> saveWords(List<Word> words);
}

// TODO(drift): the use cases write in two steps (day then words, card then
// log). The in-memory blocks cannot fail half way; before the SQLite block
// lands, add a transaction to these ports so a failed write cannot leave a
// DAY without words or a card without its log.

/// Block slot: learning state (cards) and the press log, kept apart from content.
///
/// First block: `InMemoryReviewRepository`. Next: drift (SQLite).
abstract interface class ReviewRepository {
  Future<ReviewCard?> card(String wordId);

  /// Cards keyed by word id. All cards when [wordIds] is null.
  Future<Map<String, ReviewCard>> cards({Iterable<String>? wordIds});

  Future<void> saveCard(ReviewCard card);

  Future<void> addLog(ReviewLog log);

  /// Oldest first, optionally only presses at or after [since].
  Future<List<ReviewLog>> logs({DateTime? since});
}
