// E3: the Korean glossary block plugged into the general extractor — a
// content signal for pairing, and the meaning of words the page gives none.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

/// Four rows: 運動 and 食べる with printed meanings, 部屋 and 書く with none.
OcrScan _rows() => scan(
  ja: [
    line('運動', 0.10, 0.10),
    line('うんどう', 0.25, 0.10),
    line('食べる', 0.10, 0.20),
    line('たべる', 0.25, 0.20),
    line('部屋', 0.10, 0.30),
    line('へや', 0.25, 0.30),
    line('書く', 0.10, 0.40),
    line('かく', 0.25, 0.40),
  ],
  ko: [line('운동', 0.45, 0.10), line('먹다', 0.45, 0.20)],
);

MemoryKoreanGlossary _glossary() => MemoryKoreanGlossary({
  '運動': [
    ['운동'],
  ],
  '食べる': [
    ['먹다'],
  ],
  '部屋': [
    ['방'],
  ],
  '書く': [
    ['쓰다'],
    ['그리다'],
  ],
});

ExtractedWord _word(ExtractionResult r, String headword) =>
    r.words.singleWhere((w) => w.headword == headword);

void main() {
  late ExtractionResult result;

  setUp(() async {
    result = await GeneralExtractor(
      lexicon: testLexicon(),
      koreanGlossary: _glossary(),
    ).extract(_rows());
  });

  test('運動 ↔ 운동: Korean reading of the kanji and the glossary → high', () {
    final w = _word(result, '運動');

    expect(w.meaning, '운동');
    expect(w.meaningSource, FieldSource.photo);
    expect(w.meaningLink!.confidence, PairConfidence.high);
    expect(
      w.meaningLink!.signals,
      containsAll([PairSignal.hanjaReading, PairSignal.koreanGloss]),
    );
  });

  test('食べる ↔ 먹다: the glossary alone → medium or better', () {
    final w = _word(result, '食べる');

    expect(w.meaning, '먹다');
    expect(w.meaningLink!.signals, contains(PairSignal.koreanGloss));
    expect(
      w.meaningLink!.confidence.index,
      greaterThanOrEqualTo(PairConfidence.medium.index),
    );
  });

  test('部屋 with no meaning on the page: 방 from the dictionary', () {
    final w = _word(result, '部屋');

    expect(w.meaning, '방');
    expect(w.meaningSource, FieldSource.dictionary);
    // A meaning the page did not pair is never high.
    expect(w.pairConfidence, isNot(PairConfidence.high));

    final entry = w.toCapturedEntry(fragments: result.fragments);
    expect(entry.meaning, '방');
    expect(
      entry.evidence!.of(EntryField.meaning)!.source,
      FieldSource.dictionary,
    );
    expect(entry.statusOf(EntryField.meaning), isNot(FieldStatus.needsReview));
  });

  test('a word with two senses: the first is the meaning, the second a '
      'candidate', () {
    final w = _word(result, '書く');

    expect(w.meaning, '쓰다');
    expect(w.meaningSource, FieldSource.dictionary);
    expect(w.meaningCandidates, contains('그리다'));
    expect(w.meaningCandidates, isNot(contains('쓰다')));

    final entry = w.toCapturedEntry(fragments: result.fragments);
    expect(entry.evidence!.of(EntryField.meaning)!.candidates, contains('그리다'));
  });

  test('without a glossary nothing is filled', () async {
    final r = await GeneralExtractor(lexicon: testLexicon()).extract(_rows());

    expect(_word(r, '部屋').meaning, isNull);
    expect(_word(r, '運動').meaningLink!.confidence, isNot(PairConfidence.high));
  });

  test(
    'a glossary that throws leaves the meanings as the page gave them',
    () async {
      final r = await GeneralExtractor(
        lexicon: testLexicon(),
        koreanGlossary: _ThrowingGlossary(),
      ).extract(_rows());

      expect(_word(r, '運動').meaning, '운동');
      expect(_word(r, '部屋').meaning, isNull);
    },
  );
}

final class _ThrowingGlossary implements KoreanGlossary {
  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
  }) => Future.error(const FormatException('damaged glossary file'));

  @override
  List<GlossarySourceInfo> get sources => const [];
}
