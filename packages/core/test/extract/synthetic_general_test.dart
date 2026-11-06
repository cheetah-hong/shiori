// T18–T19: the synthetic pages for the word extractor, scored by headword.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

Future<PageExtractScore> _general(ExtractTruthPage page) async {
  final scan = await loadGeneralScan(page.fixture);
  final result = await GeneralExtractor(
    lexicon: generalLexicon(),
  ).extract(scan);
  return scoreExtractPage(page, [
    for (final w in result.words) ScoredWord.fromExtracted(w),
  ]);
}

void main() {
  final truth = ExtractTruth.fromJson(readGeneralJson('ground_truth.json'));
  ExtractTruthPage page(String fixture) =>
      truth.pages.singleWhere((p) => p.fixture == fixture);

  test(
    'T18 word box page: every printed word found, no high-but-wrong',
    () async {
      final score = await _general(page('g01'));
      // Printed for the score table in the test output.
      print(
        'g01 ${score.found}/${score.vocab} reading ${score.readingsOk} '
        'meaning ${score.meanings.ok}/${score.meanings.of} highWrong ${score.highWrong}',
      );

      expect(score.found, score.vocab);
      expect(score.highWrong, 0);
    },
  );

  test('T19 curled word-list page: all 15 readings and meanings on their '
      'headwords', () async {
    final p = page('g04');
    expect(p.vocab, hasLength(15));

    final general = await _general(p);

    expect(general.found, 15);
    expect(general.readingsOk, 15);
    expect(general.meanings, (ok: 15, of: 15));
    expect(general.highWrong, 0);
  });
}
