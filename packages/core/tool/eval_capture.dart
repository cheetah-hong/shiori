// Prints the capture score table for a folder of recorded OCR passes.
//
//   dart run tool/eval_capture.dart [--verbose] [--fixtures DIR] [--gt FILE]
//     [--stars STAR_DIR] [--star-ratios RATIO_DIR]
//
// DIR defaults to the synthetic pages (test/fixtures/synthetic). The recorded
// textbook pages are local only: --fixtures "$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3".
// --gt: answers kept elsewhere (default DIR/ground_truth.json), for folders that
// only hold OCR passes.
// --stars STAR_DIR: add STAR_DIR/<page>.star.json (or <page>.ja.json) as the
// star pass (a Japanese pass over a binarized copy of the same photo).
// --star-ratios RATIO_DIR: run the ★ check with the red-pixel shares recorded
// in RATIO_DIR/<page>.ratios.json (the device probe writes them), and print
// how many ★ it added where the truth has one and where it has none.
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
  final ratioDir = _option(args, '--star-ratios');
  final recognizer = FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  );
  Future<OcrScan> load(String fixture) async {
    final scan = await recognizer.recognize(PageImage(fixture));
    if (starDir == null) return scan;
    return OcrScan(
      japanese: scan.japanese,
      korean: scan.korean,
      stars: readStarPass(starDir, fixture),
      turned: scan.turned,
    );
  }

  final truth = GroundTruth.fromJson(
    (jsonDecode(truthFile.readAsStringSync()) as Map).cast<String, Object?>(),
  );
  final starLog = ratioDir == null ? null : _StarLog(truth, ratioDir);
  final score = await scoreCapture(
    truth: truth,
    loadScan: load,
    pipeline: CapturePipeline.standard(),
    refine: starLog?.check,
  );
  stdout.writeln(score.table(verbose: verbose));
  if (starLog != null) stdout.writeln(starLog.summary());
}

/// The ★ check with recorded shares, and the ★ it added, by the truth.
final class _StarLog {
  _StarLog(GroundTruth truth, String ratioDir)
    : tally = StarCheckTally(truth),
      meter = RecordedStarMeter(ratioDir);

  final StarCheckTally tally;
  final StarMeter meter;

  Future<CaptureDraft> check(
    CaptureDraft draft,
    OcrScan scan,
    String fixture,
  ) async {
    final checked = await checkStars(
      draft: draft,
      scan: scan,
      image: PageImage(fixture),
      meter: meter,
    );
    tally.record(fixture, draft, checked);
    return checked;
  }

  String summary() => tally.summary();
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
