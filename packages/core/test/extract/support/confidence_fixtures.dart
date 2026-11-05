// Shared blocks for the pairing-confidence tests: the routed capture with
// dictionary values copied from the real dictionaries (synthetic words only),
// and the trap pages of the general set.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

import '../../support/real_dictionary.dart';
import 'connect_fixtures.dart';
import 'extract_fixtures.dart';

/// The Korean glossary's real senses for the synthetic words.
MemoryKoreanGlossary realGlossary() => MemoryKoreanGlossary(realSenses);

/// The row-template pages' words as the real dictionary has them.
InMemoryLexicon rowLexicon() => InMemoryLexicon(rowPageWords);

/// The general pages' lexicon plus the trap pages' words.
InMemoryLexicon trapLexicon() => InMemoryLexicon([
  for (final e in readGeneralJson('lexicon.json')['entries']! as List)
    LexiconWord.fromJson((e as Map).cast<String, Object?>()),
  ...trapWords,
]);

/// The routed capture as the app builds it: the row template (no JMdict
/// adapter: the synthetic pages were scored without one) and the general
/// extractor on [lexicon] with [glossary]. Template pages take their
/// evidence from the same lexicon and glossary.
CaptureRouter confidenceRouter(Lexicon lexicon, {KoreanGlossary? glossary}) =>
    CaptureRouter(
      template: CapturePipeline.standard(glossary: glossary),
      general: GeneralExtractor(lexicon: lexicon, koreanGlossary: glossary),
    );

/// Answers of the trap pages g21-g23.
ExtractTruth trapTruth() =>
    ExtractTruth.fromJson(readGeneralJson('ground_truth_traps.json'));

/// High entries and high entries with a wrong reading or meaning, over
/// every page of [truth].
Future<({int high, int highWrong})> highCounts(
  ExtractTruth truth,
  Future<OcrScan> Function(String fixture) load,
  CaptureRouter router,
) async {
  var high = 0, highWrong = 0;
  for (final page in truth.pages) {
    final draft = await router.fromScan(await load(page.fixture));
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
