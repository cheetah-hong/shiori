// E5: no entry the review screen would show as high is wrong, on every
// synthetic set as the app reads it.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

Future<({int high, int highWrong})> _score(
  ExtractTruth truth,
  Future<OcrScan> Function(String) load,
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

/// The gloss stand-in plus Sino-Korean meanings of three g01 words, as a
/// real glossary also has them.
MemoryKoreanGlossary _withSinoKorean() => MemoryKoreanGlossary({
  ...generalGlossary().senses,
  '料理': [
    ['요리'],
  ],
  '旅行': [
    ['여행'],
  ],
  '地図': [
    ['지도'],
  ],
});

void main() {
  test('synthetic general pages, with and without a glossary: high but '
      'wrong 0', () async {
    final truth = ExtractTruth.fromJson(readGeneralJson('ground_truth.json'));
    for (final (name, glossary) in [
      ('none', null),
      ('stand-in', generalGlossary()),
      ('stand-in + Sino-Korean', _withSinoKorean()),
    ]) {
      final s = await _score(
        truth,
        loadGeneralScan,
        syntheticExtractor(glossary: glossary),
      );
      // Printed for the score table in the test output.
      print('general, glossary $name: high ${s.high}');
      expect(s.highWrong, 0, reason: name);
    }
    final s = await _score(
      truth,
      loadGeneralScan,
      syntheticExtractor(glossary: _withSinoKorean()),
    );
    expect(s.high, greaterThanOrEqualTo(3));
  });

  test(
    'synthetic word-book pages (plain and ML Kit): high but wrong 0',
    () async {
      for (final set in [synthetic, syntheticMlKit]) {
        final s = await _score(set.truth, set.loadScan, syntheticExtractor());
        expect(s.highWrong, 0, reason: set.name);
      }
    },
  );

  test('a high entry carries high on every paired field', () async {
    final draft = await pageDraft(
      syntheticExtractor(glossary: _withSinoKorean()),
      await loadGeneralScan('g01'),
    );
    final high = [
      for (final e in draft.entries)
        if (e.evidence?.isHigh ?? false) e,
    ];
    expect(high, isNotEmpty);
    for (final e in high) {
      for (final field in [EntryField.readings, EntryField.meaning]) {
        final f = e.evidence!.of(field);
        if (f?.confidence != null) {
          expect(f!.confidence, PairConfidence.high, reason: e.headword);
        }
      }
      expect(e.needsReview, isFalse, reason: e.headword);
    }
  });
}
