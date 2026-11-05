/// Word-number anchors (`0016 □□□`) shared by both textbook layouts (rules 1–2).
library;

import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/models/ocr.dart';

/// A four-digit word number; OCR may read 1 as I, l or |.
final RegExp idPattern = RegExp(r'^\s*([0-9Il|]{4})(?=\s|$|[□口ロコ■])');

/// A number that lost a digit (`143 ロロロ`) but still has its checkboxes.
final RegExp _shortIdPattern = RegExp(r'^\s*([0-9Il|]{2,3})\s*[□口ロコ■]{2,}');

final RegExp _asciiDigits = RegExp(r'^[0-9]+$');

/// N3 entry blocks are spaced further apart than N5·N4 list rows.
const double entryLayoutMinGap = 0.08;

typedef Anchor = ({OcrLine line, String? no});

/// Anchors in reading order. Numbers that lost a digit are filled from neighbours.
List<Anchor> findAnchors(List<OcrLine> ja) {
  final found = <Anchor>[];
  for (final l in ja) {
    final m = idPattern.firstMatch(l.text);
    if (m != null) {
      final digits = m
          .group(1)!
          .replaceAll('I', '1')
          .replaceAll('l', '1')
          .replaceAll('|', '1');
      if (_asciiDigits.hasMatch(digits)) found.add((line: l, no: digits));
    } else if (_shortIdPattern.hasMatch(l.text)) {
      found.add((line: l, no: null));
    }
  }
  final out = stableSorted(found, (a, b) => cmpNum(a.line.cy, b.line.cy));
  for (var i = 0; i < out.length; i++) {
    if (out[i].no != null) continue;
    final prev = int.tryParse(i > 0 ? out[i - 1].no ?? '' : '');
    final next = int.tryParse(i + 1 < out.length ? out[i + 1].no ?? '' : '');
    final k = prev != null ? prev + 1 : (next != null ? next - 1 : null);
    // Word numbers start at 0001; never invent 0000 or a negative one.
    out[i] = (line: out[i].line, no: k != null && k >= 1 ? pad4(k) : null);
  }
  return out;
}

/// Median vertical gap between anchors, or null with fewer than two anchors.
double? anchorGap(List<Anchor> anchors) {
  if (anchors.length < 2) return null;
  return median([
    for (var i = 1; i < anchors.length; i++)
      anchors[i].line.cy - anchors[i - 1].line.cy,
  ]);
}

/// Number for row [i] from its nearest known neighbours; null when none is
/// known or the result would not be a valid word number (< 1).
int? inferNumber(List<String?> numbers, int i) {
  for (var j = i - 1; j >= 0; j--) {
    final prev = int.tryParse(numbers[j] ?? '');
    if (prev != null) return _valid(prev + (i - j));
  }
  for (var j = i + 1; j < numbers.length; j++) {
    final next = int.tryParse(numbers[j] ?? '');
    if (next != null) return _valid(next - (j - i));
  }
  return null;
}

int? _valid(int k) => k >= 1 ? k : null;
