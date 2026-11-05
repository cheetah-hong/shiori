// Prints the cells where the Dart pipeline differs from the frozen reference
// parser's output, as JSON in the shape of intended_differences.json.
//
//   dart run tool/reference_diff.dart [--fixtures DIR]
//
// DIR defaults to the synthetic pages. Each printed cell needs a reason before it
// goes into DIR/intended_differences.json (the parity test checks the list).
// The textbook folder's output quotes textbook text: keep it in that folder.
import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

Future<void> main(List<String> args) async {
  final i = args.indexOf('--fixtures');
  final dir = i >= 0 && i + 1 < args.length
      ? args[i + 1]
      : 'test/fixtures/synthetic';
  final referenceFile = File('$dir/reference_output.json');
  if (!referenceFile.existsSync()) {
    stderr.writeln('reference_output.json not found in $dir');
    exitCode = 2;
    return;
  }
  final recognizer = FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  );
  final found = await referenceDifferences(
    reference: (jsonDecode(referenceFile.readAsStringSync()) as Map)
        .cast<String, Object?>(),
    loadScan: (fixture) => recognizer.recognize(PageImage(fixture)),
    pipeline: CapturePipeline.standard(),
  );
  stdout.writeln(
    const JsonEncoder.withIndent(' ').convert({
      'differences': [for (final d in found) d.toJson()],
    }),
  );
}
