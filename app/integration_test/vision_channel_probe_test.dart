// Runs the real device OCR channel on page photos and scores the result,
// like tools/reference/parse_eval.py does for recorded OCR passes.
//
//   cd app && flutter test integration_test/vision_channel_probe_test.dart -d <device> \
//     --dart-define=SHIORI_PROBE_PHOTOS=<dir with <fixture>.jpg for every page> \
//     --dart-define=SHIORI_PROBE_TRUTH=<ground_truth.json>
//     [--dart-define=SHIORI_PROBE_VERBOSE=true]   (lists wrong words: textbook text)
//
// Photos are textbook pages: keep them outside the repository (SHIORI_PRIVATE_DIR).
// Skipped when the defines are missing.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/platform_text_recognizer.dart';
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

const _photos = String.fromEnvironment('SHIORI_PROBE_PHOTOS');
const _truth = String.fromEnvironment('SHIORI_PROBE_TRUTH');

/// Per-word mistake lines quote textbook text; print them only on request.
const _verbose = bool.fromEnvironment('SHIORI_PROBE_VERBOSE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'device OCR channel reads the photos at the reference level',
    () async {
      const recognizer = PlatformTextRecognizer();
      final truth = GroundTruth.fromJson(
        (jsonDecode(File(_truth).readAsStringSync()) as Map)
            .cast<String, Object?>(),
      );
      final timings = <String>[];
      final score = await scoreCapture(
        truth: truth,
        loadScan: (fixture) async {
          final scan = await recognizer.recognize(
            PageImage('$_photos/$fixture.jpg'),
          );
          timings.add(
            '$fixture: ja ${scan.japanese.lines.length} lines '
            '${scan.japanese.elapsed.inMilliseconds} ms, '
            'ko ${scan.korean.lines.length} lines '
            '${scan.korean.elapsed.inMilliseconds} ms',
          );
          return scan;
        },
        pipeline: CapturePipeline.standard(),
      );
      // ignore: avoid_print
      print(
        'engine=${recognizer.id}\n${timings.join('\n')}\n${score.table(verbose: _verbose)}',
      );
      expect(score.total('found').ok, greaterThan(0));
    },
    skip: _photos.isEmpty || _truth.isEmpty
        ? 'set SHIORI_PROBE_PHOTOS and SHIORI_PROBE_TRUTH'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
