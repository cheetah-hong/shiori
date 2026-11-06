// Shared blocks for the pairing-confidence tests: the capture with
// dictionary values copied from the real dictionaries (synthetic words only),
// and the trap pages of the general set.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

import '../../support/real_dictionary.dart';
import 'connect_fixtures.dart';
import 'extract_fixtures.dart';

/// The Korean glossary's real senses for the synthetic words.
MemoryKoreanGlossary realGlossary() => MemoryKoreanGlossary(realSenses);

/// The same senses, read backwards as the app's glossary is: the readings of
/// the word-book pages' words (every entry of a spelling, merged).
MemoryKoreanGlossary realReverseGlossary() => MemoryKoreanGlossary(
  realSenses,
  readings: {
    for (final key in realSenses.keys)
      key: [
        for (final w in rowPageWords)
          if (w.kanji.contains(key)) ...w.readings,
      ],
  },
);

/// The word-book pages' words (tools/synthetic/make_pages.py) as the real
/// dictionary has them.
InMemoryLexicon rowLexicon() => InMemoryLexicon(rowPageWords);

/// The general pages' lexicon plus the trap pages' words.
InMemoryLexicon trapLexicon() => InMemoryLexicon([
  for (final e in readGeneralJson('lexicon.json')['entries']! as List)
    LexiconWord.fromJson((e as Map).cast<String, Object?>()),
  ...trapWords,
]);

/// The word extractor as the app builds it, on [lexicon] with [glossary].
GeneralExtractor confidenceExtractor(
  Lexicon lexicon, {
  KoreanGlossary? glossary,
}) => GeneralExtractor(lexicon: lexicon, koreanGlossary: glossary);

/// Answers of the trap pages g21-g23.
ExtractTruth trapTruth() =>
    ExtractTruth.fromJson(readGeneralJson('ground_truth_traps.json'));

/// High entries and high entries with a wrong reading or meaning, over
/// every page of [truth].
Future<({int high, int highWrong})> highCounts(
  ExtractTruth truth,
  Future<OcrScan> Function(String fixture) load,
  GeneralExtractor extractor,
) async {
  var high = 0, highWrong = 0;
  for (final page in truth.pages) {
    final draft = await pageDraft(extractor, await load(page.fixture));
    final score = scoreExtractPage(page, [
      for (final e in draft.entries) ScoredWord.fromCaptured(e),
    ]);
    high += score.high;
    highWrong += score.highWrong;
  }
  return (high: high, highWrong: highWrong);
}

/// The entry of [draft] with [headword] (the first one).
CapturedEntry entryOf(CaptureDraft draft, String headword) =>
    draft.entries.firstWhere((e) => e.headword == headword);

/// The pairing confidence of [field] of [entry] (null without one).
PairConfidence? confidenceOf(CapturedEntry entry, EntryField field) =>
    entry.evidence?.of(field)?.confidence;
