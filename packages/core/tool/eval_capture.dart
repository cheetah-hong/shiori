// Prints the capture score table for a folder of recorded OCR passes.
//
//   dart run tool/eval_capture.dart [--verbose] [--fixtures DIR] [--gt FILE]
//
// DIR defaults to the synthetic pages (test/fixtures/synthetic). The recorded
// textbook pages are local only: --fixtures "$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3".
// --gt: answers kept elsewhere (default DIR/ground_truth.json), for folders that
// only hold OCR passes.
// Same columns as tools/reference/parse_eval.py, so the two can be compared.
import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

Future<void> main(List<String> args) async {
  final removed = [
    for (final o in const ['--stars', '--star-ratios'])
      if (args.contains(o)) o,
  ];
  if (removed.isNotEmpty) {
    stderr.writeln(
      '${removed.join(', ')}: removed (the textbook ★ is no longer read)',
    );
    exitCode = 2;
    return;
  }
  final verbose = args.contains('--verbose');
  final dir = _option(args, '--fixtures') ?? 'test/fixtures/synthetic';
  final truthFile = File(_option(args, '--gt') ?? '$dir/ground_truth.json');
  if (!truthFile.existsSync()) {
    stderr.writeln('ground truth not found: ${truthFile.path}');
    exitCode = 2;
    return;
  }
  final recognizer = FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  );
  final truth = GroundTruth.fromJson(
    (jsonDecode(truthFile.readAsStringSync()) as Map).cast<String, Object?>(),
  );
  final score = await scoreCapture(
    truth: truth,
    loadScan: (fixture) => recognizer.recognize(PageImage(fixture)),
    pipeline: CapturePipeline.standard(),
  );
  stdout.writeln(score.table(verbose: verbose));
}

/// The value after [name]; exits with a usage error when it is missing.
String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0) return null;
  if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
    stderr.writeln('$name needs a value');
    exit(2);
  }
  return args[i + 1];
}
