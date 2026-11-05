// Parity with the frozen reference parser, cell by cell.
//
// reference_output.json is the reference parser's output for the same OCR
// passes (tools/reference/dump_reference.py). The Dart parser has moved on from
// it on purpose; every cell where the two differ must be listed with a reason
// in intended_differences.json next to the fixtures. A difference that is not
// listed fails the test, and so does a listed one that no longer occurs.
// To see the current differences: dart run tool/reference_diff.dart --fixtures DIR
import 'dart:io';

import 'package:shiori_core/eval.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  _parity(synthetic);
  group(
    'recorded textbook pages (local only)',
    skip: skipUnlessPresent(recordedTextbook),
    () => _parity(recordedTextbook),
  );
}

void _parity(FixtureSet set) {
  // A skipped group still runs its body to declare its tests: read nothing then.
  if (!set.exists) {
    test('(no data: placeholder for the skipped group)', () {});
    return;
  }
  if (!File('${set.dir}/reference_output.json').existsSync()) {
    test('reference_output.json is present', () {
      fail(
        'missing ${set.dir}/reference_output.json: run '
        'python3 tools/reference/dump_reference.py --data <that folder> '
        '(for the synthetic pages: python3 tools/synthetic/make_pages.py)',
      );
    });
    return;
  }

  group(set.name, () {
    late List<CellDifference> found;
    final intended = readIntendedDifferences(set);

    setUpAll(
      () async => found = await referenceDifferences(
        reference: set.readJson('reference_output.json'),
        loadScan: set.loadScan,
        pipeline: standardPipeline(),
      ),
    );

    test('every listed difference has a reason', () {
      expect([
        for (final d in intended)
          if (d.reason.trim().isEmpty) '$d',
      ], isEmpty);
    });

    test('no cell differs from the reference output unless listed', () {
      final r = compareWithIntended(found, intended);
      expect(
        r.unexpected.map((d) => '$d'),
        isEmpty,
        reason:
            'cells that changed without being listed in '
            '${set.dir}/$intendedDifferencesFile',
      );
    });

    test('every listed difference still occurs', () {
      final r = compareWithIntended(found, intended);
      expect(
        r.stale.map((d) => '$d'),
        isEmpty,
        reason: 'listed in $intendedDifferencesFile but no longer different',
      );
    });
  });
}
