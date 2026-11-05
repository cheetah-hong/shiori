// The score tool with recorded ★ measurements and star passes
// (`tool/eval_capture.dart --star-ratios`, `--stars`).
import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/shiori_core.dart';
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
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('eval_capture_tool'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('--star-ratios DIR (<page>.ratios.json)', () {
    test('recorded shares change the score', () async {
      final scan = await syntheticMlKit.loadScan('m011');
      final draft = await standardPipeline().fromScan(scan);
      final cells = starCells(draft, scan);
      File('${tmp.path}/m011.ratios.json').writeAsStringSync(
        jsonEncode({
          'cells': [for (final c in cells) c.toJson()],
          'ratios': [for (final c in cells) c.no == '0013' ? 0.01 : 0.0],
        }),
      );

      final before = _totalLine(
        await _evalTool(['--fixtures', syntheticMlKit.dir]),
      );
      final after = _totalLine(
        await _evalTool([
          '--fixtures',
          syntheticMlKit.dir,
          '--star-ratios',
          tmp.path,
        ]),
      );
      expect(before, contains('important=16/18'));
      expect(before, contains('row=14/18'));
      expect(after, contains('important=17/18'));
      expect(after, contains('row=15/18'));
    });

    test('all shares below the threshold leave the score', () async {
      final scan = await syntheticMlKit.loadScan('m011');
      final draft = await standardPipeline().fromScan(scan);
      final cells = starCells(draft, scan);
      File('${tmp.path}/m011.ratios.json').writeAsStringSync(
        jsonEncode({
          'ratios': [for (final _ in cells) 0.0],
        }),
      );
      final line = _totalLine(
        await _evalTool([
          '--fixtures',
          syntheticMlKit.dir,
          '--star-ratios',
          tmp.path,
        ]),
      );
      expect(line, contains('important=16/18'));
    });
  });

  group('--stars DIR', () {
    /// A star pass per synthetic page; on s011 it shows the ★ of 0013 that
    /// the Japanese pass missed (number x + 0.187, on the reading line).
    void writeStarPasses(String suffix) {
      for (final page in ['s010', 's011', 's140', 's147']) {
        File('${tmp.path}/$page.$suffix').writeAsStringSync(
          jsonEncode({
            'engine': 'synthetic',
            'lines': [
              if (page == 's011')
                {
                  't': '★',
                  'c': 0.5,
                  'x': 0.3982,
                  'y': 0.1922,
                  'w': 0.0145,
                  'h': 0.0108,
                },
            ],
          }),
        );
      }
    }

    test('reads the probe dump name <page>.star.json', () async {
      final before = _totalLine(await _evalTool(['--fixtures', synthetic.dir]));
      writeStarPasses('star.json');
      final after = _totalLine(
        await _evalTool(['--fixtures', synthetic.dir, '--stars', tmp.path]),
      );
      expect(before, contains('important=34/35'));
      expect(after, contains('important=35/35'));
    });

    test('still reads <page>.ja.json', () async {
      writeStarPasses('ja.json');
      final after = _totalLine(
        await _evalTool(['--fixtures', synthetic.dir, '--stars', tmp.path]),
      );
      expect(after, contains('important=35/35'));
    });

    test('a page without a star pass is an error', () async {
      final r = await _evalTool([
        '--fixtures',
        synthetic.dir,
        '--stars',
        tmp.path,
      ]);
      expect(r.exitCode, isNot(0));
    });
  });
}
