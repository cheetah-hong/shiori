import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/ports/hidden_word_repository.dart';
import 'package:shiori_core/src/ports/repositories.dart';
import 'package:shiori_core/src/storage/in_memory_transactions.dart';

typedef _LibraryState = (
  Map<String, Word>,
  Map<String, Playlist>,
  List<PlaylistEntry>,
);

/// Keeps the library in memory (lost when the app quits). Used by tests;
/// the app stores it in SQLite (`packages/storage_drift`).
///
/// Unlike the SQLite block it does not tie cards to words (the review block
/// is separate here).
final class InMemoryLibraryRepository
    implements LibraryRepository, HiddenWordRepository {
  final Map<String, Word> _words = {};
  final Map<String, Playlist> _playlists = {};
  final List<PlaylistEntry> _entries = [];

  late final _tx = InMemoryTransactions<_LibraryState>(
    snapshot: () => (Map.of(_words), Map.of(_playlists), List.of(_entries)),
    restore: (state) {
      final (words, playlists, entries) = state;
      _words
        ..clear()
        ..addAll(words);
      _playlists
        ..clear()
        ..addAll(playlists);
      _entries
        ..clear()
        ..addAll(entries);
    },
  );

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _tx.transaction(action);

  @override
  Future<List<Word>> words({String? playlistId}) =>
      _tx.run(() => _wordsOf(playlistId));

  List<Word> _wordsOf(String? playlistId) {
    if (playlistId != null) {
      final inList = _entriesOf(playlistId);
      return List.unmodifiable([for (final e in inList) _words[e.wordId]!]);
    }
    final listed = {for (final e in _entries) e.wordId};
    return List.unmodifiable(
      _byAge(_words.values.where((w) => listed.contains(w.id))),
    );
  }

  @override
  Future<Word?> word(String id) => _tx.run(() => _words[id]);

  @override
  Future<Map<String, Word>> wordsByKey(Iterable<String> keys) => _tx.run(() {
    final wanted = keys.toSet();
    return Map<String, Word>.unmodifiable({
      for (final w in _words.values)
        if (wanted.contains(w.key)) w.key: w,
    });
  });

  @override
  Future<void> insertWords(List<Word> words) => _tx.run(() {
    final taken = {for (final w in _words.values) w.key};
    final ids = _words.keys.toSet();
    final clashes = <String>[];
    for (final w in words) {
      if (!taken.add(w.key) || !ids.add(w.id)) clashes.add(w.key);
    }
    if (clashes.isNotEmpty) throw DuplicateWordException(clashes);
    for (final w in words) {
      _words[w.id] = w.withHiddenAt(null);
    }
  });

  @override
  Future<void> updateWord(Word word) => _tx.run(() {
    final stored = _words[word.id];
    if (stored == null) throw WordNotFoundException([word.id]);
    if (_words.values.any((w) => w.key == word.key && w.id != word.id)) {
      throw DuplicateWordException([word.key]);
    }
    _words[word.id] = Word(
      id: word.id,
      headword: word.headword,
      readings: List.unmodifiable(word.readings),
      pos: word.pos,
      meaning: word.meaning,
      example: word.example,
      createdAt: stored.createdAt,
      hiddenAt: stored.hiddenAt,
    );
  });

  @override
  Future<List<Playlist>> playlists() =>
      _tx.run(() => List<Playlist>.unmodifiable(_sortedPlaylists()));

  @override
  Future<Playlist?> playlist(String id) => _tx.run(() => _playlists[id]);

  @override
  Future<void> savePlaylist(Playlist playlist) =>
      _tx.run(() => _playlists[playlist.id] = playlist);

  @override
  Future<void> deletePlaylist(String id) => _tx.run(() {
    _playlists.remove(id);
    _entries.removeWhere((e) => e.playlistId == id);
  });

  @override
  Future<List<PlaylistStats>> playlistStats() => _tx.run(
    () => List<PlaylistStats>.unmodifiable([
      for (final p in _sortedPlaylists()) _stats(p),
    ]),
  );

  PlaylistStats _stats(Playlist p) {
    final inList = _entriesOf(p.id);
    DateTime? last;
    for (final e in inList) {
      if (last == null || e.addedAt.isAfter(last)) last = e.addedAt;
    }
    return PlaylistStats(
      playlist: p,
      wordCount: inList.length,
      hiddenCount: inList.where((e) => _words[e.wordId]!.isHidden).length,
      lastAddedAt: last,
    );
  }

  @override
  Future<void> addToPlaylist(
    String playlistId,
    List<String> wordIds, {
    required DateTime at,
  }) => _tx.run(() {
    if (!_playlists.containsKey(playlistId)) {
      throw PlaylistNotFoundException(playlistId);
    }
    final missing = [
      for (final id in wordIds.toSet())
        if (!_words.containsKey(id)) id,
    ];
    if (missing.isNotEmpty) throw WordNotFoundException(missing);
    final inList = _entriesOf(playlistId);
    final present = {for (final e in inList) e.wordId};
    var next = inList.isEmpty ? 0 : inList.last.position + 1;
    for (final id in wordIds) {
      if (!present.add(id)) continue;
      _entries.add(
        PlaylistEntry(
          playlistId: playlistId,
          wordId: id,
          position: next++,
          addedAt: at,
        ),
      );
    }
  });

  @override
  Future<List<PlaylistEntry>> removeFromPlaylist(
    String playlistId,
    Iterable<String> wordIds,
  ) => _tx.run(() {
    final ids = wordIds.toSet();
    final removed = [
      for (final e in _entriesOf(playlistId))
        if (ids.contains(e.wordId)) e,
    ];
    _entries.removeWhere(removed.contains);
    return List<PlaylistEntry>.unmodifiable(removed);
  });

  @override
  Future<void> restoreEntries(List<PlaylistEntry> entries) => _tx.run(() {
    for (final e in entries) {
      final present = _entries.any(
        (x) => x.playlistId == e.playlistId && x.wordId == e.wordId,
      );
      if (present ||
          !_playlists.containsKey(e.playlistId) ||
          !_words.containsKey(e.wordId)) {
        continue;
      }
      _entries.add(e);
    }
  });

  @override
  Future<Map<String, Set<String>>> playlistsOf(Iterable<String> wordIds) =>
      _tx.run(() {
        final ids = wordIds.toSet();
        final of = <String, Set<String>>{};
        for (final e in _entries) {
          if (ids.contains(e.wordId)) (of[e.wordId] ??= {}).add(e.playlistId);
        }
        return Map<String, Set<String>>.unmodifiable({
          for (final MapEntry(:key, :value) in of.entries)
            key: Set<String>.unmodifiable(value),
        });
      });

  @override
  Future<void> hideWords(Iterable<String> wordIds, {required DateTime at}) =>
      _tx.run(() {
        for (final w in _known(wordIds)) {
          if (!w.isHidden) _words[w.id] = w.withHiddenAt(at);
        }
      });

  @override
  Future<void> unhideWords(Iterable<String> wordIds) => _tx.run(() {
    for (final w in _known(wordIds)) {
      if (w.isHidden) _words[w.id] = w.withHiddenAt(null);
    }
  });

  @override
  Future<List<Word>> hiddenWords({String? playlistId}) => _tx.run(() {
    final from = playlistId == null
        ? _byAge(_words.values)
        : _wordsOf(playlistId);
    return List<Word>.unmodifiable(from.where((w) => w.isHidden));
  });

  /// The words of [wordIds], each once; throws before any write when one is
  /// not in the library.
  List<Word> _known(Iterable<String> wordIds) {
    final ids = wordIds.toSet();
    final missing = [
      for (final id in ids)
        if (!_words.containsKey(id)) id,
    ];
    if (missing.isNotEmpty) throw WordNotFoundException(missing);
    return [for (final id in ids) _words[id]!];
  }

  /// The entries of [playlistId] in its order (a place shared after an
  /// undo: the earlier added first, as in the SQLite block).
  List<PlaylistEntry> _entriesOf(String playlistId) =>
      _entries.where((e) => e.playlistId == playlistId).toList()..sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        if (byPosition != 0) return byPosition;
        final byTime = a.addedAt.compareTo(b.addedAt);
        return byTime != 0 ? byTime : a.wordId.compareTo(b.wordId);
      });

  List<Playlist> _sortedPlaylists() => _playlists.values.toList()
    ..sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      if (byPosition != 0) return byPosition;
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
}

/// Oldest first, then by id (the order of `LibraryRepository.words`).
List<Word> _byAge(Iterable<Word> words) => words.toList()
  ..sort((a, b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
