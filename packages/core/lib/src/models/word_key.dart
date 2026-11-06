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
