import 'package:shiori_core/src/capture/text/chars.dart' show nfkc;
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/list_equality.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/models/word_key.dart';

/// A saved word (content), once in the library however many playlists hold
/// it. Its learning state lives in a separate `ReviewCard`.
///
/// [key] (from the headword, `wordKey`) is what makes two words the same:
/// the library holds one word per key.
///
/// [hiddenAt] is set when the learner hid the word as one they already know
/// (이미 알아요). Hiding is per word, not per playlist: a hidden word stays in
/// its playlists and keeps its card; only study sessions and the word lists
/// leave it out.
final class Word {
  Word({
    required this.id,
    required this.headword,
    required this.readings,
    required this.meaning,
    required this.createdAt,
    this.pos,
    this.example,
    this.hiddenAt,
  }) : key = wordKey(headword);

  final String id;
  final String key;
  final String headword;
  final List<String> readings;
  final PartOfSpeech? pos;
  final String meaning;
  final Example? example;
  final DateTime createdAt;

  /// When the learner hid the word; null while it is shown.
  ///
  /// Only `HiddenWordRepository` changes it: `LibraryRepository.insertWords`
  /// stores a new word shown.
  final DateTime? hiddenAt;

  bool get isHidden => hiddenAt != null;

  /// The same word, hidden since [at] (null: shown).
  Word withHiddenAt(DateTime? at) => Word(
    id: id,
    headword: headword,
    readings: readings,
    meaning: meaning,
    createdAt: createdAt,
    pos: pos,
    example: example,
    hiddenAt: at,
  );

  @override
  bool operator ==(Object other) =>
      other is Word &&
      other.id == id &&
      other.headword == headword &&
      listEquals(other.readings, readings) &&
      other.pos == pos &&
      other.meaning == meaning &&
      other.example == example &&
      other.createdAt == createdAt &&
      other.hiddenAt == hiddenAt;

  @override
  int get hashCode => Object.hash(
    id,
    headword,
    Object.hashAll(readings),
    pos,
    meaning,
    example,
    createdAt,
    hiddenAt,
  );

  @override
  String toString() => 'Word($id $headword${isHidden ? ' hidden' : ''})';
}

/// A list of words the learner made (like a music playlist). It points at
/// library words; the same word can be in several playlists.
final class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.position,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// Place on the home screen and the playlist list, from 0.
  final int position;

  Playlist copyWith({String? name, int? position}) => Playlist(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    position: position ?? this.position,
  );

  @override
  bool operator ==(Object other) =>
      other is Playlist &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.position == position;

  @override
  int get hashCode => Object.hash(id, name, createdAt, position);

  @override
  String toString() => 'Playlist($id $name @$position)';
}

/// What makes two playlist names the same: spaces around them, letter case
/// and NFKC width do not count.
String playlistNameKey(String name) => nfkc(name.trim()).toLowerCase();

/// One word's place in one playlist.
final class PlaylistEntry {
  const PlaylistEntry({
    required this.playlistId,
    required this.wordId,
    required this.position,
    required this.addedAt,
  });

  final String playlistId;
  final String wordId;

  /// Order inside the playlist (words added later come after).
  final int position;
  final DateTime addedAt;

  @override
  bool operator ==(Object other) =>
      other is PlaylistEntry &&
      other.playlistId == playlistId &&
      other.wordId == wordId &&
      other.position == position &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(playlistId, wordId, position, addedAt);

  @override
  String toString() => 'PlaylistEntry($playlistId $wordId @$position)';
}

/// A playlist with how many words it holds, for the home screen and the
/// playlist picker, in one read.
///
/// [wordCount] covers every word of the playlist, hidden ones too;
/// [hiddenCount] says how many of them are hidden. [lastAddedAt] is when a
/// word was last added (null while the playlist is empty).
final class PlaylistStats {
  const PlaylistStats({
    required this.playlist,
    required this.wordCount,
    this.hiddenCount = 0,
    this.lastAddedAt,
  });

  final Playlist playlist;
  final int wordCount;
  final int hiddenCount;
  final DateTime? lastAddedAt;

  int get shownCount => wordCount - hiddenCount;

  @override
  bool operator ==(Object other) =>
      other is PlaylistStats &&
      other.playlist == playlist &&
      other.wordCount == wordCount &&
      other.hiddenCount == hiddenCount &&
      other.lastAddedAt == lastAddedAt;

  @override
  int get hashCode =>
      Object.hash(playlist, wordCount, hiddenCount, lastAddedAt);

  @override
  String toString() =>
      'PlaylistStats(${playlist.id}, words: $wordCount, '
      'hidden: $hiddenCount, last: $lastAddedAt)';
}
