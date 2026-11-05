/// Column positions measured from the page content (rule 6).
///
/// The column offsets in the templates (`ax + 0.17` and so on) were set on photos
/// of the open book, where a page is about three quarters of the photo width.
/// A scanner crop, a flattened page or a closer photo makes every column offset
/// larger or smaller by the same factor. That factor is measured here from the
/// reading column: the distance from a word number to the kana cell on its row
/// is the same on every row of a page, whatever the image frame.
library;

import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/capture/vocab/anchors.dart';
import 'package:shiori_core/src/models/column_scale.dart';
import 'package:shiori_core/src/models/ocr.dart';

/// Number → reading distance on the photos the offsets were set on.
const double listReadingOffset = 0.23;
const double entryReadingOffset = 0.183;

/// Number → POS badge distance on the same photos, used when no reading was read.
const double listBadgeOffset = 0.415;
const double entryBadgeOffset = 0.42;

/// Two cells belong to the same column when their offsets differ by less than this share.
const double _sameColumn = 0.07;

/// A skewed page moves a cell up or down by up to this share of its distance
/// from the number; the row window grows by that much. Cells of the next row
/// that fall in do not move the result: they sit in the same columns.
const double _skew = 0.08;

/// Offsets this far from 1 are not a page crop but a misread: keep the photo frame.
const double _minScale = 0.6;
const double _maxScale = 1.8;

const Set<String> _dashes = {'-', '–', '—', '−', '一'};
final RegExp _badge = RegExp(r'^(い형|な형|명|몀|동|통|형|부)(?:\s*[.:·]?\s+|$)');

/// How the layout places a word row relative to its number.
typedef RowShape = ({
  /// Vertical window of the word row, relative to the number's centre.
  double top,
  double bottom,

  /// Smallest number → reading offset searched (keeps checkboxes and kana headwords out).
  double minOffset,
  double nominalReading,
  double nominalBadge,
});

const RowShape listRow = (
  top: -0.025,
  bottom: 0.025,
  minOffset: 0.12,
  nominalReading: listReadingOffset,
  nominalBadge: listBadgeOffset,
);

const RowShape entryRow = (
  top: 0.002,
  bottom: 0.05,
  minOffset: 0.1,
  nominalReading: entryReadingOffset,
  nominalBadge: entryBadgeOffset,
);

/// Horizontal scale of the page (1.0 on the photos the offsets were set on)
/// and how it was found.
///
/// Measured from the reading column, else from the POS badge column of the
/// Korean pass, else 1.0 (too few rows to tell). A measured scale outside
/// 0.6–1.8 is a misread, not a crop: 1.0, without trying the badge column.
ColumnScale columnScale({
  required List<Anchor> anchors,
  required List<OcrLine> ja,
  required List<OcrLine> ko,
  required RowShape shape,
}) {
  bool isReading(OcrLine l) {
    final t = nfkc(l.text).trim();
    return kanaOnly(t) || _dashes.contains(t);
  }

  final reading = _columnOffset(anchors, ja, shape, isReading);
  if (reading != null) {
    return _scale(reading / shape.nominalReading, ColumnScaleSource.reading);
  }
  final badge = _columnOffset(
    anchors,
    ko,
    shape,
    (l) => _badge.hasMatch(nfkc(l.text).trim()),
  );
  if (badge != null) {
    return _scale(badge / shape.nominalBadge, ColumnScaleSource.badge);
  }
  return const ColumnScale(1.0, ColumnScaleSource.tooFewRows);
}

ColumnScale _scale(double s, ColumnScaleSource source) =>
    s < _minScale || s > _maxScale
    ? const ColumnScale(1.0, ColumnScaleSource.outOfRange)
    : ColumnScale(s, source);

/// The offset most rows share (null below two rows): for every number, the
/// cells matching [pick] on its row; the column is the offset that the most
/// numbers have a cell near, and its value is the median of those cells.
double? _columnOffset(
  List<Anchor> anchors,
  List<OcrLine> lines,
  RowShape shape,
  bool Function(OcrLine) pick,
) {
  bool inRow(Anchor a, OcrLine l) {
    final dx = l.x - a.line.x;
    final dy = l.cy - a.line.cy;
    return dx >= shape.minOffset &&
        dy >= shape.top - _skew * dx &&
        dy <= shape.bottom + _skew * dx;
  }

  final perAnchor = <List<double>>[
    for (final a in anchors)
      [
        for (final l in lines)
          if (inRow(a, l) && pick(l)) l.x - a.line.x,
      ],
  ];
  final all = stableSorted([for (final d in perAnchor) ...d], cmpNum);
  var bestRows = 0;
  List<double> best = const [];
  for (final c in all) {
    bool near(double d) => (d - c).abs() <= _sameColumn * c;
    final rows = perAnchor.where((ds) => ds.any(near)).length;
    if (rows > bestRows) {
      bestRows = rows;
      best = [
        for (final ds in perAnchor)
          ?minBy(ds.where(near), (d) => (d - c).abs()),
      ];
    }
  }
  return bestRows >= 2 ? median(best) : null;
}
