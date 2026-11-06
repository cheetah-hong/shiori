/// How a sentence uses its words: the class a word is used as, a counter
/// after a number, a stem left over next to its dictionary form
/// (docs/extraction.md 3.3).
library;

import 'package:shiori_core/src/extract/deconjugator.dart';
import 'package:shiori_core/src/extract/extracted_word.dart';
import 'package:shiori_core/src/extract/lattice.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/ports/lexicon.dart';

/// Endings the な-adjective rules take off (deconjugator.dart): the token
/// itself shows the word used as a な-adjective (静かな, 静かだ) or as an
/// adverb (静かに).
const Map<String, PartOfSpeech> _naRules = {
  'attributive な': PartOfSpeech.naAdjective,
  'predicative だ': PartOfSpeech.naAdjective,
  'conjunctive で': PartOfSpeech.naAdjective,
  'adverbial に': PartOfSpeech.adverb,
};

/// The class [t] is used as when the dictionary gives it as an adverb and
/// also as a な-adjective or a noun: だ・な・で・じゃ after it, a
/// な-adjective; a verb or adjective after it, an adverb; が・を・は・の, a
/// noun. Null when its classes are not mixed so or nothing tells.
PartOfSpeech? usagePos(LatticeToken t, LatticeToken? next) {
  final codes = t.partsOfSpeech;
  final na = codes.contains('adj-na');
  final noun = codes.contains('n');
  if (!codes.contains('adv') || !(na || noun)) return null;
  final byRule = na ? _naRules[t.steps.firstOrNull] : null;
  if (byRule != null) return byRule;
  if (next == null || next.start != t.end) return null;
  final after = next.surface;
  if (na && ['だ', 'な', 'で', 'じゃ'].any(after.startsWith)) {
    return PartOfSpeech.naAdjective;
  }
  if (next.known &&
      !next.isFunctionWord &&
      next.partsOfSpeech.any((c) => c.startsWith('v') || c == 'adj-i')) {
    return PartOfSpeech.adverb;
  }
  if (noun && ['が', 'を', 'は', 'の'].any(after.startsWith)) {
    return PartOfSpeech.noun;
  }
  return null;
}

/// A counter right after a number (`第3課`'s 課): part of the number, not
/// a word.
bool isCounterAfterNumber(LatticeToken t, String sentence) {
  if (!t.partsOfSpeech.contains('ctr') || t.start == 0) return false;
  final c = sentence.runes.elementAt(t.start - 1);
  return (c >= 0x30 && c <= 0x39) || (c >= 0xFF10 && c <= 0xFF19);
}

/// The verbs the noun [t] is the stem of (決め of 決める) when nothing after
/// it in its sentence shows it used as a noun of its own; empty otherwise.
/// Shown as a noun: a particle or the copula after it, or a content word
/// (手作りケーキ). [found] answers the sentence's forms.
Set<String> stemOnlyOf(
  LatticeToken t,
  LatticeToken? next,
  List<LexiconEntry> Function(String form) found, {
  Deconjugator? deconjugator,
}) {
  if (!t.known || t.steps.isNotEmpty || !t.partsOfSpeech.contains('n')) {
    return const {};
  }
  if (next != null && next.start == t.end && next.known) {
    final codes = next.partsOfSpeech;
    if (codes.contains('prt') || codes.contains('cop')) return const {};
    if (!next.isFunctionWord) return const {};
  }
  final ds = (deconjugator ?? Deconjugator.standard).deconjugate(t.surface);
  return {
    for (final l in rankLemmas(ds, {for (final d in ds) d.base: found(d.base)}))
      if (l.conjugated &&
          l.entry.id != t.entry?.id &&
          (l.deinflection.tag?.startsWith('v') ?? false))
        l.base,
  };
}

/// [words] without the sentence words that are only the stem of a word the
/// page also has ([stems]: by [stemKey], the dictionary forms each is the
/// stem of). The word they go into takes the stem's example when it has
/// none; its own example stays.
List<ExtractedWord> withStemsAbsorbed(
  List<ExtractedWord> words,
  Map<String, Set<String>> stems,
) {
  if (stems.isEmpty) return words;
  final heads = {for (final w in words) w.headword};
  final into = <String, WordExample>{};
  final kept = <ExtractedWord>[];
  for (final w in words) {
    final of = w.origin == WordOrigin.sentence ? stems[stemKey(w)] : null;
    final target = of?.where(heads.contains).firstOrNull;
    if (target == null) {
      kept.add(w);
      continue;
    }
    if (w.example case final e?) into.putIfAbsent(target, () => e);
  }
  return [
    for (final w in kept)
      if (w.example == null && into[w.headword] != null)
        w.copyWith(example: into[w.headword])
      else
        w,
  ];
}

/// A sentence word's key in [withStemsAbsorbed]: its sentence and headword.
String stemKey(ExtractedWord w) => '${w.headwordFragmentId}|${w.headword}';
