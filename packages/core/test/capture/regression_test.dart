// Regression gate: the Dart capture pipeline scored against hand-made ground
// truth must stay at the level of the reference parser (OCR_TEST.md).
import 'package:shiori_core/eval.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

Future<CaptureScore> _score(FixtureSet set) async {
  final score = await scoreCapture(
    truth: GroundTruth.fromJson(set.readJson('ground_truth.json')),
    loadScan: set.loadScan,
    pipeline: standardPipeline(),
  );
  // Printed so `dart test` output doubles as the score table.
  print('${set.name}\n${score.table()}');
  return score;
}

/// Template per page as written in the ground truth (`list` / `entry`).
Map<int, String> _templates(FixtureSet set) => {
  for (final p
      in (set.readJson('ground_truth.json')['pages']! as List)
          .cast<Map<String, Object?>>())
    p['page']! as int: 'vocab.${p['template']}',
};

void main() {
  group('synthetic pages', () {
    late CaptureScore score;
    setUpAll(() async => score = await _score(synthetic));

    // Every miss below is built into the pages on purpose
    // (tools/synthetic/make_pages.py), so the totals are exact.
    test('finds every word (35/35)', () {
      expect(score.total('found'), (ok: 35, of: 35));
    });

    test('per-field totals', () {
      expect(score.total('headword'), (ok: 33, of: 35)); // two unread kanji
      expect(score.total('readings'), (ok: 35, of: 35));
      expect(score.total('pos'), (ok: 35, of: 35));
      expect(score.total('meaning'), (ok: 33, of: 35)); // misread + unread
      expect(score.total('important'), (ok: 34, of: 35)); // one ★ not read
      expect(score.total('row'), (ok: 30, of: 35));
    });

    test('examples: all read except the one OCR missed (10/11)', () {
      expect(score.total('ex_ja'), (ok: 10, of: 11));
      expect(score.total('ex_ko'), (ok: 10, of: 11));
    });

    test('one silent error; the other wrong cells are flagged', () {
      expect(score.silentErrors, 1);
      expect(score.flaggedWrong, 3);
      expect(score.flaggedOk, 4, reason: 'the four auto-corrected headwords');
    });

    test('DAY, title and page read on every page (4/4)', () {
      expect(score.pages.where((p) => p.metaOk).length, 4);
    });

    test('picks the list or entry layout as the ground truth says', () {
      expect({
        for (final p in score.pages) p.page: p.templateId,
      }, _templates(synthetic));
    });
  });

  group(
    'recorded textbook pages (local only)',
    skip: skipUnlessPresent(recordedTextbook),
    () {
      late CaptureScore score;
      setUpAll(() async => score = await _score(recordedTextbook));

      test('finds every word (59/59)', () {
        expect(score.total('found'), (ok: 59, of: 59));
      });

      test('whole rows correct ≥ 52/59', () {
        expect(score.total('row').ok, greaterThanOrEqualTo(52));
      });

      test('examples read in Japanese and Korean (12/12)', () {
        expect(score.total('ex_ja'), (ok: 12, of: 12));
        expect(score.total('ex_ko'), (ok: 12, of: 12));
      });

      test('at most one silent error in headword, readings or meaning', () {
        expect(score.silentErrors, lessThanOrEqualTo(1));
      });

      test('DAY, title and page read on every page (5/5)', () {
        expect(score.pages.where((p) => p.metaOk).length, 5);
      });

      test('per-field totals do not fall below the reference', () {
        expect(score.total('headword').ok, greaterThanOrEqualTo(57));
        expect(score.total('readings').ok, greaterThanOrEqualTo(59));
        expect(score.total('pos').ok, greaterThanOrEqualTo(59));
        expect(score.total('meaning').ok, greaterThanOrEqualTo(57));
        expect(score.total('important').ok, greaterThanOrEqualTo(56));
      });

      test('picks the list or entry layout as the ground truth says', () {
        expect({
          for (final p in score.pages) p.page: p.templateId,
        }, _templates(recordedTextbook));
      });
    },
  );
}
