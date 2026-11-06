// A3: a clean word-list page whose checkboxes OCR glued to the headwords
// (`OD机`, `ー傘`, `ON`) fits the row template on every other check; the
// template's headword cells are broken, so the page goes to the general
// extractor with the reason.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../extract/support/connect_fixtures.dart';
import '../extract/support/extract_fixtures.dart';
import '../support/fixtures.dart';

const _generalSet = FixtureSet('synthetic general pages', generalDir);

TemplateFit _fit({int entries = 15, int markedHeadwords = 0}) => TemplateFit(
  entries: entries,
  numberedRows: entries,
  duplicateNumbers: 0,
  missingMeanings: 0,
  missingReadings: 0,
  missingHeadwords: 0,
  numberOrder: 1.0,
  columnsMeasured: true,
  markedHeadwords: markedHeadwords,
);

void main() {
  group('A3 route of the marked word list (c01)', () {
    test('every other check fits; the marked headwords send it to the '
        'general extractor', () async {
      final scan = await _generalSet.loadScan('c01');
      final draft = await syntheticRouter(
        glossary: generalGlossary(),
      ).fromScan(scan);

      expect(draft.route!.route, CaptureRoute.general);
      expect(draft.route!.reasons, [RouteReason.markedHeadwords]);
      expect(draft.route!.fit.markedHeadwords, 4);
      expect(draft.route!.fit.entries, 10);
      expect(draft.route!.summary, contains('표제어 앞 자국 4/10'));
      expect(draft.templateId, generalTemplateId);
    });

    test('the general extractor reads the page better than the template '
        'would', () async {
      final scan = await _generalSet.loadScan('c01');
      final truth = ExtractTruth.fromJson(
        readGeneralJson('ground_truth_android.json'),
      ).pages.singleWhere((p) => p.fixture == 'c01');
      final draft = await syntheticRouter(
        glossary: generalGlossary(),
      ).fromScan(scan);
      final s = scoreExtractPage(truth, [
        for (final e in draft.entries) ScoredWord.fromCaptured(e),
      ]);
      print(
        'c01 routed: ${s.found}/${s.vocab} meaning ${s.meanings.ok}/'
        '${s.meanings.of} extras ${s.extras} ${s.mistakes}',
      );
      // 庭: nothing but `ON` is left of its headword cell.
      expect(s.found, greaterThanOrEqualTo(s.vocab - 1));
      expect(s.meanings.ok, s.found);
      expect(s.extras, lessThanOrEqualTo(1));
      expect(s.highWrong, 0);
      expect(s.extraHigh, 0);
      for (final e in draft.entries) {
        expect(e.headword, isNot(startsWith('O')), reason: e.headword);
        expect(e.headword, isNot(startsWith('ー')), reason: e.headword);
      }
    });

    test('the template measures the marked rows of its raw headword '
        'cells', () async {
      final scan = await _generalSet.loadScan('c01');
      final attempt = templatePipeline().attempt(scan);
      final fit = measureTemplateFit(attempt.prepared, attempt.result);
      expect(fit.markedHeadwords, 4);
    });
  });

  group('A3 marked headwords in the route decision', () {
    test('two marked rows and at least a tenth of the rows → general', () {
      final d = chooseRoute(_fit(markedHeadwords: 2));
      expect(d.route, CaptureRoute.general);
      expect(d.reasons, [RouteReason.markedHeadwords]);
    });

    test('one marked row is a misread, not the page → template', () {
      expect(
        chooseRoute(_fit(markedHeadwords: 1)).route,
        CaptureRoute.template,
      );
    });

    test('two marked rows of thirty (under a tenth) → template', () {
      expect(
        chooseRoute(_fit(entries: 30, markedHeadwords: 2)).route,
        CaptureRoute.template,
      );
    });

    test('a fit without the count (older callers) has none', () {
      const fit = TemplateFit(
        entries: 12,
        numberedRows: 12,
        duplicateNumbers: 0,
        missingMeanings: 0,
        missingReadings: 0,
        missingHeadwords: 0,
        numberOrder: 1,
        columnsMeasured: true,
      );
      expect(fit.markedHeadwords, 0);
      expect(chooseRoute(fit).route, CaptureRoute.template);
    });
  });

  group('A3 which headword cells count as marked', () {
    for (final (cell, marked) in [
      ('OD机', true),
      ('OL（お）はし', true),
      ('ー有名だ', true),
      ('ロ口机', true),
      ('□机', true),
      ('ON', true),
      ('LOD', true),
      // one glyph alone is a misread headword (口 as ロ, 一 as ー, 力 as カ)
      ('ロ', false),
      ('ー', false),
      ('カ', false),
      ('+', false),
      ('机', false),
      ('タ日', false),
      ('ロッカー', false),
      ('口座', false),
      ('Tシャツ', false),
      ('ロロロ', true),
      ('', false),
    ]) {
      test('"$cell" → $marked', () {
        expect(isMarkedHeadword(cell), marked);
      });
    }
  });

  group('A3 route results of the other synthetic pages hold', () {
    for (final (set, fixture) in [
      (synthetic, 's010'),
      (synthetic, 's011'),
      (synthetic, 's140'),
      (synthetic, 's147'),
      (syntheticMlKit, 'm011'),
      (syntheticMlKit, 'm140'),
    ]) {
      test('$fixture → template, no marked rows', () async {
        final draft = await syntheticRouter().fromScan(
          await set.loadScan(fixture),
        );
        expect(draft.route!.route, CaptureRoute.template);
        expect(draft.route!.fit.markedHeadwords, 0);
      });
    }
  });
}
