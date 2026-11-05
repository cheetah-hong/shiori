/// Recorded ★ measurements and star passes, for scoring them again offline
/// (`tool/eval_capture.dart --star-ratios`, `--stars`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/src/eval/ground_truth.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/models/page_image.dart';
import 'package:shiori_core/src/ports/star_meter.dart';

/// `<page>.ratios.json`: the cells measured and their red-pixel shares.
String starRatiosFileName(String fixture) => '$fixture.ratios.json';

Map<String, Object?> starRatiosJson({
  required List<StarCell> cells,
  required StarMeasurement measurement,
  required int turned,
}) => {
  'turned': turned,
  'ms': measurement.elapsed.inMilliseconds,
  'cells': [for (final c in cells) c.toJson()],
  'ratios': measurement.ratios,
};

/// Plays back `<dir>/<page>.ratios.json` (the image path is the fixture name).
///
/// With the measured cells in the record, shares go to the cells asked for by
/// word number, so a record made from another OCR pass of the same photo
/// still applies; a row that was not measured gets 0 (stays as read). Without
/// them the shares are taken in order.
final class RecordedStarMeter implements StarMeter {
  const RecordedStarMeter(this.dir);

  final String dir;

  @override
  String get id => 'recorded';

  @override
  Future<StarMeasurement?> measure(
    PageImage image, {
    required List<StarCell> cells,
    required StarColor color,
    int turned = 0,
  }) async {
    final file = File('$dir/${starRatiosFileName(image.path)}');
    if (!file.existsSync()) {
      throw FileSystemException(
        'no ★ measurement for ${image.path}',
        file.path,
      );
    }
    final json = jsonDecode(await file.readAsString());
    final ratios = switch (json) {
      {'ratios': final List<Object?> r} when r.every((v) => v is num) => [
        for (final v in r) (v! as num).toDouble(),
      ],
      _ => throw FormatException(
        '${file.path} needs a "ratios" list of numbers',
      ),
    };
    final recorded = switch (json) {
      {'cells': final List<Object?> c} when c.length == ratios.length => [
        for (final cell in c) cell is Map ? cell['no'] : null,
      ],
      _ => null,
    };
    if (recorded == null) return StarMeasurement(ratios);
    final byNo = {
      for (final (i, no) in recorded.indexed)
        if (no is String) no: ratios[i],
    };
    return StarMeasurement([for (final c in cells) byNo[c.no] ?? 0.0]);
  }
}

/// The star pass of [fixture] in [dir]: `<page>.star.json` (the probe dump)
/// or `<page>.ja.json` (older recordings).
OcrPage readStarPass(String dir, String fixture) {
  for (final name in ['$fixture.star.json', '$fixture.ja.json']) {
    final file = File('$dir/$name');
    if (file.existsSync()) {
      return OcrPage.fromJson(
        (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>(),
      );
    }
  }
  throw FileSystemException('no star pass for $fixture', dir);
}

/// The ★ marks a check added, sorted by the truth: where the page has a ★
/// ([rightly]) and where it has none ([wrongly]). Word numbers only.
final class StarCheckTally {
  StarCheckTally(this.truth);

  final GroundTruth truth;
  final rightly = <String>[];
  final wrongly = <String>[];

  /// Records the rows of [after] that are ★ while they were not in [before].
  void record(String fixture, CaptureDraft before, CaptureDraft after) {
    final page = truth.pages.firstWhere((p) => p.fixture == fixture);
    for (final (i, e) in after.entries.indexed) {
      if (!e.important || before.entries[i].important) continue;
      final starred = page.entries.any((g) => g.no == e.no && g.important);
      (starred ? rightly : wrongly).add('$fixture ${e.no}');
    }
  }

  String summary() =>
      '★ check: added ${rightly.length} where the truth has ★, '
      '${wrongly.length} where it has none $wrongly';
}
