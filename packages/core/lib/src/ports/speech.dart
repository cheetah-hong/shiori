import 'package:shiori_core/src/models/part_of_speech.dart';

/// Block slot (optional): reads Japanese aloud.
///
/// Blocks: [SilentSpeech] (the card hides the speaker buttons) and the
/// on-device VOICEVOX block in the app.
abstract interface class Speech {
  bool get isAvailable;

  /// Plays [request] from the start; a sound still playing is stopped first.
  /// Completes when playback has started. Throws [SpeechFailure] when the
  /// sound cannot be made or played.
  Future<void> speak(SpeechRequest request);

  /// Stops what is playing (nothing happens when nothing is).
  Future<void> stop();
}

/// What to read aloud.
sealed class SpeechRequest {
  const SpeechRequest();
}

/// One word: its written form, its reading (hiragana or katakana) and its
/// pitch accent(s) from accent data. Accent n means the pitch falls after the
/// n-th mora, 0 means it does not fall (flat).
final class WordSpeech extends SpeechRequest {
  const WordSpeech({
    required this.headword,
    required this.reading,
    this.accents = const [],
    this.pos,
  });

  final String headword;
  final String reading;

  /// Part of speech when known: a verb keeps its final う as a vowel
  /// (思う is おもう, not おもー) when the reading is turned into sounds.
  final PartOfSpeech? pos;

  /// Values from the accent data, first one first; empty when the data has
  /// none for this (headword, reading).
  final List<int> accents;

  /// No accent data: the engine guesses the accent, and the screen says so.
  bool get isEstimated => accents.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is WordSpeech &&
      other.headword == headword &&
      other.reading == reading &&
      other.pos == pos &&
      _sameList(other.accents, accents);

  @override
  int get hashCode =>
      Object.hash(headword, reading, pos, Object.hashAll(accents));

  @override
  String toString() => 'WordSpeech($headword, $reading, $accents)';
}

/// An example sentence; [word] is the card's word, whose accent is kept as
/// the accent data gives it wherever the sentence says it.
final class SentenceSpeech extends SpeechRequest {
  const SentenceSpeech({required this.text, required this.word});

  final String text;
  final WordSpeech word;

  @override
  bool operator ==(Object other) =>
      other is SentenceSpeech && other.text == text && other.word == word;

  @override
  int get hashCode => Object.hash(text, word);

  @override
  String toString() => 'SentenceSpeech($text, $word)';
}

/// The sound could not be made or played; [message] is for the learner.
final class SpeechFailure implements Exception {
  const SpeechFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'SpeechFailure: $message'
      : 'SpeechFailure: $message ($cause)';
}

final class SilentSpeech implements Speech {
  const SilentSpeech();

  @override
  bool get isAvailable => false;

  @override
  Future<void> speak(SpeechRequest request) async {}

  @override
  Future<void> stop() async {}
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
