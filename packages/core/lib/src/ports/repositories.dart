import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/models/review.dart';

/// A word whose key is already in the library (`Word.key`): the library
/// holds each word once. Nothing is written when it is thrown.
final class DuplicateWordException implements Exception {
  const DuplicateWordException(this.keys);

  /// The keys already taken, in the order they were given.
  final List<String> keys;

  @override
  String toString() => 'DuplicateWordException: ${keys.join(', ')}';
}

/// A playlist id that is not in the library.
final class PlaylistNotFoundException implements Exception {
  const PlaylistNotFoundException(this.playlistId);

  final String playlistId;

  @override
  String toString() => 'PlaylistNotFoundException: $playlistId';
}

/// Block slot: library words (content) and the playlists that point at them.
///
/// Blocks: `InMemoryLibraryRepository` (tests), `DriftLibraryRepository` (app).
abstract interface class LibraryRepository {
  /// The words of playlist [playlistId] in its order, or (null) every word
  /// that is in at least one playlist, oldest first (creation time, then id).
  /// A word in no playlist is kept in the library but not listed. Hidden
  /// words are included (`Word.isHidden` tells them apart).
  Future<List<Word>> words({String? playlistId});

  /// Any library word, also one in no playlist.
  Future<Word?> word(String id);

  /// Library words (also ones in no playlist) by `Word.key`, for the keys
  /// that have one.
  Future<Map<String, Word>> wordsByKey(Iterable<String> keys);

  /// Adds new words, all or none. Throws [DuplicateWordException] when a
  /// word's key (or id) is already in the library, or two of [words] share
  /// one. A new word is stored shown, whatever `Word.hiddenAt` says.
  Future<void> insertWords(List<Word> words);

  /// Every playlist by position (then creation time, then id).
  Future<List<Playlist>> playlists();

  Future<Playlist?> playlist(String id);

  /// Inserts the playlist or replaces its name and position by id.
  Future<void> savePlaylist(Playlist playlist);

  /// Removes the playlist and its entries. Its words stay in the library
  /// (with their learning state) even when no other playlist holds them.
  /// An unknown id does nothing.
  Future<void> deletePlaylist(String id);

  /// Every playlist (in the order of [playlists]) with its counts, in one read.
  Future<List<PlaylistStats>> playlistStats();

  /// Appends [wordIds] to playlist [playlistId] in their order, at [at].
  /// Words already in it keep their place; a word listed twice is added
  /// once. Throws [PlaylistNotFoundException] or `WordNotFoundException`
  /// (and adds nothing) for an unknown id.
  Future<void> addToPlaylist(
    String playlistId,
    List<String> wordIds, {
    required DateTime at,
  });

  /// Takes [wordIds] out of playlist [playlistId] and returns the entries
  /// removed (to undo with [restoreEntries]). Ids not in it are skipped.
  /// The words stay in the library.
  Future<List<PlaylistEntry>> removeFromPlaylist(
    String playlistId,
    Iterable<String> wordIds,
  );

  /// Puts [entries] back as they were (position and time). An entry whose
  /// word is already in that playlist, or whose playlist or word is gone,
  /// is skipped.
  Future<void> restoreEntries(List<PlaylistEntry> entries);

  /// The playlists each of [wordIds] is in (a word in none is absent).
  Future<Map<String, Set<String>>> playlistsOf(Iterable<String> wordIds);

  /// Runs [action] so that its writes land together or not at all.
  ///
  /// When [action] throws, every write it made through this repository is
  /// undone and the error is rethrown. Calls made inside [action] see its
  /// writes; calls from elsewhere wait until it ends. A nested call is a
  /// savepoint: if it throws and the outer action catches the error, only the
  /// nested writes are undone.
  ///
  /// The use cases write in steps (new words, then playlist entries; card
  /// then log); this keeps a failed write from leaving half of them. Write
  /// only to this repository inside [action].
  Future<T> transaction<T>(Future<T> Function() action);
}

/// Block slot: learning state (cards) and the press log, kept apart from content.
///
/// Every read and write names a [CardScope]; the app uses
/// [CardScope.shared] only (one record per word).
///
/// Blocks: `InMemoryReviewRepository` (tests), `DriftReviewRepository` (app).
abstract interface class ReviewRepository {
  Future<ReviewCard?> card(String wordId, {CardScope scope = CardScope.shared});

  /// Cards of [scope] keyed by word id. All of that scope's cards when
  /// [wordIds] is null.
  Future<Map<String, ReviewCard>> cards({
    Iterable<String>? wordIds,
    CardScope scope = CardScope.shared,
  });

  /// Stores [card] under its own scope (`ReviewCard.scope`).
  Future<void> saveCard(ReviewCard card);

  Future<void> addLog(ReviewLog log);

  /// Removes the cards of [wordIds] in [scope] and returns them (to put back
  /// with [saveCard]). Ids without a card are skipped, an id listed twice is
  /// removed once. The press log is kept.
  Future<List<ReviewCard>> deleteCards(
    Iterable<String> wordIds, {
    CardScope scope = CardScope.shared,
  });

  /// Removes every card of [scope] (null: of every scope) and returns how
  /// many. The press log is kept.
  Future<int> deleteAllCards({CardScope? scope});

  /// Oldest first (presses at the same instant in the order they were
  /// added), optionally only presses at or after [since] and only of
  /// [scope] (null: every scope).
  Future<List<ReviewLog>> logs({DateTime? since, CardScope? scope});

  /// Same meaning as [LibraryRepository.transaction].
  Future<T> transaction<T>(Future<T> Function() action);
}
