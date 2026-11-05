// C1, C2, C7 (general side): on every synthetic set, through the router, no
// high entry is wrong; there are at least as many high entries as measured
// when the rules were set; the values (found, readings, meanings, sentence
// words, extras) are what they were before the confidence rules.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import 'support/confidence_fixtures.dart';
import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

ExtractTruth get _general =>
    ExtractTruth.fromJson(readGeneralJson('ground_truth.json'));

ExtractTruth _rows(FixtureSet set) =>
    ExtractTruth.fromAnyJson(set.readJson('ground_truth.json'));

Future<ExtractScore> _score(
  ExtractTruth truth,
  Future<OcrScan> Function(String) load,
  CaptureRouter router,
) async => ExtractScore([
  for (final page in truth.pages)
    scoreExtractPage(page, [
      for (final e in (await router.fromScan(await load(page.fixture))).entries)
        ScoredWord.fromCaptured(e),
    ]),
]);

/// Every routed run of the synthetic sets: (name, answers, loader, router).
List<(String, ExtractTruth, Future<OcrScan> Function(String), CaptureRouter)>
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
      confidenceRouter(generalLexicon(), glossary: glossary),
    ),
  for (final glossary in [null, realGlossary()])
    (
      'traps, glossary ${glossary == null ? 'none' : 'real senses'}',
      trapTruth(),
      loadGeneralScan,
      confidenceRouter(trapLexicon(), glossary: glossary),
    ),
  for (final set in [synthetic, syntheticMlKit])
    for (final glossary in [null, realGlossary()])
      (
        '${set.name}, glossary ${glossary == null ? 'none' : 'real senses'}',
        _rows(set),
        set.loadScan,
        confidenceRouter(rowLexicon(), glossary: glossary),
      ),
];

void main() {
  test('C1 high but wrong 0 on every synthetic set, template and general '
      'routes, with and without a glossary', () async {
    for (final (name, truth, load, router) in _runs()) {
      final s = await _score(truth, load, router);
      // Printed for the score table in the test output.
      print('$name: high ${s.high}, high but wrong ${s.highWrong}');
      expect(s.highWrong, 0, reason: name);
    }
  });

  test(
    'C1 a high entry is high on every paired cell and needs no review',
    () async {
      var seen = 0;
      for (final (name, truth, load, router) in _runs()) {
        for (final page in truth.pages) {
          final draft = await router.fromScan(await load(page.fixture));
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
        confidenceRouter(generalLexicon(), glossary: realGlossary()),
      );
      print('synthetic general: high ${s.high} (was 8)');
      expect(s.high, greaterThanOrEqualTo(25));
      expect(s.highWrong, 0);
    },
  );

  test('C2 high entries: synthetic row-template 4 pages >= 22, ML Kit kind '
      '>= 10 (real dictionary values)', () async {
    final rows = await _score(
      _rows(synthetic),
      synthetic.loadScan,
      confidenceRouter(rowLexicon(), glossary: realGlossary()),
    );
    final mlKit = await _score(
      _rows(syntheticMlKit),
      syntheticMlKit.loadScan,
      confidenceRouter(rowLexicon(), glossary: realGlossary()),
    );
    print(
      'synthetic rows: high ${rows.high}, ML Kit kind: high ${mlKit.high} '
      '(both were 0)',
    );
    expect(rows.high, greaterThanOrEqualTo(22));
    expect(mlKit.high, greaterThanOrEqualTo(10));
  });

  test('C7 the general pages\' values stay as they were (only the confidence '
      'changes)', () async {
    for (final (name, glossary) in [
      ('none', null),
      ('stand-in', generalGlossary()),
      ('real senses', realGlossary()),
    ]) {
      final s = await _score(
        _general,
        loadGeneralScan,
        confidenceRouter(generalLexicon(), glossary: glossary),
      );
      expect(
        [
          s.found,
          s.readingsOk,
          s.meanings.ok,
          s.meanings.of,
          s.sentenceWords.ok,
          s.sentencePredicted.ok,
          s.sentencePredicted.of,
          s.extras,
          s.duplicates,
        ],
        [49, 49, 48, 48, 45, 38, 38, 0, 0],
        reason: name,
      );
    }
    final traps = await _score(
      trapTruth(),
      loadGeneralScan,
      confidenceRouter(trapLexicon(), glossary: realGlossary()),
    );
    expect(
      [traps.found, traps.readingsOk, traps.meanings.ok, traps.extras],
      [6, 6, 6, 0],
    );
  });

  test('C7 the row-template pages\' word scores stay as they were', () async {
    for (final (set, glossary, want) in [
      (synthetic, null, [33, 33, 31, 1, 1]),
      (synthetic, realGlossary(), [33, 33, 32, 1, 1]),
      (syntheticMlKit, null, [17, 17, 16, 1, 0]),
      (syntheticMlKit, realGlossary(), [17, 17, 16, 1, 0]),
    ]) {
      final s = await _score(
        _rows(set),
        set.loadScan,
        confidenceRouter(rowLexicon(), glossary: glossary),
      );
      expect(
        [s.found, s.readingsOk, s.meanings.ok, s.extras, s.duplicates],
        want,
        reason: '${set.name} ${glossary == null ? 'none' : 'real'}',
      );
    }
  });
}
