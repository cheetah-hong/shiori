// Prints the capture score table for a folder of recorded OCR passes.
//
//   dart run tool/eval_capture.dart [--verbose] [--fixtures DIR] [--gt FILE]
//
// DIR defaults to the synthetic pages (test/fixtures/synthetic). The recorded
// textbook pages are local only: --fixtures "$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3".
// --gt: answers kept elsewhere (default DIR/ground_truth.json), for folders that
// only hold OCR passes.
// --stars STAR_DIR: add STAR_DIR/<page>.ja.json as the star pass (a Japanese
// pass over a binarized copy of the same photo).
// Same columns as tools/reference/parse_eval.py, so the two can be compared.
import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

Future<void> main(List<String> args) async {
  final verbose = args.contains('--verbose');
  final dir = _option(args, '--fixtures') ?? 'test/fixtures/synthetic';
  final truthFile = File(_option(args, '--gt') ?? '$dir/ground_truth.json');
  if (!truthFile.existsSync()) {
    stderr.writeln('ground truth not found: ${truthFile.path}');
    exitCode = 2;
    return;
  }
  final starDir = _option(args, '--stars');
  final recognizer = FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  );
  Future<OcrScan> load(String fixture) async {
    final scan = await recognizer.recognize(PageImage(fixture));
    if (starDir == null) return scan;
    final starFile = File('$starDir/$fixture.ja.json');
    if (!starFile.existsSync()) {
      throw FileSystemException('no star pass for $fixture', starFile.path);
    }
    final stars = OcrPage.fromJson(
      (jsonDecode(starFile.readAsStringSync()) as Map).cast<String, Object?>(),
    );
    return OcrScan(japanese: scan.japanese, korean: scan.korean, stars: stars);
  }

  final score = await scoreCapture(
    truth: GroundTruth.fromJson(
      (jsonDecode(truthFile.readAsStringSync()) as Map).cast<String, Object?>(),
    ),
    loadScan: load,
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
