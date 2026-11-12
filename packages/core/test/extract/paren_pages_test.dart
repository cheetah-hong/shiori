// P6 on the synthetic pages of bracketed readings with an ending or an
// honorific (tools/synthetic/make_general_pages.py, answers in
// ground_truth_paren.json): g40 a word box with `親切(しんせつ)だ`-like rows,
// one at the engine's lowest confidence under the Korean pass's garbage, and
// a sentence with a bracketed reading in it; g41 two rows cut out of a word
// list with checkboxes glued to the words, one row at the lowest confidence
// and a show-through mark after a meaning. Every word comes out read and
// meant right, nothing extra, nothing wrong or extra at high.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

/// High entries at least (measured with the memory lexicon and glossary).
const Map<String, int> _minHigh = {'g40': 7, 'g41': 2};

Future<PageExtractScore> _score(String fixture) async {
  final draft = await pageDraft(
    GeneralExtractor(
      lexicon: generalLexicon(),
      koreanGlossary: generalGlossary(),
    ),
    await loadGeneralScan(fixture),
  );
  final truth = ExtractTruth.fromJson(
    readGeneralJson('ground_truth_paren.json'),
  );
  return scoreExtractPage(
    truth.pages.singleWhere((p) => p.fixture == fixture),
    [for (final e in draft.entries) ScoredWord.fromCaptured(e)],
  );
}

void main() {
  for (final fixture in _minHigh.keys) {
    test('$fixture: every word found, read and meant right, no extras, '
        'nothing wrong or extra at high', () async {
      final s = await _score(fixture);
      print(
        '$fixture: ${s.found}/${s.vocab} reading ${s.readingsOk} meaning '
        '${s.meanings.ok}/${s.meanings.of} extras ${s.extras} high ${s.high} '
        'highWrong ${s.highWrong} extraHigh ${s.extraHigh}',
      );
      expect(s.found, s.vocab, reason: '${s.mistakes}');
      expect(s.readingsOk, s.found, reason: '${s.mistakes}');
      expect(s.meanings.ok, s.meanings.of, reason: '${s.mistakes}');
      expect(s.extras, 0, reason: '${s.mistakes}');
      expect(s.highWrong, 0, reason: '${s.mistakes}');
      expect(s.extraHigh, 0, reason: '${s.mistakes}');
      expect(s.high, greaterThanOrEqualTo(_minHigh[fixture]!));
    });
  }

  test('g40: the sentence with a bracketed reading gives its words', () async {
    final s = await _score('g40');
    expect(s.sentenceWords.ok, s.sentenceWords.of);
    expect(s.sentencePredicted.ok, s.sentencePredicted.of);
  });
}
