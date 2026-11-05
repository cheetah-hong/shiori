/// Word-number anchors (`0016 □□□`) shared by both textbook layouts (rules 1–2).
library;

import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/capture/vocab/fields.dart';
import 'package:shiori_core/src/models/ocr.dart';

/// A four-digit word number; OCR may read 1 as I, l or |, and 0 as O or D,
/// with the first checkbox read as O right after it (`1212O`).
final RegExp idPattern = RegExp('^\\s*([$ocrDigits]{4})(?=\\s|\$|[□口ロコ■Oo])');

/// A real number keeps at least two digits (`DO17` is 0017, `DOOD` is a word).
const int _minDigits = 2;

/// A number that lost a digit (`143 ロロロ`) but still has its checkboxes.
final RegExp _shortIdPattern = RegExp(r'^\s*([0-9Il|]{2,3})\s*[□口ロコ■]{2,}');

final RegExp _asciiDigits = RegExp(r'^[0-9]+$');

/// N3 entry blocks are spaced further apart than N5·N4 list rows.
const double entryLayoutMinGap = 0.08;

typedef Anchor = ({OcrLine line, String? no});

/// Checkbox glyphs printed right after a word number.
final RegExp _checkboxAfterId = RegExp(
  '^\\s*[$ocrDigits]{2,4}\\s*[□口ロコ■]|^\\s*[$ocrDigits]{4}[Oo]',
);

/// Numbers whose x differ by less than this sit in the same column.
const double _columnTolerance = 0.12;

/// A column of numbers with fewer members and no checkbox is not a page.
const int _minColumn = 3;

/// Anchors in reading order. Numbers that lost a digit are filled from neighbours.
///
/// A column of numbers counts as a page only with at least three numbers or a
/// checkbox printed next to one: a meaning line misread as four digits must not
/// split the page in two (rule 3).
List<Anchor> findAnchors(List<OcrLine> ja) {
  final found = <Anchor>[];
  for (final l in ja) {
    final m = idPattern.firstMatch(l.text);
    if (m != null) {
      final token = m.group(1)!;
      final digits = token
          .replaceAll(RegExp('[Il|]'), '1')
          .replaceAll(RegExp('[OoD]'), '0');
      if (_asciiDigits.hasMatch(digits) &&
          RegExp('[0-9]').allMatches(token).length >= _minDigits) {
        found.add((line: l, no: digits));
      }
    } else if (_shortIdPattern.hasMatch(l.text)) {
      found.add((line: l, no: null));
    }
  }
  final out = stableSorted(
    _credibleColumns(found),
    (a, b) => cmpNum(a.line.cy, b.line.cy),
  );
  // Unread digits count on from the nearest read number by distance, so a run
  // of them is filled too; never 0000 or below (inferNumber).
  final numbers = [for (final a in out) a.no];
  return [
    for (final (i, a) in out.indexed)
      a.no != null
          ? a
          : (
              line: a.line,
              no: switch (inferNumber(numbers, i)) {
                final k? => pad4(k),
                null => null,
              },
            ),
  ];
}

/// Drops number columns that are too small to be a page and show no checkbox.
/// The largest column always stays.
List<Anchor> _credibleColumns(List<Anchor> found) {
  if (found.isEmpty) return found;
  final columns = <List<Anchor>>[];
  for (final a in stableSorted(found, (p, q) => cmpNum(p.line.x, q.line.x))) {
    if (columns.isNotEmpty &&
        (a.line.x - columns.last.last.line.x).abs() < _columnTolerance) {
      columns.last.add(a);
    } else {
      columns.add([a]);
    }
  }
  final largest = maxBy(columns, (c) => c.length);
  final kept = {
    for (final c in columns)
      if (identical(c, largest) ||
          c.length >= _minColumn ||
          c.any((a) => _checkboxAfterId.hasMatch(a.line.text)))
        ...c,
  };
  return [
    for (final a in found)
      if (kept.contains(a)) a,
  ];
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
