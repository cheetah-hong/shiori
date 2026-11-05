// E1–E2: each page goes to the row template only when the template clearly
// fits it; every other page (and every doubtful one) to the general extractor.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../extract/support/connect_fixtures.dart';
import '../extract/support/extract_fixtures.dart';
import '../support/fixtures.dart';

Future<CaptureDraft> _routed(FixtureSet set, String fixture) async =>
    syntheticRouter().fromScan(await set.loadScan(fixture));

const _generalSet = FixtureSet('synthetic general pages', generalDir);

void main() {
  group('E1 route per page', () {
    for (final fixture in ['s010', 's011', 's140', 's147']) {
      test('synthetic $fixture → row template', () async {
        final draft = await _routed(synthetic, fixture);

        expect(draft.route, isNotNull);
        expect(draft.route!.route, CaptureRoute.template);
        expect(draft.route!.reasons, [RouteReason.fits]);
        expect(draft.templateId, isNot(generalTemplateId));
      });
    }

    for (final fixture in ['m011', 'm140']) {
      test('synthetic ML Kit $fixture → row template', () async {
        final draft = await _routed(syntheticMlKit, fixture);

        expect(draft.route!.route, CaptureRoute.template);
      });
    }

    for (final fixture in ['g01', 'g02', 'g03', 'g05']) {
      test('synthetic general $fixture → general, with a reason', () async {
        final draft = await _routed(_generalSet, fixture);

        expect(draft.route!.route, CaptureRoute.general);
        expect(draft.route!.reasons, isNotEmpty);
        expect(draft.route!.reasons, isNot(contains(RouteReason.fits)));
        expect(draft.templateId, generalTemplateId);
        expect(draft.route!.summary, isNotEmpty);
      });
    }

    test(
      'the curled word list g04 → general: rows found, but they do not line up',
      () async {
        final draft = await _routed(_generalSet, 'g04');

        expect(draft.route!.route, CaptureRoute.general);
        expect(draft.route!.fit.entries, greaterThan(10));
        expect(
          draft.route!.reasons,
          anyOf(
            contains(RouteReason.duplicateNumbers),
            contains(RouteReason.missingMeanings),
            contains(RouteReason.missingReadings),
          ),
        );
      },
    );

    test('a page with no text at all → general (nothing fits)', () async {
      final draft = await syntheticRouter().fromScan(scan());

      expect(draft.route!.route, CaptureRoute.general);
      expect(draft.route!.reasons, contains(RouteReason.noRows));
      expect(draft.entries, isEmpty);
    });

    test(
      'recorded textbook pages (local only) → row template',
      () async {
        for (final fixture in fixturesIn(recordedTextbook.dir)) {
          final draft = await _routed(recordedTextbook, fixture);
          expect(draft.route!.route, CaptureRoute.template, reason: fixture);
        }
      },
      skip: skipUnlessPresent(recordedTextbook),
    );

    test(
      'the curled phone page (local only) → general',
      () async {
        for (final fixture in fixturesIn(recordedCurledPage.dir)) {
          final draft = await _routed(recordedCurledPage, fixture);
          expect(draft.route!.route, CaptureRoute.general, reason: fixture);
          expect(draft.route!.reasons, isNot(contains(RouteReason.fits)));
        }
      },
      skip: skipUnlessPresent(recordedCurledPage),
    );

    test(
      'pages of another textbook (local only) → general',
      () async {
        final fixtures = fixturesIn(recordedOtherBook.dir);
        expect(fixtures, hasLength(3));
        for (final fixture in fixtures) {
          final draft = await _routed(recordedOtherBook, fixture);
          expect(draft.route!.route, CaptureRoute.general, reason: fixture);
        }
      },
      skip: skipUnlessPresent(recordedOtherBook),
    );
  });

  group('E1 route decision from the template fit', () {
    TemplateFit fit({
      int entries = 12,
      int numberedRows = 12,
      int duplicateNumbers = 0,
      int missingMeanings = 0,
      int missingReadings = 0,
      int missingHeadwords = 0,
      double numberOrder = 1.0,
      bool columnsMeasured = true,
    }) => TemplateFit(
      entries: entries,
      numberedRows: numberedRows,
      duplicateNumbers: duplicateNumbers,
      missingMeanings: missingMeanings,
      missingReadings: missingReadings,
      missingHeadwords: missingHeadwords,
      numberOrder: numberOrder,
      columnsMeasured: columnsMeasured,
    );

    test('a clean fit → template', () {
      expect(chooseRoute(fit()).route, CaptureRoute.template);
    });

    test('each failed check → general with its reason', () {
      expect(chooseRoute(fit(entries: 2, numberedRows: 2)).reasons, [
        RouteReason.noRows,
      ]);
      expect(
        chooseRoute(fit(duplicateNumbers: 1)).reasons,
        contains(RouteReason.duplicateNumbers),
      );
      expect(
        chooseRoute(fit(missingMeanings: 4)).reasons,
        contains(RouteReason.missingMeanings),
      );
      expect(
        chooseRoute(fit(missingReadings: 2)).reasons,
        contains(RouteReason.missingReadings),
      );
      expect(
        chooseRoute(fit(missingHeadwords: 5)).reasons,
        contains(RouteReason.missingHeadwords),
      );
      expect(
        chooseRoute(fit(numberOrder: 0.5)).reasons,
        contains(RouteReason.numberOrder),
      );
      expect(
        chooseRoute(fit(columnsMeasured: false)).reasons,
        contains(RouteReason.columnsNotMeasured),
      );
      for (final f in [
        fit(duplicateNumbers: 1),
        fit(missingMeanings: 4),
        fit(numberOrder: 0.5),
      ]) {
        expect(chooseRoute(f).route, CaptureRoute.general);
      }
    });

    test('the decision names its numbers in Korean', () {
      final d = chooseRoute(fit(duplicateNumbers: 2, missingMeanings: 7));
      expect(d.summary, contains('범용'));
      expect(d.summary, contains('2'));
    });
  });

  group('E2 scores after routing', () {
    test(
      'pages routed to the template come out exactly as the template pipeline '
      'gives them (synthetic 31/35, ML Kit 16/18 unchanged)',
      () async {
        for (final (set, fixtures) in [
          (synthetic, ['s010', 's011', 's140', 's147']),
          (syntheticMlKit, ['m011', 'm140']),
        ]) {
          for (final fixture in fixtures) {
            final scan = await set.loadScan(fixture);
            final routed = await syntheticRouter().fromScan(scan);
            final plain = await templatePipeline().fromScan(scan);
            // Values only: a routed template page also carries evidence.
            expect(
              [for (final e in routed.entries) e.copyWith(evidence: null)],
              plain.entries,
              reason: fixture,
            );
            expect(routed.templateId, plain.templateId, reason: fixture);
            expect(routed.meta, plain.meta, reason: fixture);
          }
        }
      },
    );

    test('recorded textbook pages (local only): routed entries equal the '
        'template pipeline (Vision and ML Kit scores unchanged)', () async {
      for (final set in [recordedTextbook, recordedMlKit]) {
        if (!set.exists) continue;
        for (final fixture in fixturesIn(set.dir)) {
          final scan = await set.loadScan(fixture);
          final routed = await syntheticRouter().fromScan(scan);
          final plain = await templatePipeline().fromScan(scan);
          expect(
            [for (final e in routed.entries) e.copyWith(evidence: null)],
            plain.entries,
            reason: fixture,
          );
        }
      }
    }, skip: skipUnlessPresent(recordedTextbook));

    test(
      'the five synthetic general pages through the router: found 46/46, '
      'readings 46/46, meanings 45/46 or better, sentence words 39/39',
      () async {
        final truth = ExtractTruth.fromJson(
          readGeneralJson('ground_truth.json'),
        );
        var vocab = 0, found = 0, readings = 0, meanings = 0;
        var sentenceOk = 0, sentenceOf = 0;
        for (final page in truth.pages.where(
          (p) => ['g01', 'g02', 'g03', 'g04', 'g05'].contains(p.fixture),
        )) {
          final draft = await syntheticRouter().fromScan(
            await loadGeneralScan(page.fixture),
          );
          final score = scoreExtractPage(page, [
            for (final e in draft.entries) ScoredWord.fromCaptured(e),
          ]);
          vocab += score.vocab;
          found += score.found;
          readings += score.readingsOk;
          meanings += score.meanings.ok;
          sentenceOk += score.sentenceWords.ok;
          sentenceOf += score.sentenceWords.of;
        }
        expect(vocab, 46);
        expect(found, 46);
        expect(readings, 46);
        expect(meanings, greaterThanOrEqualTo(45));
        expect((sentenceOk, sentenceOf), (39, 39));
      },
    );
  });
}
