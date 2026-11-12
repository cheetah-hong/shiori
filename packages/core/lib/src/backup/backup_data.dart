import 'package:shiori_core/src/models/list_equality.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/models/study_mode.dart';

/// A saved word as a backup holds it: every stored field, [key] included,
/// so a restored library is the same row for row.
final class BackupWord {
  BackupWord({
    required this.id,
    required this.key,
    required this.headword,
    required List<String> readings,
    required this.meaning,
    required this.createdAt,
    this.pos,
    this.exampleJa,
    this.exampleKo,
    this.hiddenAt,
  }) : readings = List.unmodifiable(readings);

  final String id;
  final String key;
  final String headword;
  final List<String> readings;
  final PartOfSpeech? pos;
  final String meaning;

  /// The example sentence and its translation: both or neither.
  final String? exampleJa;
  final String? exampleKo;
  final DateTime createdAt;

  /// When the learner hid the word (이미 알아요); null while it is shown.
  final DateTime? hiddenAt;

  @override
  bool operator ==(Object other) =>
      other is BackupWord &&
      other.id == id &&
      other.key == key &&
      other.headword == headword &&
      listEquals(other.readings, readings) &&
      other.pos == pos &&
      other.meaning == meaning &&
      other.exampleJa == exampleJa &&
      other.exampleKo == exampleKo &&
      other.createdAt == createdAt &&
      other.hiddenAt == hiddenAt;

  @override
  int get hashCode => Object.hash(
    id,
    key,
    headword,
    Object.hashAll(readings),
    pos,
    meaning,
    exampleJa,
    exampleKo,
    createdAt,
    hiddenAt,
  );

  @override
  String toString() => 'BackupWord($id $headword)';
}

/// A playlist as a backup holds it.
final class BackupPlaylist {
  const BackupPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.position,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int position;

  @override
  bool operator ==(Object other) =>
      other is BackupPlaylist &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.position == position;

  @override
  int get hashCode => Object.hash(id, name, createdAt, position);

  @override
  String toString() => 'BackupPlaylist($id $name)';
}

/// One word in one playlist, as a backup holds it.
final class BackupPlaylistWord {
  const BackupPlaylistWord({
    required this.playlistId,
    required this.wordId,
    required this.position,
    required this.addedAt,
  });

  final String playlistId;
  final String wordId;
  final int position;
  final DateTime addedAt;

  @override
  bool operator ==(Object other) =>
      other is BackupPlaylistWord &&
      other.playlistId == playlistId &&
      other.wordId == wordId &&
      other.position == position &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(playlistId, wordId, position, addedAt);

  @override
  String toString() => 'BackupPlaylistWord($playlistId $wordId)';
}

/// One button press as a backup holds it: a `ReviewLog` with its place in
/// the log ([id], in the order presses were made).
final class BackupLog {
  const BackupLog({
    required this.id,
    required this.wordId,
    required this.answer,
    required this.at,
    required this.levelBefore,
    required this.levelAfter,
    required this.retriesInSession,
    this.scope = CardScope.shared,
    this.mode = StudyMode.meaning,
  });

  final int id;
  final CardScope scope;
  final StudyMode mode;

  /// The word pressed on. History: it may name a word the library no longer
  /// holds.
  final String wordId;
  final Answer answer;
  final DateTime at;
  final int levelBefore;
  final int levelAfter;
  final int retriesInSession;

  @override
  bool operator ==(Object other) =>
      other is BackupLog &&
      other.id == id &&
      other.scope == scope &&
      other.mode == mode &&
      other.wordId == wordId &&
      other.answer == answer &&
      other.at == at &&
      other.levelBefore == levelBefore &&
      other.levelAfter == levelAfter &&
      other.retriesInSession == retriesInSession;

  @override
  int get hashCode => Object.hash(
    id,
    scope,
    mode,
    wordId,
    answer,
    at,
    levelBefore,
    levelAfter,
    retriesInSession,
  );

  @override
  String toString() => 'BackupLog($id $wordId ${answer.name})';
}

/// Everything a backup holds: the library, the learning state and the
/// study options. Photos, OCR passes, dictionaries and voices are not part
/// of it (they ship with the app or can be made again).
final class BackupData {
  BackupData({
    List<BackupWord> words = const [],
    List<BackupPlaylist> playlists = const [],
    List<BackupPlaylistWord> playlistWords = const [],
    List<ReviewCard> cards = const [],
    List<BackupLog> logs = const [],
    Map<String, String> settings = const {},
  }) : words = List.unmodifiable(words),
       playlists = List.unmodifiable(playlists),
       playlistWords = List.unmodifiable(playlistWords),
       cards = List.unmodifiable(cards),
       logs = List.unmodifiable(logs),
       settings = Map.unmodifiable(settings);

  final List<BackupWord> words;
  final List<BackupPlaylist> playlists;
  final List<BackupPlaylistWord> playlistWords;
  final List<ReviewCard> cards;
  final List<BackupLog> logs;

  /// The study options as stored (key → value; see `StudySettingKeys`).
  final Map<String, String> settings;

  /// No word, playlist, card or press (the study options do not count): a
  /// fresh install, with nothing a restore could lose.
  bool get isEmpty =>
      words.isEmpty &&
      playlists.isEmpty &&
      playlistWords.isEmpty &&
      cards.isEmpty &&
      logs.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is BackupData &&
      listEquals(other.words, words) &&
      listEquals(other.playlists, playlists) &&
      listEquals(other.playlistWords, playlistWords) &&
      listEquals(other.cards, cards) &&
      listEquals(other.logs, logs) &&
      _mapEquals(other.settings, settings);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(words),
    Object.hashAll(playlists),
    Object.hashAll(playlistWords),
    Object.hashAll(cards),
    Object.hashAll(logs),
    Object.hashAllUnordered(settings.entries.map((e) => '${e.key}=${e.value}')),
  );

  @override
  String toString() =>
      'BackupData(${words.length} words, ${playlists.length} playlists, '
      '${playlistWords.length} entries, ${cards.length} cards, '
      '${logs.length} presses, ${settings.length} settings)';
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length &&
    a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);
