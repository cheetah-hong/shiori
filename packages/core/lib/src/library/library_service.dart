import 'package:shiori_core/src/decks/deck_draft.dart';
import 'package:shiori_core/src/library/word_edit.dart';
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

  /// Adds [deck]'s words to the playlist named like the deck (the same name
  /// under [playlistNameKey]), made when there is none, by [addDraft]'s
  /// rules: adding a deck again adds only the words it is missing.
  Future<AddResult> addDeck(DeckDraft deck) async {
    final key = playlistNameKey(deck.deck.name);
    final same = [
      for (final p in await library.playlists())
        if (playlistNameKey(p.name) == key) p,
    ];
    return addDraft(
      deck.draft,
      to: same.isEmpty
          ? NewPlaylist(deck.deck.name)
          : ExistingPlaylist(same.first.id),
    );
  }

  /// Adds library words to the playlist [to] (다른 목록에 추가).
  Future<AddResult> addWords(List<String> wordIds, {required AddTarget to}) =>
      library.transaction(() async {
        final playlist = await _target(to);
        return _link(playlist, wordIds, clock.now(), isNew: const {});
      });

  /// Adds one word the learner typed (단어 추가) to the playlist [to], by
  /// [addDraft]'s rules: a word whose key the library has is linked, not
  /// made again. Throws [LibraryException] for a blank or non-Japanese
  /// headword or a blank meaning.
  Future<AddResult> addWord(WordEdit word, {required AddTarget to}) async {
    final clean = _checked(word);
    return addDraft(CaptureDraft(entries: [clean.toEntry()]), to: to);
  }

  /// Changes the content of word [wordId] (단어 고치기): every playlist that
  /// holds it shows the change; its learning state and hidden state stay.
  ///
  /// Throws [LibraryException] for a blank or non-Japanese headword, a blank
  /// meaning or an unknown id, and [WordKeyTakenException] when another
  /// word has the key the headword now makes; nothing is written then.
  Future<WordEdited> editWord(String wordId, WordEdit edit) async {
    final clean = _checked(edit);
    return library.transaction(() async {
      final before = await _word(wordId);
      final after = Word(
        id: before.id,
        headword: clean.headword,
        readings: clean.readings,
        pos: clean.pos,
        meaning: clean.meaning,
        example: clean.example,
        createdAt: before.createdAt,
        hiddenAt: before.hiddenAt,
      );
      await _update(after);
      return WordEdited(before: before, after: after);
    });
  }

  /// Puts the word back as it was before [edited]. Throws
  /// [WordKeyTakenException] when another word took its key meanwhile.
  Future<void> undoEdit(WordEdited edited) =>
      library.transaction(() => _update(edited.before));

  /// 저장된 단어로 바꾸기: in every playlist that holds [wordId], the
  /// library word [existingId] takes its place (same position and time; a
  /// playlist holding both just loses [wordId]). [wordId] stays in the
  /// library, in no playlist, with its learning state. One transaction.
  Future<Replacement> replaceWithExisting(String wordId, String existingId) =>
      library.transaction(() async {
        await _word(wordId);
        await _word(existingId);
        final of = await library.playlistsOf([wordId, existingId]);
        final lists = of[wordId] ?? const <String>{};
        final holding = of[existingId] ?? const <String>{};
        final removed = <PlaylistEntry>[];
        final linked = <PlaylistEntry>[];
        for (final p in await library.playlists()) {
          if (!lists.contains(p.id)) continue;
          final out = await library.removeFromPlaylist(p.id, [wordId]);
          removed.addAll(out);
          if (holding.contains(p.id)) continue;
          final entries = [
            for (final e in out)
              PlaylistEntry(
                playlistId: e.playlistId,
                wordId: existingId,
                position: e.position,
                addedAt: e.addedAt,
              ),
          ];
          await library.restoreEntries(entries);
          linked.addAll(entries);
        }
        return Replacement(
          wordId: wordId,
          existingId: existingId,
          removed: List.unmodifiable(removed),
          linked: List.unmodifiable(linked),
        );
      });

  /// Undoes [replaceWithExisting]: [Replacement.linked] taken out, the word
  /// back at its places.
  Future<void> undoReplace(Replacement replacement) =>
      library.transaction(() async {
        for (final e in replacement.linked) {
          await library.removeFromPlaylist(e.playlistId, [e.wordId]);
        }
        await library.restoreEntries(replacement.removed);
      });

  /// [edit] trimmed, when its headword and meaning can be saved.
  WordEdit _checked(WordEdit edit) {
    final clean = edit.trimmed;
    final problem =
        headwordProblem(clean.headword) ?? meaningProblem(clean.meaning);
    if (problem != null) throw LibraryException(problem);
    return clean;
  }

  Future<Word> _word(String id) async =>
      await library.word(id) ?? (throw const LibraryException('단어를 찾지 못했어요'));

  /// Stores [word]'s content, or throws [WordKeyTakenException] with the
  /// word that has its key (found by the service's own check, or by the
  /// repository's when a write landed in between).
  Future<void> _update(Word word) async {
    final holder = await _holderOf(word);
    if (holder != null) throw WordKeyTakenException(holder);
    try {
      await library.updateWord(word);
    } on DuplicateWordException {
      throw WordKeyTakenException(
        await _holderOf(word, everyWord: true) ??
            (throw const LibraryException('같은 단어가 이미 있어요')),
      );
    }
  }

  /// Another library word with [word]'s key, if any. With [everyWord], the
  /// words listed in playlists are read too (a block's key lookup can miss
  /// a word written a moment ago).
  Future<Word?> _holderOf(Word word, {bool everyWord = false}) async {
    final byKey = (await library.wordsByKey([word.key]))[word.key];
    if (byKey != null && byKey.id != word.id) return byKey;
    if (!everyWord) return null;
    for (final w in await library.words()) {
      if (w.key == word.key && w.id != word.id) return w;
    }
    return null;
  }

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
