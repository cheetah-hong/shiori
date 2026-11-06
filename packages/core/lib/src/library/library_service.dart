import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/models/word_key.dart';
import 'package:shiori_core/src/ports/clock.dart';
import 'package:shiori_core/src/ports/hidden_word_repository.dart';
import 'package:shiori_core/src/ports/repositories.dart';

/// A library request the learner can fix (empty name, playlist gone).
final class LibraryException implements Exception {
  const LibraryException(this.message);

  /// Shown to the learner as is.
  final String message;

  @override
  String toString() => 'LibraryException: $message';
}

/// The name a new playlist starts with.
const String defaultPlaylistName = '내 단어장';

/// Where reviewed words go: a playlist the learner has, or a new one.
sealed class AddTarget {
  const AddTarget();
}

final class ExistingPlaylist extends AddTarget {
  const ExistingPlaylist(this.playlistId);

  final String playlistId;
}

final class NewPlaylist extends AddTarget {
  const NewPlaylist(this.name);

  final String name;
}

/// What adding words to a playlist did.
final class AddResult {
  const AddResult({
    required this.playlist,
    required this.added,
    required this.linked,
    required this.alreadyIn,
    required this.skipped,
  });

  final Playlist playlist;

  /// New library words, now in the playlist.
  final int added;

  /// Library words (from other playlists, or in none) now in the playlist
  /// too, with their stored content and learning state.
  final int linked;

  /// Words the playlist already held (also a word twice in one draft).
  final int alreadyIn;

  /// Entries left out by the learner or without a headword.
  final int skipped;

  /// Words that went into the playlist.
  int get total => added + linked;
}

/// Before adding: which words the library already has, and how many of
/// them each playlist already holds.
final class AddPreview {
  const AddPreview({required this.libraryKeys, required this.alreadyIn});

  /// `Word.key`s (of the headwords asked about) already in the library.
  final Set<String> libraryKeys;

  /// Playlist id → how many of the headwords asked about it holds.
  final Map<String, int> alreadyIn;

  int alreadyInFor(String playlistId) => alreadyIn[playlistId] ?? 0;
}

/// One playlist with its words, for the playlist screen.
final class PlaylistView {
  const PlaylistView({required this.playlist, required this.words});

  final Playlist playlist;

  /// Every word in the playlist's order, hidden ones too.
  final List<Word> words;

  List<Word> get shownWords =>
      List.unmodifiable(words.where((w) => !w.isHidden));

  List<Word> get hiddenWords =>
      List.unmodifiable(words.where((w) => w.isHidden));

  int get hiddenCount => words.where((w) => w.isHidden).length;

  int get shownCount => words.length - hiddenCount;
}

/// Digits of a word's position in its save (a page holds far fewer words).
const int _positionDigits = 4;

/// Library use cases: playlists, adding a reviewed draft to one, taking
/// words out, hiding words the learner already knows.
final class LibraryService {
  /// [hidden] defaults to [library] when that block also hides words (both
  /// stock blocks do).
  LibraryService({
    required this.library,
    required this.clock,
    HiddenWordRepository? hidden,
  }) : hidden =
           hidden ??
           switch (library) {
             final HiddenWordRepository h => h,
             _ => null,
           };

  final LibraryRepository library;
  final Clock clock;

  /// Where words are hidden; null when no block can.
  final HiddenWordRepository? hidden;

  /// Hides [wordIds] now (이미 알아요), in every playlist. Their cards and
  /// logs stay.
  Future<void> hideWords(Iterable<String> wordIds) =>
      _hidden.hideWords(wordIds, at: clock.now());

  /// Shows [wordIds] again.
  Future<void> unhideWords(Iterable<String> wordIds) =>
      _hidden.unhideWords(wordIds);

  HiddenWordRepository get _hidden =>
      hidden ??
      (throw StateError('no HiddenWordRepository: words cannot be hidden'));

  /// A new playlist at the end of the list. Throws [LibraryException] when
  /// [name] is blank or another playlist has the same name
  /// (`playlistNameKey`).
  Future<Playlist> createPlaylist(String name) =>
      library.transaction(() => _createPlaylist(name));

  /// Same checks as [createPlaylist]; keeping its own name is fine.
  Future<Playlist> renamePlaylist(String playlistId, String name) =>
      library.transaction(() async {
        final playlist = await _playlist(playlistId);
        final renamed = playlist.copyWith(
          name: await _freeName(name, except: playlistId),
        );
        await library.savePlaylist(renamed);
        return renamed;
      });

  /// Removes the playlist. Its words stay in the library with their
  /// learning state (a word in no playlist is not shown or studied, and
  /// comes back with its record when added again). The playlists left are
  /// numbered again from 0.
  Future<void> deletePlaylist(String playlistId) =>
      library.transaction(() async {
        await library.deletePlaylist(playlistId);
        await _renumber(await library.playlists());
      });

  /// Puts the playlists in the order of [playlistIds], which must name each
  /// playlist once ([ArgumentError] otherwise).
  Future<void> reorderPlaylists(List<String> playlistIds) =>
      library.transaction(() async {
        final byId = {for (final p in await library.playlists()) p.id: p};
        if (playlistIds.length != byId.length ||
            playlistIds.toSet().length != playlistIds.length ||
            !playlistIds.every(byId.containsKey)) {
          throw ArgumentError.value(
            playlistIds,
            'playlistIds',
            'must name every playlist once',
          );
        }
        await _renumber([for (final id in playlistIds) byId[id]!]);
      });

  /// Which of [headwords] the library has (by `Word.key`) and how many of
  /// them each playlist holds.
  Future<AddPreview> previewAdd(Iterable<String> headwords) async {
    final keys = {
      for (final h in headwords)
        if (h.trim().isNotEmpty) wordKey(h),
    };
    final found = await library.wordsByKey(keys);
    final of = await library.playlistsOf([for (final w in found.values) w.id]);
    final alreadyIn = <String, int>{};
    for (final lists in of.values) {
      for (final id in lists) {
        alreadyIn[id] = (alreadyIn[id] ?? 0) + 1;
      }
    }
    return AddPreview(
      libraryKeys: Set.unmodifiable(found.keys),
      alreadyIn: Map.unmodifiable(alreadyIn),
    );
  }

  /// Adds the included entries of [draft] to the playlist [to], in the
  /// draft's order, in one transaction (a new playlist too: if anything
  /// fails, nothing is kept).
  ///
  /// An entry whose word (`Word.key`) is in the library already is linked:
  /// the stored word keeps its content and learning state. A word the
  /// playlist holds already is skipped and counted in
  /// [AddResult.alreadyIn].
  Future<AddResult> addDraft(CaptureDraft draft, {required AddTarget to}) =>
      library.transaction(() async {
        final playlist = await _target(to);
        final now = clock.now();
        final entries = [
          for (final e in draft.entries)
            if (e.included && e.headword.trim().isNotEmpty) e,
        ];
        final skipped = draft.entries.length - entries.length;
        final found = await library.wordsByKey([
          for (final e in entries) wordKey(e.headword),
        ]);
        final stamp = await _freshStamp(now);
        final fresh = <String, Word>{};
        for (final e in entries) {
          final key = wordKey(e.headword);
          if (found.containsKey(key) || fresh.containsKey(key)) continue;
          // Numbered among the new words only, so a save that makes any
          // word makes `-0000` (what [_freshStamp] looks for).
          fresh[key] = Word(
            id: _wordId(stamp, fresh.length),
            headword: e.headword.trim(),
            readings: List.unmodifiable(e.readings),
            pos: e.pos,
            meaning: e.meaning.trim(),
            example: e.example,
            createdAt: now,
          );
        }
        await library.insertWords(fresh.values.toList());
        final ids = [
          for (final e in entries)
            (found[wordKey(e.headword)] ?? fresh[wordKey(e.headword)])!.id,
        ];
        return _link(
          playlist,
          ids,
          now,
          isNew: {for (final w in fresh.values) w.id},
          skipped: skipped,
        );
      });

  /// Adds library words to the playlist [to] (다른 목록에 추가).
  Future<AddResult> addWords(List<String> wordIds, {required AddTarget to}) =>
      library.transaction(() async {
        final playlist = await _target(to);
        return _link(playlist, wordIds, clock.now(), isNew: const {});
      });

  /// Takes [wordIds] out of the playlist; returns what to give
  /// [restoreWords] to undo.
  Future<List<PlaylistEntry>> removeWords(
    String playlistId,
    Iterable<String> wordIds,
  ) => library.removeFromPlaylist(playlistId, wordIds);

  /// Undoes [removeWords]: the words come back at their places.
  Future<void> restoreWords(List<PlaylistEntry> entries) =>
      library.restoreEntries(entries);

  Future<PlaylistView> playlistView(String playlistId) async {
    final playlist = await _playlist(playlistId);
    return PlaylistView(
      playlist: playlist,
      words: await library.words(playlistId: playlistId),
    );
  }

  /// Adds [wordIds] (in order, each once) to [playlist]; what it already
  /// holds is counted, not added.
  Future<AddResult> _link(
    Playlist playlist,
    List<String> wordIds,
    DateTime now, {
    required Set<String> isNew,
    int skipped = 0,
  }) async {
    final held = {
      for (final w in await library.words(playlistId: playlist.id)) w.id,
    };
    final toAdd = <String>[];
    var alreadyIn = 0;
    for (final id in wordIds) {
      if (held.contains(id) || toAdd.contains(id)) {
        alreadyIn++;
      } else {
        toAdd.add(id);
      }
    }
    await library.addToPlaylist(playlist.id, toAdd, at: now);
    final added = toAdd.where(isNew.contains).length;
    return AddResult(
      playlist: playlist,
      added: added,
      linked: toAdd.length - added,
      alreadyIn: alreadyIn,
      skipped: skipped,
    );
  }

  Future<Playlist> _target(AddTarget to) => switch (to) {
    ExistingPlaylist(:final playlistId) => _playlist(
      playlistId,
      missing: '재생목록을 찾지 못했어요. 다시 골라 주세요',
    ),
    NewPlaylist(:final name) => _createPlaylist(name),
  };

  Future<Playlist> _playlist(
    String id, {
    String missing = '재생목록을 찾지 못했어요',
  }) async => await library.playlist(id) ?? (throw LibraryException(missing));

  Future<Playlist> _createPlaylist(String name) async {
    final clean = await _freeName(name);
    final now = clock.now();
    final existing = await library.playlists();
    final playlist = Playlist(
      id: await _freshPlaylistId(now),
      name: clean,
      createdAt: now,
      position: existing.isEmpty ? 0 : existing.last.position + 1,
    );
    await library.savePlaylist(playlist);
    return playlist;
  }

  /// [name] trimmed, when it is not blank and no other playlist (than
  /// [except]) has it.
  Future<String> _freeName(String name, {String? except}) async {
    final clean = name.trim();
    if (clean.isEmpty) throw const LibraryException('재생목록 이름이 비어 있어요');
    final key = playlistNameKey(clean);
    for (final p in await library.playlists()) {
      if (p.id != except && playlistNameKey(p.name) == key) {
        throw const LibraryException('같은 이름의 재생목록이 있어요');
      }
    }
    return clean;
  }

  Future<void> _renumber(List<Playlist> ordered) async {
    for (final (i, p) in ordered.indexed) {
      if (p.position != i) await library.savePlaylist(p.copyWith(position: i));
    }
  }

  /// `w<stamp>-<position>`: the words of one save share their time, and the
  /// position is zero-padded so the ids sort in the draft's order (`-0010`
  /// after `-0002`).
  String _wordId(int stamp, int index) =>
      'w$stamp-${index.toString().padLeft(_positionDigits, '0')}';

  /// The save time in microseconds, moved on past any earlier save at the
  /// same instant (a clock that did not move) so no id is taken twice. A
  /// save's new words are numbered from 0, so `-0000` marks a used stamp.
  Future<int> _freshStamp(DateTime now) async {
    var stamp = now.microsecondsSinceEpoch;
    while (await library.word(_wordId(stamp, 0)) != null) {
      stamp++;
    }
    return stamp;
  }

  Future<String> _freshPlaylistId(DateTime now) async {
    final base = 'pl-${now.microsecondsSinceEpoch.toRadixString(36)}';
    var id = base;
    for (var n = 2; await library.playlist(id) != null; n++) {
      id = '$base-$n';
    }
    return id;
  }
}
