// V3: the synthetic general pages g01–g06 score as before with the word-list
// rules in (memory lexicon and the gloss stand-in as a glossary).
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

const _pages = ['g01', 'g02', 'g03', 'g04', 'g05', 'g06'];

void main() {
  test('g01–g06: found 49/49, readings 49/49, meanings 48/48, sentence '
      'words 45/45 and 38/38, no extras, no high but wrong', () async {
    final truth = ExtractTruth.fromJson(readGeneralJson('ground_truth.json'));
    final extractor = GeneralExtractor(
      lexicon: generalLexicon(),
      koreanGlossary: generalGlossary(),
    );
    final scores = [
      for (final page in truth.pages.where((p) => _pages.contains(p.fixture)))
        scoreExtractPage(page, [
          for (final w in (await extractor.extract(
            await loadGeneralScan(page.fixture),
          )).words)
            ScoredWord.fromExtracted(w),
        ]),
    ];
    int sum(int Function(PageExtractScore) f) =>
        scores.fold(0, (s, p) => s + f(p));
    expect(scores, hasLength(6));
    expect(sum((s) => s.vocab), 49);
    expect(sum((s) => s.found), 49);
    expect(sum((s) => s.readingsOk), 49);
    expect(sum((s) => s.meanings.ok), 48);
    expect(sum((s) => s.meanings.of), 48);
    expect(sum((s) => s.sentenceWords.ok), 45);
    expect(sum((s) => s.sentenceWords.of), 45);
    expect(sum((s) => s.sentencePredicted.ok), 38);
    expect(sum((s) => s.sentencePredicted.of), 38);
    expect(sum((s) => s.extras), 0);
    expect(sum((s) => s.highWrong), 0);
  });
}
