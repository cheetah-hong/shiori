import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/models/review.dart';

/// Block slot: textbooks, days and words (content).
///
/// Blocks: `InMemoryLibraryRepository` (tests), `DriftLibraryRepository` (app).
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

  /// Every textbook (in the order of [textbooks]) with its word count and
  /// days, in one read: the shelf does not list each textbook's words.
  Future<List<TextbookStats>> textbookStats();

  /// Inserts or replaces by id.
  Future<void> saveWords(List<Word> words);

  /// Runs [action] so that its writes land together or not at all.
  ///
  /// When [action] throws, every write it made through this repository is
  /// undone and the error is rethrown. Calls made inside [action] see its
  /// writes; calls from elsewhere wait until it ends. A nested call is a
  /// savepoint: if it throws and the outer action catches the error, only the
  /// nested writes are undone.
  ///
  /// The use cases write in two steps (DAY then words, card then log); this
  /// keeps a failed write from leaving a DAY without its words or a card
  /// without its log. Write only to this repository inside [action].
  Future<T> transaction<T>(Future<T> Function() action);
}

/// Block slot: learning state (cards) and the press log, kept apart from content.
///
/// Blocks: `InMemoryReviewRepository` (tests), `DriftReviewRepository` (app).
abstract interface class ReviewRepository {
  Future<ReviewCard?> card(String wordId);

  /// Cards keyed by word id. All cards when [wordIds] is null.
  Future<Map<String, ReviewCard>> cards({Iterable<String>? wordIds});

  Future<void> saveCard(ReviewCard card);

  Future<void> addLog(ReviewLog log);

  /// Oldest first (presses at the same instant in the order they were
  /// added), optionally only presses at or after [since].
  Future<List<ReviewLog>> logs({DateTime? since});

  /// Same meaning as [LibraryRepository.transaction].
  Future<T> transaction<T>(Future<T> Function() action);
}
