// The extraction score tool: general extractor and row template side by side.
import 'dart:io';

import 'package:test/test.dart';

import '../support/fixtures.dart';

Future<ProcessResult> _evalTool(List<String> args) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'tool/eval_extract.dart', ...args],
);

void main() {
  test(
    'synthetic general pages: a row per page and a total for both ways',
    () async {
      final r = await _evalTool(['--template']);

      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      final out = r.stdout as String;
      expect(out, contains('== general'));
      expect(out, contains('== template'));
      for (final page in ['g01', 'g02', 'g03', 'g04', 'g05']) {
        expect(out, contains(page));
      }
      expect(RegExp('^TOTAL', multiLine: true).allMatches(out), hasLength(2));
    },
  );

  test('template answers (legacy format) are scored by headword', () async {
    final r = await _evalTool(['--fixtures', synthetic.dir]);

    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout as String, contains('TOTAL'));
  });

  test('a missing answer file is a usage error', () async {
    final r = await _evalTool(['--gt', 'no/such/file.json']);

    expect(r.exitCode, 2);
  });
}
