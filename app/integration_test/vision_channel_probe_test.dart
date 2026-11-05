// Runs the real device OCR channel on page photos and scores the result,
// like tools/reference/parse_eval.py does for recorded OCR passes.
//
//   cd app && flutter test integration_test/vision_channel_probe_test.dart -d <device> \
//     --dart-define=SHIORI_PROBE_PHOTOS=<dir with <fixture>.jpg for every page> \
//     --dart-define=SHIORI_PROBE_TRUTH=<ground_truth.json>
//     [--dart-define=SHIORI_PROBE_VERBOSE=true]   (lists wrong words: textbook text)
//     [--dart-define=SHIORI_PROBE_STARS=false]    (no star pass, iOS)
//     [--dart-define=SHIORI_PROBE_DUMP=<dir>]     (writes <page>.{ja,ko,star}.json there:
//                                                  recorded passes for the local regression sets)
//     [--dart-define=SHIORI_PROBE_MEASURE_STARS=true]
//                                                 (Android: ★ check on the photo after the
//                                                  first score; prints the score again, the ★
//                                                  it added and its time per page, and the
//                                                  shares as `ratios <page> {json}` lines, also
//                                                  written as <page>.ratios.json to the dump folder)
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
import 'package:shiori/adapters/platform_star_meter.dart';
import 'package:shiori/adapters/platform_text_recognizer.dart';
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

const _photos = String.fromEnvironment('SHIORI_PROBE_PHOTOS');
const _truth = String.fromEnvironment('SHIORI_PROBE_TRUTH');

/// Per-word mistake lines quote textbook text; print them only on request.
const _verbose = bool.fromEnvironment('SHIORI_PROBE_VERBOSE');
const _stars = bool.fromEnvironment('SHIORI_PROBE_STARS', defaultValue: true);
const _dump = String.fromEnvironment('SHIORI_PROBE_DUMP');
const _measureStars = bool.fromEnvironment('SHIORI_PROBE_MEASURE_STARS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'device OCR channel reads the photos at the reference level',
    () async {
      const recognizer = PlatformTextRecognizer(starPass: _stars);
      final truth = GroundTruth.fromJson(
        (jsonDecode(File(_truth).readAsStringSync()) as Map)
            .cast<String, Object?>(),
      );
      final timings = <String>[];
      final scans = <String, OcrScan>{};
      final score = await scoreCapture(
        truth: truth,
        loadScan: (fixture) async {
          // The adapter drops the channel's diagnostics; read them here.
          final watch = Stopwatch()..start();
          final payload = await PlatformTextRecognizer.defaultChannel
              .invokeMethod<String>('recognize', {
                'path': '$_photos/$fixture.jpg',
                'starPass': _stars,
              });
          watch.stop();
          final json = (jsonDecode(payload!) as Map).cast<String, Object?>();
          final scan = OcrScan.fromJson(json);
          scans[fixture] = scan;
          if (_dump.isNotEmpty) _write(fixture, scan);
          final stars = scan.stars;
          timings.add(
            '$fixture: turned ${json['turned']}°, '
            'ja ${scan.japanese.lines.length} lines '
            '${scan.japanese.elapsed.inMilliseconds} ms, '
            'ko ${scan.korean.lines.length} lines '
            '${scan.korean.elapsed.inMilliseconds} ms, '
            '${stars == null ? 'no star pass' : 'star ${stars.elapsed.inMilliseconds} ms'}, '
            'extra ${json['timing']}, total ${watch.elapsedMilliseconds} ms',
          );
          return scan;
        },
        pipeline: CapturePipeline.standard(),
      );
      // The score table is this probe's output (a test run, never shipped).
      // ignore: avoid_print
      print(
        'engine=${recognizer.id}\n${timings.join('\n')}\n${score.table(verbose: _verbose)}',
      );
      expect(score.total('found').ok, greaterThan(0));
      if (_measureStars) await _starCheck(truth, scans);
    },
    skip: _photos.isEmpty || _truth.isEmpty
        ? 'set SHIORI_PROBE_PHOTOS and SHIORI_PROBE_TRUTH'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Scores the same scans again with the ★ check on the photos (no second OCR).
Future<void> _starCheck(GroundTruth truth, Map<String, OcrScan> scans) async {
  final tally = StarCheckTally(truth);
  final lines = <String>[];
  final score = await scoreCapture(
    truth: truth,
    loadScan: (fixture) async => scans[fixture]!,
    pipeline: CapturePipeline.standard(),
    refine: (draft, scan, fixture) async {
      final meter = _RecordingMeter(const PlatformStarMeter());
      final watch = Stopwatch()..start();
      final checked = await checkStars(
        draft: draft,
        scan: scan,
        image: PageImage('$_photos/$fixture.jpg'),
        meter: meter,
      );
      watch.stop();
      tally.record(fixture, draft, checked);
      final measured = meter.measurement;
      lines.add(
        '$fixture: ${meter.cells.length} cells, '
        'channel ${measured?.elapsed.inMilliseconds ?? '-'} ms, '
        'total ${watch.elapsedMilliseconds} ms',
      );
      if (measured != null) {
        final record = jsonEncode(
          starRatiosJson(
            cells: meter.cells,
            measurement: measured,
            turned: scan.turned,
          ),
        );
        // Word numbers and shares only. Printed too: the test run removes the
        // app, and with it the dump folder, from the device.
        lines.add('ratios $fixture $record');
        if (_dump.isNotEmpty) {
          File(
            '$_dump/${starRatiosFileName(fixture)}',
          ).writeAsStringSync(record);
        }
      }
      return checked;
    },
  );
  // ignore: avoid_print
  print(
    '★ check on the photos\n${lines.join('\n')}\n${tally.summary()}\n'
    '${score.table(verbose: _verbose)}',
  );
}

/// Passes the call on and keeps what was measured.
final class _RecordingMeter implements StarMeter {
  _RecordingMeter(this.inner);

  final StarMeter inner;
  List<StarCell> cells = const [];
  StarMeasurement? measurement;

  @override
  String get id => inner.id;

  @override
  Future<StarMeasurement?> measure(
    PageImage image, {
    required List<StarCell> cells,
    required StarColor color,
    int turned = 0,
  }) async {
    this.cells = cells;
    return measurement = await inner.measure(
      image,
      cells: cells,
      color: color,
      turned: turned,
    );
  }
}

/// The passes in the fixture format (`FixtureTextRecognizer`, the eval tool).
void _write(String fixture, OcrScan scan) {
  Directory(_dump).createSync(recursive: true);
  for (final (tag, page) in [
    ('ja', scan.japanese),
    ('ko', scan.korean),
    if (scan.stars case final s?) ('star', s),
  ]) {
    File(
      '$_dump/$fixture.$tag.json',
    ).writeAsStringSync(jsonEncode(page.toJson()));
  }
}
