// The score tool prints the same totals as the regression tests, without a ★
// column.
import 'dart:io';

import 'package:test/test.dart';

import '../support/fixtures.dart';

Future<ProcessResult> _evalTool(List<String> args) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'tool/eval_capture.dart', ...args],
);

final RegExp _total = RegExp(r'^TOTAL .*$', multiLine: true);

String _totalLine(ProcessResult r) {
  expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  return _total.firstMatch(r.stdout as String)!.group(0)!;
}

void main() {
  test('synthetic pages: 31/35 rows, no ★ column', () async {
    final r = await _evalTool(['--fixtures', synthetic.dir]);
    final line = _totalLine(r);
    expect(line, contains('row=31/35'));
    expect(line, isNot(contains('important')));
    expect(r.stdout as String, isNot(contains('star')));
  });

  test('synthetic ML Kit pages: 16/18 rows', () async {
    final line = _totalLine(
      await _evalTool(['--fixtures', syntheticMlKit.dir]),
    );
    expect(line, contains('row=16/18'));
    expect(line, isNot(contains('important')));
  });

  test('a missing ground truth is a usage error', () async {
    final tmp = Directory.systemTemp.createTempSync('eval_capture_tool');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final r = await _evalTool(['--fixtures', tmp.path]);
    expect(r.exitCode, 2);
  });
}
