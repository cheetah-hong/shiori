/// The meaning a dictionary word gets when the page gives none, and the
/// senses offered as candidates (docs/extraction.md 4.5).
///
/// The glossary orders the senses (with the class the word is printed as);
/// on top of that a sense that spells the headword's kanji in Korean
/// readings comes first (雪森 → 설삼 before 눈숲), and a sentence word takes
/// the sense its printed translation uses. The pairing of a page's own
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
/// page's badge as [pos] when one is printed (else the dictionary's class)
/// and a sentence word's printed translation as [translation].
Future<List<KoreanSense>> meaningSensesOf(
  KoreanGlossary glossary,
  String headword, {
  List<String> readings = const [],
  PartOfSpeech? pos,
  String? translation,
}) async => orderMeaningSenses(
  headword,
  await glossary.lookup(
    headword,
    readings: readings,
    limit: meaningSenses,
    pos: pos,
  ),
  translation: translation,
);

/// [senses] (the glossary's order) with the senses that spell [headword]'s
/// kanji in Korean readings first, and then, with a [translation] (the
/// printed translation of the sentence the word came from), the first sense
/// it names in front. Nothing is left out.
List<KoreanSense> orderMeaningSenses(
  String headword,
  List<KoreanSense> senses, {
  String? translation,
}) {
  final spellings = sinoKoreanReadings(headword);
  final syllables =
      headword.runes.every((c) => _numerals.contains(String.fromCharCode(c)))
      ? 1
      : minSpelledSyllables;
  bool spells(KoreanSense s) =>
      s.words.any((w) => _spellsKanji(w, spellings, syllables));
  final ordered = [...senses.where(spells), ...senses.where((s) => !spells(s))];
  if (translation == null || translation.trim().isEmpty) {
    return List.unmodifiable(ordered);
  }
  final named = ordered.indexWhere(
    (s) => s.words.any((w) => _namedIn(w, translation)),
  );
  if (named <= 0) return List.unmodifiable(ordered);
  return List.unmodifiable([
    ordered[named],
    for (final (i, s) in ordered.indexed)
      if (i != named) s,
  ]);
}

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
