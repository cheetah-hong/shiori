// Runs the real device OCR channel on page photos and scores what the word
// extractor makes of them, by headword (as tool/eval_extract.dart does for
// recorded OCR passes).
//
//   cd app && flutter test integration_test/vision_channel_probe_test.dart -d <device> \
//     --dart-define=SHIORI_PROBE_PHOTOS=<dir with <fixture>.jpg for every page> \
//     --dart-define=SHIORI_PROBE_TRUTH=<ground_truth.json, "format": "general-1">
//     [--dart-define=SHIORI_PROBE_VERBOSE=true]   (lists wrong words: textbook text)
//     [--dart-define=SHIORI_PROBE_DUMP=<dir>]     (writes <page>.{ja,ko}.json there:
//                                                  recorded passes for the local regression sets)
//
// Photos go in as they are: the channel turns sideways photos upright itself
// (EXIF, then the reading direction). Per photo it prints the turn applied and
// the time of every pass, then the score table.
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
const _dump = String.fromEnvironment('SHIORI_PROBE_DUMP');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'device OCR channel reads the photos for the word extractor',
    () async {
      const recognizer = PlatformTextRecognizer();
      final truth = ExtractTruth.fromJson(
        (jsonDecode(File(_truth).readAsStringSync()) as Map)
            .cast<String, Object?>(),
      );
      final timings = <String>[];
      final score = await scoreExtractor(
        truth: truth,
        loadScan: (fixture) async {
          // The adapter drops the channel's diagnostics; read them here.
          final watch = Stopwatch()..start();
          final payload = await PlatformTextRecognizer.defaultChannel
              .invokeMethod<String>('recognize', {
                'path': '$_photos/$fixture.jpg',
              });
          watch.stop();
          final json = (jsonDecode(payload!) as Map).cast<String, Object?>();
          final scan = OcrScan.fromJson(json);
          if (_dump.isNotEmpty) _write(fixture, scan);
          timings.add(
            '$fixture: turned ${json['turned']}°, '
            'ja ${scan.japanese.lines.length} lines '
            '${scan.japanese.elapsed.inMilliseconds} ms, '
            'ko ${scan.korean.lines.length} lines '
            '${scan.korean.elapsed.inMilliseconds} ms, '
            'extra ${json['timing']}, total ${watch.elapsedMilliseconds} ms',
          );
          return scan;
        },
        run: generalRun(GeneralExtractor()),
      );
      // The score table is this probe's output (a test run, never shipped).
      // ignore: avoid_print
      print(
        'engine=${recognizer.id}\n${timings.join('\n')}\n${score.table(verbose: _verbose)}',
      );
      expect(score.found, greaterThan(0));
    },
    skip: _photos.isEmpty || _truth.isEmpty
        ? 'set SHIORI_PROBE_PHOTOS and SHIORI_PROBE_TRUTH'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// The passes in the fixture format (`FixtureTextRecognizer`, the eval tool).
void _write(String fixture, OcrScan scan) {
  Directory(_dump).createSync(recursive: true);
  for (final (tag, page) in [('ja', scan.japanese), ('ko', scan.korean)]) {
    File(
      '$_dump/$fixture.$tag.json',
    ).writeAsStringSync(jsonEncode(page.toJson()));
  }
}
