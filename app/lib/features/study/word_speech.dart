import 'package:shiori/features/study/pitch_line.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

/// The word's speech request: the first reading [table] has accents for,
/// else, for a な-adjective printed with its ending (`便利だ`, read
/// `べんりだ`), the dictionary word without it (`便利`, `べんり`) when the
/// table has that, else the first reading (the written form when there is
/// none).
WordSpeech wordSpeechFor(Word word, AccentTable table) {
  final readings = word.readings.isEmpty ? [word.headword] : word.readings;
  final bare = withoutPrintedEnding(word.headword, word.readings);
  return _withAccents(word.headword, readings, word.pos, table) ??
      (bare == null
          ? null
          : _withAccents(
              bare.headword,
              bare.readings.isEmpty ? [bare.headword] : bare.readings,
              word.pos,
              table,
            )) ??
      WordSpeech(
        headword: word.headword,
        reading: readings.first,
        pos: word.pos,
      );
}

/// The request for [headword] read as the first of [readings] [table] has
/// accents for; null when it has none.
WordSpeech? _withAccents(
  String headword,
  List<String> readings,
  PartOfSpeech? pos,
  AccentTable table,
) {
  for (final reading in readings) {
    final accents = table.lookup(headword, reading);
    if (accents.isNotEmpty) {
      return WordSpeech(
        headword: headword,
        reading: reading,
        accents: accents,
        pos: pos,
      );
    }
  }
  return null;
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
