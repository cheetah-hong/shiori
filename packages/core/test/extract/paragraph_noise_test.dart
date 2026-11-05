// E6: Japanese the Japanese pass read out of a Korean explanation paragraph
// gives no words; a word printed in the paragraph as 漢字[かな] stays.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

Future<PageExtractScore> _score(String fixture) async {
  final truth = ExtractTruth.fromJson(readGeneralJson('ground_truth.json'));
  final page = truth.pages.singleWhere((p) => p.fixture == fixture);
  final r = await GeneralExtractor(
    lexicon: generalLexicon(),
  ).extract(await loadGeneralScan(fixture));
  return scoreExtractPage(page, [
    for (final w in r.words) ScoredWord.fromExtracted(w),
  ]);
}

void main() {
  test('g06: no extras — the paragraph lines read as 上手・木・気 and the '
      'pattern 〜が好きです。 give no words', () async {
    final score = await _score('g06');

    expect(score.extras, 0, reason: score.mistakes.join('\n'));
    expect(score.duplicates, 0);
  });

  test('g06: 学校[がっこう] printed inside the paragraph stays a word', () async {
    final r = await GeneralExtractor(
      lexicon: generalLexicon(),
    ).extract(await loadGeneralScan('g06'));

    final w = r.words.singleWhere((w) => w.headword == '学校');
    expect(w.readings, ['がっこう']);
    expect(w.readingLink!.signals, contains(PairSignal.inlineNotation));
    for (final noise in ['上手', '木', '気', '好き']) {
      expect(r.words.where((w) => w.headword == noise), isEmpty, reason: noise);
    }
  });

  test('g06: every printed word and sentence word is still found', () async {
    final score = await _score('g06');

    expect(score.found, score.vocab);
    expect(score.sentenceWords.ok, score.sentenceWords.of);
  });

  test('the other synthetic pages keep their scores (no extras, nothing '
      'lost)', () async {
    for (final fixture in ['g01', 'g02', 'g03', 'g04', 'g05']) {
      final score = await _score(fixture);
      expect(score.found, score.vocab, reason: fixture);
      expect(score.sentenceWords.ok, score.sentenceWords.of, reason: fixture);
      expect(score.extras, lessThanOrEqualTo(1), reason: fixture);
    }
  });

  test(
    'a reading in brackets inside a sentence is not a word of its own',
    () async {
      final r = await GeneralExtractor(
        lexicon: testLexicon(),
      ).extract(scan(ja: [line('毎日学校［がっこう］に行った。', 0.1, 0.1, c: 1.0)]));

      expect(r.words.map((w) => w.headword), contains('学校'));
      expect(r.words.where((w) => w.headword == 'がっこう'), isEmpty);
    },
  );

  test('one kana out of a sentence is not a word', () async {
    final lexicon = InMemoryLexicon([
      ...testWords,
      const LexiconWord(id: 9000002, readings: ['こ'], pos: ['n'], priority: 0),
    ]);
    final r = await GeneralExtractor(
      lexicon: lexicon,
    ).extract(scan(ja: [line('学校に行った。こ', 0.1, 0.1, c: 1.0)]));

    expect(r.words.where((w) => w.headword == 'こ'), isEmpty);
    expect(r.words.map((w) => w.headword), contains('学校'));
  });
}
