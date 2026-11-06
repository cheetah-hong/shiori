// T20: the headword-based scorer on a small hand-made page.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

const _page = ExtractTruthPage(
  page: 't1',
  fixture: 't1',
  vocab: [
    TruthWord(headword: '料理', readings: ['りょうり'], meaning: '요리'),
    TruthWord(headword: '地図', readings: ['ちず'], meaning: '지도'),
    TruthWord(headword: 'ゆっくり', meaning: '천천히'),
    TruthWord(headword: '机', readings: ['つくえ']),
  ],
  sentenceWords: ['朝', '起きる'],
  ignore: {'第一課'},
);

void main() {
  group('T20 scoring by headword', () {
    final words = [
      const ScoredWord(
        headword: '料理',
        readings: ['りょうり'],
        meaning: '요리',
        confidence: PairConfidence.high,
      ),
      // Wrong reading with high confidence: a high-but-wrong word.
      const ScoredWord(
        headword: '地図',
        readings: ['ちと'],
        meaning: '지도',
        confidence: PairConfidence.high,
      ),
      const ScoredWord(
        headword: '地図',
        readings: ['ちず'],
        meaning: '지도',
        confidence: PairConfidence.medium,
      ),
      const ScoredWord(
        headword: '机',
        readings: ['つくえ'],
        meaning: '책상',
        confidence: PairConfidence.low,
      ),
      const ScoredWord(
        headword: '朝',
        readings: ['あさ'],
        origin: WordOrigin.sentence,
      ),
      const ScoredWord(
        headword: '歩く',
        readings: ['あるく'],
        origin: WordOrigin.sentence,
      ),
      const ScoredWord(headword: '第一課', origin: WordOrigin.wordList),
      const ScoredWord(headword: '窓', readings: ['まど'], meaning: '창문'),
    ];
    final s = scoreExtractPage(_page, words);

    test('found, readings and meanings of the printed words', () {
      expect(s.vocab, 4);
      expect(s.found, 3, reason: 'ゆっくり is missing');
      // The first 地図 is scored (as returned first); its reading is wrong.
      expect(s.readingsOk, 2);
      expect(s.meanings, (ok: 2, of: 2), reason: '机 has no printed meaning');
    });

    test(
      'sentence words: recall and precision, ignored headwords not counted',
      () {
        expect(s.sentenceWords, (ok: 1, of: 2));
        expect(s.sentencePredicted, (ok: 1, of: 2));
      },
    );

    test('extras, repeats and high-but-wrong are counted apart', () {
      expect(s.extras, 2, reason: '歩く and 窓 are in no answer list');
      expect(s.duplicates, 1);
      expect(s.highWrong, 1);
      expect(s.high, 2);
      expect(s.returned, words.length);
    });

    test(
      'a kana word scores without readings; a dictionary reading equal to the kana is fine',
      () {
        final kana = scoreExtractPage(_page, const [
          ScoredWord(headword: 'ゆっくり', readings: ['ゆっくり'], meaning: '천천히'),
        ]);
        expect(kana.found, 1);
        expect(kana.readingsOk, 1);
        expect(kana.meanings, (ok: 1, of: 1));
      },
    );

    test(
      'meanings compare without spaces, notes in brackets, or comma/period slips',
      () {
        expect(
          normalizeMeaning('(뒤에 오는 말)그다지, 별로'),
          normalizeMeaning('그다지,별로'),
        );
        expect(normalizeMeaning('이기다. 승리하다'), normalizeMeaning('이기다, 승리하다'));
        expect(normalizeMeaning('수능(시험 이름)'), normalizeMeaning('수능'));
        expect(normalizeMeaning('바람'), isNot(normalizeMeaning('바닥')));
      },
    );

    test('the table lists every page and a total', () {
      final table = ExtractScore([s]).table();
      expect(table, contains('t1'));
      expect(table, contains('TOTAL'));
    });
  });

  test('answers that list no sentence words say so', () {
    final t = ExtractTruth.fromJson({
      'format': 'general-1',
      'pages': [
        {
          'page': '10',
          'fixture': 's010',
          'kind': 'word-list',
          'scores_sentences': false,
          'vocab': [
            {
              'headword': '雨',
              'readings': ['あめ'],
              'meaning': '비',
            },
          ],
        },
      ],
    });

    expect(t.pages.single.page, '10');
    expect(t.pages.single.fixture, 's010');
    expect(t.pages.single.vocab.single.headword, '雨');
    expect(t.pages.single.vocab.single.readings, ['あめ']);
    expect(t.pages.single.vocab.single.meaning, '비');
    expect(t.pages.single.sentenceWords, isEmpty);
    expect(t.pages.single.scoresSentences, isFalse);
  });

  test('general-1 answers load, and a malformed file fails loudly', () {
    final t = ExtractTruth.fromJson({
      'format': 'general-1',
      'pages': [
        {
          'page': 'g01',
          'fixture': 'g01',
          'kind': 'box',
          'vocab': [
            {
              'headword': '料理',
              'readings': ['りょうり'],
              'meaning': '요리',
            },
            {'headword': 'ゆっくり', 'readings': <String>[], 'meaning': null},
          ],
          'sentence_words': ['朝'],
          'ignore': ['第一課'],
        },
      ],
    });
    expect(t.pages.single.vocab[1].meaning, isNull);
    expect(t.pages.single.ignore, {'第一課'});
    expect(() => ExtractTruth.fromJson({'pages': 3}), throwsFormatException);
  });

  test('scored words come from extractor words and template entries', () {
    const w = ExtractedWord(
      headword: '料理',
      origin: WordOrigin.wordList,
      readings: ['りょうり'],
      meaning: '요리',
      readingLink: PairLink(
        confidence: PairConfidence.high,
        signals: {PairSignal.inlineNotation},
      ),
      meaningLink: PairLink(
        confidence: PairConfidence.medium,
        signals: {PairSignal.hanjaReading},
      ),
    );
    final fromWord = ScoredWord.fromExtracted(w);
    expect(fromWord.confidence, PairConfidence.medium);
    expect(fromWord.meaning, '요리');

    const e = CapturedEntry(
      headword: '雨',
      readings: ['あめ'],
      pos: PartOfSpeech.noun,
      meaning: '비',
    );
    final fromEntry = ScoredWord.fromCaptured(e);
    expect(fromEntry.confidence, isNull);
    expect(fromEntry.readings, ['あめ']);
  });
}
