// The score table counts words that are extras (in no answer list) yet
// high: a wrong headword the learner would approve unseen.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  const page = ExtractTruthPage(
    page: 't1',
    fixture: 't1',
    vocab: [
      TruthWord(headword: '皿', readings: ['さら'], meaning: '접시'),
    ],
    ignore: {'ロロロ'},
  );

  test('an extra at high confidence counts as extra and extra-high', () {
    final s = scoreExtractPage(page, const [
      ScoredWord(
        headword: 'さら',
        meaning: '접시',
        confidence: PairConfidence.high,
      ),
    ]);
    expect(s.extras, 1);
    expect(s.extraHigh, 1);
    expect(s.mistakes, contains('EXTRA-HIGH さら'));
  });

  test('extras below high and ignored words do not count', () {
    final s = scoreExtractPage(page, const [
      ScoredWord(
        headword: 'さら',
        meaning: '접시',
        confidence: PairConfidence.medium,
      ),
      ScoredWord(headword: 'ロロロ', confidence: PairConfidence.high),
      ScoredWord(
        headword: '皿',
        readings: ['さら'],
        meaning: '접시',
        confidence: PairConfidence.high,
      ),
    ]);
    expect(s.extras, 1);
    expect(s.extraHigh, 0);
    expect(s.high, 1);
  });

  test('the table and its total show extra-high', () {
    final s = scoreExtractPage(page, const [
      ScoredWord(headword: 'さら', confidence: PairConfidence.high),
    ]);
    final table = ExtractScore([s]).table();
    expect(table, contains('exHigh'));
    expect(table, contains('extra_high=1'));
    expect(ExtractScore([s, s]).extraHigh, 2);
  });
}
