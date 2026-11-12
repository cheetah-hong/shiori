import 'package:shiori_core/src/capture/text/chars.dart' show nfkc;
import 'package:shiori_core/src/extract/script_runs.dart' show isKanji;

/// A headword as one word: a な-adjective's printed だ does not count
/// (`丈夫だ` from a word list and `丈夫` from a sentence are one word).
String headwordKey(String headword) =>
    headword.length > 1 && headword.endsWith('だ') && headword.runes.any(isKanji)
    ? headword.substring(0, headword.length - 1)
    : headword;

final RegExp _spaces = RegExp(r'\s+');

/// What makes two saved words the same word: the headword alone, in NFKC
/// without spaces, with [headwordKey] applied. Readings are left out (OCR
/// misreads them more than anything else, and a word may have several).
String wordKey(String headword) =>
    headwordKey(nfkc(headword).replaceAll(_spaces, ''));

/// Endings a word list prints after a な-adjective (`便利だ`, `静かな`).
const List<String> _printedEndings = ['だ', 'な'];

/// [headword] and its [readings] without a な-adjective's printed ending
/// (`便利だ` read `べんりだ` → `便利`, `べんり`; a reading printed without it
/// stays), to look the word up where the dictionaries file it bare. Null
/// when there is none to drop: no kanji, nothing before the ending, or
/// another ending. The saved word keeps its printed form.
({String headword, List<String> readings})? withoutPrintedEnding(
  String headword,
  List<String> readings,
) {
  if (headword.length < 2 || !headword.runes.any(isKanji)) return null;
  for (final ending in _printedEndings) {
    if (!headword.endsWith(ending)) continue;
    return (
      headword: headword.substring(0, headword.length - ending.length),
      readings: [
        for (final r in readings)
          r.length > ending.length && r.endsWith(ending)
              ? r.substring(0, r.length - ending.length)
              : r,
      ],
    );
  }
  return null;
}
