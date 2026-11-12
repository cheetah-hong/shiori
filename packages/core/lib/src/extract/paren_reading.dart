/// Bracketed readings as a word list prints them, checked against the
/// dictionary while the fragments are collected (docs/extraction.md 2).
///
/// `漢字(かな)` splits into a headword and its reading as printed. A short
/// kana ending after the brackets (`親切(しんせつ)だ`, `新(あたら)しい`) or an
/// honorific in front (`お茶(ちゃ)`) splits only when the dictionary reads the
/// whole word so: a bracket inside a sentence (`学校(がっこう)を…`) stays a
/// sentence. The same check tells a checkbox read as 口 or ロ glued to a word
/// from a word that starts with that glyph, and a bracketed line read at
/// the engine's lowest confidence from garbage.
library;

import 'package:shiori_core/src/extract/script_runs.dart';

/// What the fragment collector asks the dictionary (answered from forms
/// looked up before, see [fragmentProbeForms]).
abstract interface class FragmentDictionary {
  /// [text] is a dictionary word as a word list prints it: a dictionary
  /// form, or a な-adjective with だ.
  bool knows(String text);

  /// The dictionary reads [headword] (as printed) as [kana].
  bool reads(String headword, String kana);

  /// [text] is a noun the dictionary has as a する verb (`vs`).
  bool takesSuru(String text);
}

/// `漢字(かな)`, `漢字[かな]`, `漢字【かな】`… with the closing bracket maybe
/// not read; several readings may be printed (`/`, `・`).
final RegExp inlineReading = RegExp(
  r'^([\p{Script=Han}々〆][\p{Script=Han}々〆\p{Script=Hiragana}\p{Script=Katakana}ー]*?)\s*'
  r'[(（\[［【「]\s*([\p{Script=Hiragana}\p{Script=Katakana}ー\s/／・]+?)\s*[)）\]］】」]?\s*$',
  unicode: true,
);

/// Checkbox glyphs in front of a Japanese line (and a dash glued to it).
final RegExp leadingCheckbox = RegExp('^(?:[□■☐☑☒|｜]+\\s*|ー+(?=[^ー\\s]))');

/// A 口 or ロ in front: a checkbox when the column or a space says so, or
/// [isGluedBox].
final RegExp leadingLookalikeBox = RegExp('^[口ロ](?:\\s+|(?=[^\\s]))');

/// One bracketed reading with an honorific in front or up to three kana
/// after the closing bracket, and nothing else on the run.
final RegExp _wrapped = RegExp(
  r'^([おご]?)([\p{Script=Han}々〆][\p{Script=Han}々〆\p{Script=Hiragana}\p{Script=Katakana}ー]*?)\s*'
  r'[(（\[［【「]\s*([\p{Script=Hiragana}\p{Script=Katakana}ー]+?)\s*[)）\]］】」]\s*(\p{Script=Hiragana}{0,3})$',
  unicode: true,
);

final RegExp _anyBracket = RegExp('[(（\\[［【「)）\\]］】」]');
final RegExp _openingBracket = RegExp('[(（\\[［【「]');
final RegExp _space = RegExp(r'\s');

/// A headword and its reading out of a bracketed reading with a prefix or
/// an ending, and where they are printed in the text (code units).
typedef WrappedReading = ({
  String headword,
  String reading,
  int headEnd,
  int readingStart,
  int readingEnd,
});

/// [text] as a bracketed reading with an honorific in front or a kana
/// ending after it, when [dictionary] reads the word so; else null (also
/// for a plain `漢字(かな)`, which [inlineReading] takes).
///
/// The headword is printed form (prefix, kanji, ending) and the reading the
/// brackets' kana with the prefix (unless the brackets hold it already) and
/// the ending. With する after the brackets the headword is the noun the
/// dictionary has as a する verb (`練習(れんしゅう)する` → 練習, れんしゅう).
WrappedReading? wrappedReading(String text, FragmentDictionary dictionary) {
  final m = _wrapped.firstMatch(text);
  if (m == null) return null;
  final prefix = m.group(1)!;
  final head = m.group(2)!;
  final kana = m.group(3)!;
  final ending = m.group(4)!;
  if (prefix.isEmpty && ending.isEmpty) return null;
  final headEnd = prefix.length + head.length;
  final readingStart = text.indexOf(kana, headEnd);
  WrappedReading found(String headword, String reading) => (
    headword: headword,
    reading: reading,
    headEnd: headEnd,
    readingStart: readingStart,
    readingEnd: readingStart + kana.length,
  );

  final headword = '$prefix$head$ending';
  for (final reading in {
    if (prefix.isNotEmpty && kana.startsWith(prefix)) '$kana$ending',
    '$prefix$kana$ending',
  }) {
    if (dictionary.reads(headword, reading)) return found(headword, reading);
  }
  if (ending == 'する' &&
      prefix.isEmpty &&
      dictionary.takesSuru(head) &&
      dictionary.reads(head, kana)) {
    return found(head, kana);
  }
  return null;
}

/// [text] is a word the dictionary has as printed: a `漢字(かな)` it reads so
/// (also with a prefix or an ending), or a dictionary form.
bool isDictionaryWord(String text, FragmentDictionary dictionary) {
  final m = inlineReading.firstMatch(text);
  if (m != null) {
    final head = m.group(1)!;
    return dictionary.knows(head) &&
        dictionary.reads(head, m.group(2)!.replaceAll(_space, ''));
  }
  if (wrappedReading(text, dictionary) != null) return true;
  return !text.contains(_anyBracket) && dictionary.knows(text);
}

/// [text] without its checkbox in front, then also without a 口 or ロ after
/// it (the whole text first).
List<String> unboxed(String text) {
  final box = leadingCheckbox.firstMatch(text);
  final t = (box == null ? text : text.substring(box.end)).trim();
  final look = leadingLookalikeBox.firstMatch(t);
  return [
    text.trim(),
    t,
    if (look != null && t.length > 1) t.substring(look.end).trim(),
  ];
}

/// [text] (a Japanese-pass run) is a bracketed reading the dictionary
/// confirms, after a checkbox or a box glyph in front.
bool confirmsBracketedReading(String text, FragmentDictionary dictionary) {
  for (final t in unboxed(text).skip(1)) {
    if (t.contains(_openingBracket) && isDictionaryWord(t, dictionary)) {
      return true;
    }
  }
  return false;
}

/// A 口 or ロ glued to the word at [restAt] of [text] where no checkbox
/// column says it is a box: a box when the rest is a dictionary word and
/// the whole is not (`口紅` stays), and the rest starts with kanji or
/// hiragana (after ロ, katakana may go on a loanword).
bool isGluedBox(String text, int restAt, FragmentDictionary dictionary) {
  final rest = text.substring(restAt).trim();
  if (rest.isEmpty) return false;
  final first = rest.runes.first;
  if (!isKanji(first) && !isHiragana(first)) return false;
  return isDictionaryWord(rest, dictionary) &&
      !isDictionaryWord(text.trim(), dictionary);
}

/// The printed forms the checks above may ask about for a Japanese run
/// [text]: the extractor looks them up before collecting.
Iterable<String> fragmentProbeForms(String text) => {
  for (final t in unboxed(text)) ...[
    t,
    if (inlineReading.firstMatch(t) case final m?) m.group(1)!,
    if (_wrapped.firstMatch(t) case final m?) ...[
      '${m.group(1)}${m.group(2)}${m.group(4)}',
      m.group(2)!,
    ],
  ],
};
