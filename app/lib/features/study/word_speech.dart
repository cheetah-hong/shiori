import 'package:shiori/features/study/pitch_line.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

/// The word's speech request: the first reading [table] has accents for,
/// else the first reading (the written form when there is none).
WordSpeech wordSpeechFor(Word word, AccentTable table) {
  final readings = word.readings.isEmpty ? [word.headword] : word.readings;
  for (final reading in readings) {
    final accents = table.lookup(word.headword, reading);
    if (accents.isNotEmpty) {
      return WordSpeech(
        headword: word.headword,
        reading: reading,
        accents: accents,
        pos: word.pos,
      );
    }
  }
  return WordSpeech(
    headword: word.headword,
    reading: readings.first,
    pos: word.pos,
  );
}

/// The example's speech request: the page example, else [filled] (a
/// sentence of the word's dictionary entry), the same request either way;
/// null when there is neither.
SentenceSpeech? exampleSpeechFor(
  Word word,
  AccentTable table, {
  CardExample? filled,
}) => switch (word.example?.ja ?? filled?.ja) {
  final String text => SentenceSpeech(
    text: text,
    word: wordSpeechFor(word, table),
  ),
  null => null,
};

/// The pitch line of [speech]; null when its reading is not kana.
PitchInfo? pitchInfoFor(WordSpeech speech) {
  if (pronunciationMorae(speech.reading, pos: speech.pos) == null) return null;
  return PitchInfo(
    morae: splitMorae(speech.reading),
    accent: speech.accents.firstOrNull,
    estimated: speech.isEstimated,
  );
}
