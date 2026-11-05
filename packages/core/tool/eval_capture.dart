// Prints the capture score table for a folder of recorded OCR passes.
//
//   dart run tool/eval_capture.dart [--verbose] [--fixtures DIR]
//
// DIR defaults to the synthetic pages (test/fixtures/synthetic). The recorded
// textbook pages are local only: --fixtures "$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3".
// Same columns as tools/reference/parse_eval.py, so the two can be compared.
import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

Future<void> main(List<String> args) async {
  final verbose = args.contains('--verbose');
  final dirFlag = args.indexOf('--fixtures');
  final dir = dirFlag >= 0 && dirFlag + 1 < args.length
      ? args[dirFlag + 1]
      : 'test/fixtures/synthetic';

  final truthFile = File('$dir/ground_truth.json');
  if (!truthFile.existsSync()) {
    stderr.writeln('ground_truth.json not found in $dir');
    exitCode = 2;
    return;
  }
  final recognizer = FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  );
  final score = await scoreCapture(
    truth: GroundTruth.fromJson(
      (jsonDecode(truthFile.readAsStringSync()) as Map).cast<String, Object?>(),
    ),
    loadScan: (fixture) => recognizer.recognize(PageImage(fixture)),
    pipeline: CapturePipeline.standard(),
  );
  stdout.writeln(score.table(verbose: verbose));
}
