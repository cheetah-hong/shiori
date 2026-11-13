import 'package:shiori_core/src/capture/text/chars.dart' show nfkc;
import 'package:shiori_core/src/extract/script_runs.dart' show isKana, isKanji;
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/models/list_equality.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';

/// What the learner can change in a saved word (단어 고치기, 단어 추가):
/// everything but its id, creation time and hidden state.
final class WordEdit {
  const WordEdit({
    required this.headword,
    this.readings = const [],
    this.pos,
    required this.meaning,
    this.example,
  });

  /// The content [word] has now.
  factory WordEdit.of(Word word) => WordEdit(
    headword: word.headword,
    readings: word.readings,
    pos: word.pos,
    meaning: word.meaning,
    example: word.example,
  );

  final String headword;

  /// Readings in kana; empty for a word written in kana.
  final List<String> readings;
  final PartOfSpeech? pos;
  final String meaning;

  /// The example read from the page with the word, if it kept one.
  final Example? example;

  /// Spaces around each field taken off, empty readings left out.
  WordEdit get trimmed => WordEdit(
    headword: headword.trim(),
    readings: List.unmodifiable([
      for (final r in readings)
        if (r.trim().isNotEmpty) r.trim(),
    ]),
    pos: pos,
    meaning: meaning.trim(),
    example: example,
  );

  /// As a review-draft entry, to add with `LibraryService.addDraft`.
  CapturedEntry toEntry() => CapturedEntry(
    headword: headword,
    readings: readings,
    pos: pos,
    meaning: meaning,
    example: example,
  );

  @override
  bool operator ==(Object other) =>
      other is WordEdit &&
      other.headword == headword &&
      listEquals(other.readings, readings) &&
      other.pos == pos &&
      other.meaning == meaning &&
      other.example == example;

  @override
  int get hashCode =>
      Object.hash(headword, Object.hashAll(readings), pos, meaning, example);

  @override
  String toString() =>
      'WordEdit($headword|${readings.join('/')}|${pos?.badge}|$meaning)';
}

/// What is wrong with [headword] as a word's headword (null: nothing): it is
/// blank, or has no kana or kanji (a word is written in Japanese).
String? headwordProblem(String headword) {
  final clean = nfkc(headword.trim());
  if (clean.isEmpty) return '표제어를 써 주세요';
  if (!clean.runes.any((c) => isKana(c) || isKanji(c))) {
    return '표제어는 가나나 한자로 써 주세요';
  }
  return null;
}

/// What is wrong with [meaning] as a word's meaning (null: nothing).
String? meaningProblem(String meaning) =>
    meaning.trim().isEmpty ? '뜻을 써 주세요' : null;

/// Another library word already has the key the headword was changed to
/// (the library holds one word per key). Nothing was written.
final class WordKeyTakenException implements Exception {
  const WordKeyTakenException(this.existing);

  /// The word that has the key.
  final Word existing;

  @override
  String toString() => 'WordKeyTakenException: ${existing.key}';
}

/// A word before and after the learner changed it (to undo the change).
final class WordEdited {
  const WordEdited({required this.before, required this.after});

  final Word before;
  final Word after;

  /// The headword now names another word (`Word.key`).
  bool get keyChanged => before.key != after.key;
}

/// What 「저장된 단어로 바꾸기」 did: in every playlist that held [wordId],
/// [existingId] took its place (or was there already). To undo it.
final class Replacement {
  const Replacement({
    required this.wordId,
    required this.existingId,
    required this.removed,
    required this.linked,
  });

  /// The word the learner was changing; it stays in the library, in no
  /// playlist, with its learning state.
  final String wordId;

  /// The library word with the key the learner asked for.
  final String existingId;

  /// [wordId]'s entries taken out, as they were.
  final List<PlaylistEntry> removed;

  /// [existingId]'s entries put in at those places (none where it was in
  /// the playlist already).
  final List<PlaylistEntry> linked;

  /// How many playlists held [wordId].
  int get playlistCount => removed.length;
}
