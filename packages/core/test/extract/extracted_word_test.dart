// Result model: the weakest link decides, and the template entry conversion.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  const high = PairLink(
    confidence: PairConfidence.high,
    signals: {PairSignal.inlineNotation},
  );
  const low = PairLink(
    confidence: PairConfidence.low,
    signals: {PairSignal.position},
  );

  test('pair confidence is the weakest link; nothing paired is low', () {
    const both = ExtractedWord(
      headword: '料理',
      origin: WordOrigin.wordList,
      readingLink: high,
      meaningLink: low,
    );
    const readingOnly = ExtractedWord(
      headword: '料理',
      origin: WordOrigin.wordList,
      readingLink: high,
    );
    const none = ExtractedWord(headword: '料理', origin: WordOrigin.wordList);

    expect(both.pairConfidence, PairConfidence.low);
    expect(readingOnly.pairConfidence, PairConfidence.high);
    expect(none.pairConfidence, PairConfidence.low);
  });

  test('toCapturedEntry: badge from JMdict codes, example, review flags', () {
    const w = ExtractedWord(
      headword: '行く',
      origin: WordOrigin.sentence,
      readings: ['いく'],
      partsOfSpeech: ['v5k-s', 'vi', 'aux-v'],
      readingSource: FieldSource.dictionary,
      example: WordExample(ja: '学校に行きました。', ko: '학교에 갔습니다.'),
    );

    final e = w.toCapturedEntry();

    expect(e.no, isNull);
    expect(e.headword, '行く');
    expect(e.readings, ['いく']);
    expect(e.pos, PartOfSpeech.verb);
    expect(e.example, const Example(ja: '学校に行きました。', ko: '학교에 갔습니다.'));
    expect(e.statusOf(EntryField.meaning), FieldStatus.needsReview);
    expect(e.statusOf(EntryField.readings), FieldStatus.inferred);
  });

  test('a meaning paired with high confidence is not flagged', () {
    const w = ExtractedWord(
      headword: '料理',
      origin: WordOrigin.wordList,
      readings: ['りょうり'],
      meaning: '요리',
      partsOfSpeech: ['n', 'vs'],
      readingSource: FieldSource.photo,
      meaningSource: FieldSource.photo,
      readingLink: high,
      meaningLink: PairLink(
        confidence: PairConfidence.high,
        signals: {PairSignal.hanjaReading, PairSignal.koreanGloss},
      ),
    );

    final e = w.toCapturedEntry();

    expect(e.pos, PartOfSpeech.noun);
    expect(e.issues, isEmpty);
  });

  test('POS badges for the JMdict classes', () {
    expect(partOfSpeechOf(['adj-i']), PartOfSpeech.iAdjective);
    expect(partOfSpeechOf(['adj-na']), PartOfSpeech.naAdjective);
    expect(partOfSpeechOf(['adv']), PartOfSpeech.adverb);
    expect(partOfSpeechOf(['vs', 'n']), PartOfSpeech.noun);
    expect(partOfSpeechOf(['prt']), PartOfSpeech.particle);
    expect(partOfSpeechOf([]), isNull);
  });
}
