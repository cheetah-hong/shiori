// The extraction score tool.
import 'dart:io';

import 'package:test/test.dart';

import '../support/fixtures.dart';

Future<ProcessResult> _evalTool(List<String> args) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'tool/eval_extract.dart', ...args],
);

void main() {
  test('synthetic general pages: a row per page and a total', () async {
    final r = await _evalTool([]);

    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    final out = r.stdout as String;
    expect(out, contains('== general'));
    for (final page in ['g01', 'g02', 'g03', 'g04', 'g05']) {
      expect(out, contains(page));
    }
    expect(RegExp('^TOTAL', multiLine: true).allMatches(out), hasLength(1));
  });

  test('the template flags are gone', () async {
    for (final flag in ['--template', '--routed']) {
      final r = await _evalTool([flag]);
      expect(r.stdout as String, isNot(contains('== template')), reason: flag);
      expect(r.stdout as String, isNot(contains('== routed')), reason: flag);
    }
  });

  test('the word-book pages are scored by headword', () async {
    final r = await _evalTool(['--fixtures', synthetic.dir]);

    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout as String, contains('TOTAL'));
  });

  test('a missing answer file is a usage error', () async {
    final r = await _evalTool(['--gt', 'no/such/file.json']);

    expect(r.exitCode, 2);
  });
}
