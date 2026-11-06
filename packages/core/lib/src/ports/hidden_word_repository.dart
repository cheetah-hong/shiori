import 'package:shiori_core/src/models/library.dart';

/// A word id that is not in the library. Hiding and showing never skip an
/// unknown id silently.
final class WordNotFoundException implements Exception {
  const WordNotFoundException(this.wordIds);

  /// The ids that were not found, in the order they were asked for.
  final List<String> wordIds;

  @override
  String toString() => 'WordNotFoundException: ${wordIds.join(', ')}';
}

/// Block slot: hiding words the learner already knows (이미 알아요), and
/// showing them again.
///
/// The hidden state lives with the word (`Word.hiddenAt`), so
/// `LibraryRepository.words` keeps returning hidden words and tells them
/// apart by that field. Hiding is per word, whatever playlists hold it. Hiding never touches the word's review card or log:
/// a word shown again goes on from the state it had.
///
/// Kept apart from `LibraryRepository` so that a library block can be
/// swapped without it. Blocks: `InMemoryLibraryRepository` (tests),
/// `DriftLibraryRepository` (app); both implement the two slots on one store.
abstract interface class HiddenWordRepository {
  /// Hides every word in [wordIds] since [at], all or none.
  ///
  /// A word already hidden keeps the time it was first hidden. Throws
  /// [WordNotFoundException] (and hides nothing) when an id is unknown.
  Future<void> hideWords(Iterable<String> wordIds, {required DateTime at});

  /// Shows every word in [wordIds] again, all or none. A word that is not
  /// hidden stays as it is. Throws [WordNotFoundException] (and changes
  /// nothing) when an id is unknown.
  Future<void> unhideWords(Iterable<String> wordIds);

  /// The hidden words of playlist [playlistId] in its order, or (null)
  /// every hidden word in the library, also ones in no playlist (hiding is
  /// per word: the word capture leaves them all out).
  Future<List<Word>> hiddenWords({String? playlistId});
}
