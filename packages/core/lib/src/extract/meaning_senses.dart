/// The meaning a dictionary word gets when the page gives none, and the
/// senses offered as candidates (docs/extraction.md 4.5).
///
/// The glossary orders the senses (with the class the word is printed as);
/// on top of that a sense that spells the headword's kanji in Korean
/// readings comes first (雪森 → 설삼 before 눈숲), a sentence word with a
/// negative after it takes a sense used with a negative (別に → 별로, not
/// 따로), and a sentence word takes the sense its printed translation uses. The pairing of a page's own
/// meanings does not go through here.
library;

import 'package:shiori_core/src/extract/hanja.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/ports/korean_glossary.dart';

/// Senses asked of the glossary for a word's meaning and its candidates.
const int meaningSenses = 5;

/// Candidates offered for a meaning cell, at most.
const int maxMeaningCandidates = 4;

/// A Korean reading of the kanji names the meaning only from this many
/// syllables (one syllable matches another word by chance too often).
const int minSpelledSyllables = 2;

/// Kanji numerals: their one-syllable Korean reading is the textbook's
/// meaning (三 → 삼, not 셋).
const String _numerals = '一二三四五六七八九十百千万';

/// The senses of [headword] for its meaning cell, best first (at most
/// [meaningSenses]): the glossary's order with [pos] as its class hint, then
/// [orderMeaningSenses].
///
/// The word extractor asks the same way, through its page cache, with the
/// page's badge as [pos] when one is printed (else the dictionary's class),
/// a sentence word's printed translation as [translation] and whether a
/// negative follows it as [negated].
Future<List<KoreanSense>> meaningSensesOf(
  KoreanGlossary glossary,
  String headword, {
  List<String> readings = const [],
  PartOfSpeech? pos,
  String? translation,
  bool negated = false,
}) async => orderMeaningSenses(
  headword,
  await glossary.lookup(
    headword,
    readings: readings,
    limit: meaningSenses,
    pos: pos,
  ),
  translation: translation,
  negated: negated,
);

/// [senses] (the glossary's order) with the senses that spell [headword]'s
/// kanji in Korean readings first; then, when [negated] (a negative follows
/// the word in its sentence) and the first sense is no Korean adverb used
/// with a negative, the first such sense in front; then, with a
/// [translation] (the printed translation of the sentence the word came
/// from), the first sense it names in front. Nothing is left out.
List<KoreanSense> orderMeaningSenses(
  String headword,
  List<KoreanSense> senses, {
  String? translation,
  bool negated = false,
}) {
  final spellings = sinoKoreanReadings(headword);
  final syllables =
      headword.runes.every((c) => _numerals.contains(String.fromCharCode(c)))
      ? 1
      : minSpelledSyllables;
  bool spells(KoreanSense s) =>
      s.words.any((w) => _spellsKanji(w, spellings, syllables));
  final spelled = [...senses.where(spells), ...senses.where((s) => !spells(s))];
  final ordered = negated ? _negativeFirst(spelled) : spelled;
  if (translation == null || translation.trim().isEmpty) {
    return List.unmodifiable(ordered);
  }
  final named = ordered.indexWhere(
    (s) => s.words.any((w) => _namedIn(w, translation)),
  );
  if (named <= 0) return List.unmodifiable(ordered);
  return List.unmodifiable(_toFront(ordered, named));
}

/// Korean adverbs used with a negative after them (별로 좋지 않다): the
/// sense a Japanese adverb has before a negative (別に・あまり・全然).
const Set<String> negativePolarityWords = {
  '별로', '그다지', '전혀', '전연', '결코', '결단코', '도무지', '도저히', //
  '도통', '당최', '통', '영', '별반', '과히', '조금도', '하나도', //
  '좀처럼', '좀체', '여간', '차마', '미처', '딱히', '그리', '별달리', //
};

bool _usedWithNegative(KoreanSense s) =>
    s.words.any((w) => negativePolarityWords.contains(w.trim()));

/// [senses] with the first sense used with a negative in front, unless the
/// first already is one or none is.
List<KoreanSense> _negativeFirst(List<KoreanSense> senses) {
  if (senses.isEmpty || _usedWithNegative(senses.first)) return senses;
  final at = senses.indexWhere(_usedWithNegative);
  return at <= 0 ? senses : _toFront(senses, at);
}

/// [senses] with the one at [at] moved to the front.
List<KoreanSense> _toFront(List<KoreanSense> senses, int at) => [
  senses[at],
  for (final (i, s) in senses.indexed)
    if (i != at) s,
];

/// Prefixes and suffixes of the glossary (`-이`, `-하다`) name no word.
bool _isAffix(String word) => word.startsWith('-') || word.endsWith('-');

/// [word] is a Korean reading of the kanji ([spellings]) of at least
/// [syllables] syllables, alone or with 하다 / 되다 (静走 → 정주하다).
bool _spellsKanji(String word, Set<String> spellings, int syllables) {
  final w = word.trim();
  if (w.isEmpty || _isAffix(w)) return false;
  final bare = w.replaceAll(RegExp(r'\s+'), '');
  return spellings.any(
    (r) =>
        r.length >= syllables &&
        (bare == r || bare == '$r하다' || bare == '$r되다'),
  );
}

/// [translation] uses [word]: a word other than a verb or adjective as it
/// is, a verb or adjective by its stem (반짝이다 in 반짝였습니다 through
/// 반짝; 산책하다 through 산책). The piece found has two syllables or more.
bool _namedIn(String word, String translation) {
  final w = word.trim();
  if (_isAffix(w)) return false;
  if (!w.endsWith('다')) {
    return w.length >= minSpelledSyllables && translation.contains(w);
  }
  final stem = w.substring(0, w.length - 1);
  final pieces = [
    stem,
    if (stem.endsWith('하')) stem.substring(0, stem.length - 1),
    if (stem.length > minSpelledSyllables) stem.substring(0, stem.length - 1),
  ];
  return pieces.any(
    (p) => p.length >= minSpelledSyllables && translation.contains(p),
  );
}
