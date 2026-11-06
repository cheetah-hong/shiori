import 'dart:typed_data';

import 'package:voicevox_block/src/accent_phrase.dart';

/// The VOICEVOX engine operations the block uses. The app binds them to the
/// core C API; tests use a fake. Every call may throw when the engine fails.
abstract interface class VoicevoxOps {
  /// Engine, model and voice (style) in one string: part of each cache key,
  /// so a new voice never plays an old sound.
  String get voiceId;

  /// Phrases of VOICEVOX kana (`ハ'シ`), pitches made.
  Future<List<AccentPhrase>> phrasesFromKana(String kana);

  /// Phrases of Japanese text, as the engine reads and accents it.
  Future<List<AccentPhrase>> phrasesFromText(String text);

  /// The same phrases with pitches made again (after an accent changed).
  Future<List<AccentPhrase>> replaceMoraPitch(List<AccentPhrase> phrases);

  /// WAV of [phrases].
  Future<Uint8List> synthesize(List<AccentPhrase> phrases);
}
