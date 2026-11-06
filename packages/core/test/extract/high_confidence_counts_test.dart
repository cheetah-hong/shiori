// C1, C2, C7, D1, D2: on every synthetic set, through the capture the app
// uses (every page read by the word extractor), no high entry is wrong;
// there are at least as many high entries as the lower bounds; the values
// (found, readings, meanings, sentence words, extras) hold.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import 'support/confidence_fixtures.dart';
import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

ExtractTruth get _general =>
    ExtractTruth.fromJson(readGeneralJson('ground_truth.json'));

ExtractTruth _rows(FixtureSet set) => set.truth;

Future<ExtractScore> _score(
  ExtractTruth truth,
  Future<OcrScan> Function(String) load,
  GeneralExtractor extractor,
) async => ExtractScore([
  for (final page in truth.pages)
    scoreExtractPage(page, [
      for (final e in (await pageDraft(
        extractor,
        await load(page.fixture),
      )).entries)
        ScoredWord.fromCaptured(e),
    ]),
]);

/// Every run of the synthetic sets: (name, answers, loader, extractor).
List<(String, ExtractTruth, Future<OcrScan> Function(String), GeneralExtractor)>
_runs() => [
  for (final (name, glossary) in [
    ('none', null),
    ('stand-in', generalGlossary()),
    ('real senses', realGlossary()),
  ])
    (
      'general, glossary $name',
      _general,
      loadGeneralScan,
      confidenceExtractor(generalLexicon(), glossary: glossary),
    ),
  for (final glossary in [null, realGlossary()])
    (
      'traps, glossary ${glossary == null ? 'none' : 'real senses'}',
      trapTruth(),
      loadGeneralScan,
      confidenceExtractor(trapLexicon(), glossary: glossary),
    ),
  for (final set in [synthetic, syntheticMlKit])
    for (final glossary in [null, realGlossary()])
      (
        '${set.name}, glossary ${glossary == null ? 'none' : 'real senses'}',
        _rows(set),
        set.loadScan,
        confidenceExtractor(rowLexicon(), glossary: glossary),
      ),
];

void main() {
  test('C1 high but wrong 0 on every synthetic set, with and without a '
      'glossary', () async {
    for (final (name, truth, load, extractor) in _runs()) {
      final s = await _score(truth, load, extractor);
      // Printed for the score table in the test output.
      print('$name: high ${s.high}, high but wrong ${s.highWrong}');
      expect(s.highWrong, 0, reason: name);
    }
  });

  test(
    'C1 a high entry is high on every paired cell and needs no review',
    () async {
      var seen = 0;
      for (final (name, truth, load, extractor) in _runs()) {
        for (final page in truth.pages) {
          final draft = await pageDraft(extractor, await load(page.fixture));
          for (final e in draft.entries) {
            if (!(e.evidence?.isHigh ?? false)) continue;
            seen++;
            expect(e.meaning.trim(), isNotEmpty, reason: '$name ${e.headword}');
            for (final field in [EntryField.readings, EntryField.meaning]) {
              final f = e.evidence!.of(field);
              if (f != null) {
                expect(
                  f.confidence,
                  PairConfidence.high,
                  reason: '$name ${e.headword} ${field.name}',
                );
              }
            }
            expect(e.needsReview, isFalse, reason: '$name ${e.headword}');
          }
        }
      }
      expect(seen, greaterThan(0));
    },
  );

  test(
    'C2 high entries: synthetic general 6 pages >= 25 (real senses)',
    () async {
      final s = await _score(
        _general,
        loadGeneralScan,
        confidenceExtractor(generalLexicon(), glossary: realGlossary()),
      );
      print('synthetic general: high ${s.high} (was 8)');
      expect(s.high, greaterThanOrEqualTo(25));
      expect(s.highWrong, 0);
    },
  );

  test('D1 D2 high entries: synthetic word-book 4 pages >= 21, ML Kit kind '
      '>= 10 (real dictionary values)', () async {
    final rows = await _score(
      _rows(synthetic),
      synthetic.loadScan,
      confidenceExtractor(rowLexicon(), glossary: realGlossary()),
    );
    final mlKit = await _score(
      _rows(syntheticMlKit),
      syntheticMlKit.loadScan,
      confidenceExtractor(rowLexicon(), glossary: realGlossary()),
    );
    print(
      'synthetic word book: high ${rows.high}, ML Kit kind: high '
      '${mlKit.high}',
    );
    expect(rows.high, greaterThanOrEqualTo(21));
    expect(rows.highWrong, 0);
    expect(mlKit.high, greaterThanOrEqualTo(10));
    expect(mlKit.highWrong, 0);
  });

  test('C7 the general pages\' values stay as they were (only the confidence '
      'changes)', () async {
    List<int> values(ExtractScore s) => [
      s.found,
      s.readingsOk,
      s.meanings.ok,
      s.meanings.of,
      s.sentenceWords.ok,
      s.sentencePredicted.ok,
      s.sentencePredicted.of,
      s.extras,
      s.duplicates,
    ];
    // g01–g06 as when the confidence rules were set; the whole set also has
    // the word-list pages g10–g11. Only the gloss stand-in is read backwards
    // (it knows the readings of its words): without it the misread 箱 is not
    // read back (one word fewer, its kana an extra).
    const firstPages = {'g01', 'g02', 'g03', 'g04', 'g05', 'g06'};
    for (final (name, glossary, whole) in [
      ('none', null, [69, 69, 67, 67, 54, 44, 44, 1, 0]),
      ('stand-in', generalGlossary(), [70, 70, 68, 68, 54, 44, 44, 0, 0]),
      ('real senses', realGlossary(), [69, 69, 67, 67, 54, 44, 44, 1, 0]),
    ]) {
      final s = await _score(
        _general,
        loadGeneralScan,
        confidenceExtractor(generalLexicon(), glossary: glossary),
      );
      expect(
        values(
          ExtractScore([
            for (final p in s.pages)
              if (firstPages.contains(p.page)) p,
          ]),
        ),
        [49, 49, 48, 48, 45, 38, 38, 0, 0],
        reason: '$name, g01–g06',
      );
      expect(values(s), whole, reason: name);
    }
    final traps = await _score(
      trapTruth(),
      loadGeneralScan,
      confidenceExtractor(trapLexicon(), glossary: realGlossary()),
    );
    expect(
      [traps.found, traps.readingsOk, traps.meanings.ok, traps.extras],
      [6, 6, 6, 0],
    );
  });

  test('D1 D2 the word-book pages, read by the word extractor with a '
      'glossary that reads backwards (as the app\'s does), score at least '
      'what the row templates did (found 33/35 and 17/18, one wrong meaning '
      'at most, extras and duplicates two at most)', () async {
    for (final (set, glossary, found) in [
      (synthetic, realReverseGlossary(), 33),
      (syntheticMlKit, realReverseGlossary(), 17),
    ]) {
      final s = await _score(
        _rows(set),
        set.loadScan,
        confidenceExtractor(rowLexicon(), glossary: glossary),
      );
      final why = set.name;
      print(
        '$why: found ${s.found}, readings ${s.readingsOk}, meanings '
        '${s.meanings.ok}/${s.meanings.of}, extras ${s.extras}, '
        'duplicates ${s.duplicates}, high ${s.high}',
      );
      expect(s.found, greaterThanOrEqualTo(found), reason: why);
      expect(s.readingsOk, s.found, reason: why);
      expect(s.meanings.of - s.meanings.ok, lessThanOrEqualTo(1), reason: why);
      // The row templates gave the two rows OCR read no headword of as one
      // extra and one duplicate; the extractor gives their kana.
      expect(s.extras + s.duplicates, lessThanOrEqualTo(2), reason: why);
      expect(s.highWrong, 0, reason: why);
    }
  });
}
