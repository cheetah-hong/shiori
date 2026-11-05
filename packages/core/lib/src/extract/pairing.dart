/// Costs for pairing fragments: content evidence first, placement second.
///
/// Every cost is `1 − Σ weight·signal`, so lower is better and a pair with no
/// evidence costs 1. A row is left unpaired at [PairWeights.readingUnmatched]
/// or [PairWeights.meaningUnmatched]. Distances are measured in the
/// headword's line heights, so the same numbers work for any photo size.
library;

import 'dart:math' as math;

import 'package:shiori_core/src/extract/fragment.dart';

/// Weights and thresholds of the pairing costs (chosen on the synthetic set,
/// docs/extraction.md).
final class PairWeights {
  const PairWeights({
    this.readingDictionary = 0.6,
    this.readingPosition = 0.4,
    this.readingUnmatched = 0.8,
    this.minReadingPosition = 0.5,
    this.meaningHanja = 0.5,
    this.meaningGloss = 0.5,
    this.meaningPosition = 0.4,
    this.meaningUnmatched = 0.9,
    this.minMeaningPosition = 0.3,
    this.rowTolerance = 6.0,
    this.translationPosition = 0.8,
    this.translationUnmatched = 0.7,
    this.unconfirmedPenalty = 0.2,
  });

  final double readingDictionary;
  final double readingPosition;
  final double readingUnmatched;

  /// A reading with no dictionary support needs at least this placement.
  final double minReadingPosition;

  final double meaningHanja;
  final double meaningGloss;
  final double meaningPosition;
  final double meaningUnmatched;

  /// A meaning with no content evidence needs at least this placement.
  final double minMeaningPosition;

  /// Line heights of vertical offset at which a same-row placement scores 0.
  final double rowTolerance;

  final double translationPosition;
  final double translationUnmatched;

  /// Added to the meaning cost of a kanji headword read at the engine's
  /// lowest confidence that no reading confirms (placement only).
  final double unconfirmedPenalty;
}

double _xOverlap(Fragment a, Fragment b) =>
    math.min(a.right, b.right) - math.max(a.x, b.x);

/// How well [reading] sits as the reading of [head] (0..1): to its right on
/// the same row, as furigana right above, or right below.
double readingPlacement(Fragment head, Fragment reading) {
  final h = head.height;
  final minWidth = math.min(head.width, reading.width);
  var best = 0.0;
  final dx = (reading.x - head.right) / h;
  final dy = (reading.cy - head.cy).abs() / h;
  if (dx >= -0.5 && dy <= 1.5) {
    final far = dx <= 15 ? 1.0 : math.max(0.0, 1 - (dx - 15) / 15);
    best = math.max(best, (1 - dy / 1.5) * far);
  }
  final above = head.y - reading.bottom;
  if (above >= -0.4 * h &&
      above <= 1.0 * h &&
      _xOverlap(head, reading) >= 0.5 * minWidth) {
    best = math.max(best, 0.9);
  }
  final below = reading.y - head.bottom;
  if (below >= -0.4 * h &&
      below <= 1.0 * h &&
      _xOverlap(head, reading) >= 0.3 * minWidth) {
    best = math.max(best, 0.6);
  }
  return best;
}

/// How well [meaning] sits as the meaning of [item] (0..1). [slope] is the
/// row's tilt (page y per page x) estimated from the item's printed reading:
/// on a curled page the meaning column is lower or higher than the headword
/// by slope × distance.
double meaningPlacement(
  Fragment item,
  Fragment meaning, {
  double slope = 0,
  double rowTolerance = 6.0,
}) {
  final h = item.height;
  var best = 0.0;
  if (meaning.x >= item.x + 0.5 * item.width) {
    final predicted = item.cy + slope * (meaning.cx - item.cx);
    final dy = (meaning.cy - predicted).abs() / h;
    final dx = (meaning.x - item.right) / h;
    final far = dx <= 30 ? 1.0 : math.max(0.0, 1 - (dx - 30) / 30);
    best = math.max(0.0, 1 - dy / rowTolerance) * far;
  }
  // A meaning on the next line under the headword (a narrow side column).
  final below = meaning.y - item.bottom;
  if ((meaning.x - item.x).abs() <= 2 * h &&
      below >= -0.3 * h &&
      below <= 2.5 * h) {
    best = math.max(best, 0.7 - 0.1 * math.max(0.0, below / h - 1));
  }
  return best;
}

/// How well [korean] sits as the translation of the Japanese [sentence]
/// (0..1): to its right on the same row, on the next row to the right (a
/// translation that wrapped), or on the line right below, starting where
/// the sentence starts (an example box).
double translationPlacement(Fragment sentence, Fragment korean) {
  final h = sentence.height;
  final below = (korean.y - sentence.bottom) / h;
  if ((korean.x - sentence.x).abs() <= 2 * h && below >= -0.3 && below <= 1.5) {
    return 0.6 - 0.1 * math.max(0.0, below - 0.5);
  }
  if (korean.x < sentence.x + 0.3 * sentence.width) return 0;
  final dy = (korean.cy - sentence.cy) / h;
  if (dy.abs() <= 0.8) return 1 - dy.abs() / 0.8 * 0.3;
  if (dy > 0 && dy <= 2.2 && korean.right >= sentence.right - 2 * h) return 0.6;
  return 0;
}
