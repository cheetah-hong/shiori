import 'package:shiori_core/shiori_core.dart';

/// Hands every call to an in-memory library, so a test fake overrides only
/// the call it changes (a failing write, a counted read).
class ForwardingLibrary implements LibraryRepository, HiddenWordRepository {
  final inner = InMemoryLibraryRepository();

  @override
  Future<List<Word>> words({String? playlistId}) =>
      inner.words(playlistId: playlistId);

  @override
  Future<Word?> word(String id) => inner.word(id);

  @override
  Future<Map<String, Word>> wordsByKey(Iterable<String> keys) =>
      inner.wordsByKey(keys);

  @override
  Future<void> insertWords(List<Word> words) => inner.insertWords(words);

  @override
  Future<List<Playlist>> playlists() => inner.playlists();

  @override
  Future<Playlist?> playlist(String id) => inner.playlist(id);

  @override
  Future<void> savePlaylist(Playlist playlist) => inner.savePlaylist(playlist);

  @override
  Future<void> deletePlaylist(String id) => inner.deletePlaylist(id);

  @override
  Future<List<PlaylistStats>> playlistStats() => inner.playlistStats();

  @override
  Future<void> addToPlaylist(
    String playlistId,
    List<String> wordIds, {
    required DateTime at,
  }) => inner.addToPlaylist(playlistId, wordIds, at: at);

  @override
  Future<List<PlaylistEntry>> removeFromPlaylist(
    String playlistId,
    Iterable<String> wordIds,
  ) => inner.removeFromPlaylist(playlistId, wordIds);

  @override
  Future<void> restoreEntries(List<PlaylistEntry> entries) =>
      inner.restoreEntries(entries);

  @override
  Future<Map<String, Set<String>>> playlistsOf(Iterable<String> wordIds) =>
      inner.playlistsOf(wordIds);

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      inner.transaction(action);

  @override
  Future<void> hideWords(Iterable<String> wordIds, {required DateTime at}) =>
      inner.hideWords(wordIds, at: at);

  @override
  Future<void> unhideWords(Iterable<String> wordIds) =>
      inner.unhideWords(wordIds);

  @override
  Future<List<Word>> hiddenWords({String? playlistId}) =>
      inner.hiddenWords(playlistId: playlistId);
}
