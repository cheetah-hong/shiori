/// ★ check on the page photo, after the template has read the page.
///
/// ML Kit returns no glyph for about one printed ★ in three. The photo still
/// shows it: between the headword column and the reading of a list row there
/// is only the ★, printed in red on a beige band. So for every list row read
/// without ★ the page gets a cell there, a `StarMeter` block counts the red
/// pixels in it, and a row whose share passes the template's threshold becomes
/// ★, flagged `important:inferred`.
library;

import 'package:shiori_core/src/capture/scan_preparation.dart';
import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/capture/vocab/anchors.dart';
import 'package:shiori_core/src/capture/vocab/column_scale.dart';
import 'package:shiori_core/src/capture/vocab/fields.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/list_equality.dart';
import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/models/page_image.dart';
import 'package:shiori_core/src/ports/star_meter.dart';

/// `vocab.list`: red ★ on a beige band. The share was set on photos of the
/// textbook's list pages (22 of 24 ★ found, no row without ★ marked).
const StarColor listStarColor = StarColor(
  minRed: 120,
  minRedLead: 45,
  minShare: 0.002,
);

/// Templates whose pages are checked, by template id. The cell geometry
/// below is the list layout's; a template added here needs its own.
const Map<String, StarColor> _starColors = {'vocab.list': listStarColor};

/// The ★ colour of a template, or null when its pages are not checked.
StarColor? starColorFor(String templateId) => _starColors[templateId];

// Cell geometry, as offsets from the row's word number on the photos the
// list template's columns were set on (times the page's column scale).

/// The cell starts where the headword column ends.
const double _headEnd = 0.165;

/// Reading column of the list template (`readingFrom`, `readingTo`).
const double _readingFrom = 0.195;
const double _readingTo = 0.33;

/// Margin above and below the reading line, as a share of the page height.
const double _rowMargin = 0.006;

/// A reading belongs to a number this close, in number gaps.
const double _sameRow = 0.6;

/// Number gap used when fewer than two numbers were read.
const double _defaultGap = 0.045;

/// Cells for the ★ check of [draft], read from [scan] (raw or already
/// prepared, the clean-up is idempotent): one per list row without ★, in entry
/// order, or none when the template has no ★ setting.
///
/// [onlyUnmarked] false: every row gets a cell (to look at the geometry).
List<StarCell> starCells(
  CaptureDraft draft,
  OcrScan scan, {
  bool onlyUnmarked = true,
}) {
  if (starColorFor(draft.templateId) == null) return const [];
  final prepared = prepareScan(scan);
  final ja = prepared.japanese.lines;
  final anchors = [
    for (final a in findAnchors(ja))
      if (a.no != null) a,
  ];
  if (anchors.isEmpty) return const [];
  final page = _PageRows(
    anchors: anchors,
    readings: [
      for (final l in ja)
        if (isReadingCell(l.text)) l,
    ],
    scale: _listColumnScale(anchors, prepared),
    gap: anchorGap(anchors) ?? _defaultGap,
  );
  return List.unmodifiable([
    for (final (i, e) in draft.entries.indexed)
      if (!(onlyUnmarked && e.important)) ?page.cellOf(i, e),
  ]);
}

/// The one place the star check asks for the column scale.
double _listColumnScale(List<Anchor> anchors, OcrScan prepared) => columnScale(
  anchors: anchors,
  ja: prepared.japanese.lines,
  ko: prepared.korean.lines,
  shape: listRow,
).value;

/// The numbers and reading lines of one page, and where a row's ★ cell is.
final class _PageRows {
  _PageRows({
    required this.anchors,
    required this.readings,
    required this.scale,
    required this.gap,
  });

  final List<Anchor> anchors;
  final List<OcrLine> readings;
  final double scale;
  final double gap;

  /// Where readings sit relative to their number, for rows whose reading OCR
  /// missed: median offset of the reading centre and median reading height.
  late final ({double dy, double height})? _typicalReading = () {
    final pairs = [
      for (final a in anchors)
        if (_readingNear(a, const [], a.line.x) case final r?) (a, r),
    ];
    if (pairs.isEmpty) return null;
    return (
      dy: median([for (final (a, r) in pairs) r.cy - a.line.cy]),
      height: median([for (final (_, r) in pairs) r.height]),
    );
  }();

  StarCell? cellOf(int index, CapturedEntry e) {
    final anchor = _anchorOf(e.no);
    final ax = anchor?.line.x ?? _columnOfReading(e.readings);
    if (ax == null) return null;
    final reading = anchor == null
        ? _readingByText(e.readings, ax)
        : _readingNear(anchor, e.readings, ax);
    final left = ax + _headEnd * scale;
    final double right;
    final double top;
    final double bottom;
    if (reading != null) {
      right = reading.x;
      top = reading.y - _rowMargin;
      bottom = reading.y + reading.height + _rowMargin;
    } else {
      final typical = _typicalReading;
      if (anchor == null || typical == null) return null;
      final cy = anchor.line.cy + typical.dy;
      right = ax + listReadingOffset * scale;
      top = cy - typical.height / 2 - _rowMargin;
      bottom = cy + typical.height / 2 + _rowMargin;
    }
    return _clipped(index, e.no, left, top, right, bottom);
  }

  Anchor? _anchorOf(String? no) {
    if (no == null) return null;
    for (final a in anchors) {
      if (a.no == no) return a;
    }
    return null;
  }

  bool _inReadingColumn(OcrLine l, double ax) =>
      ax + _readingFrom * scale <= l.x && l.x <= ax + _readingTo * scale;

  /// The reading on the row of [anchor]: the one with the entry's readings,
  /// else the nearest in height.
  OcrLine? _readingNear(Anchor anchor, List<String> wanted, double ax) {
    final row = [
      for (final l in readings)
        if (_inReadingColumn(l, ax) &&
            (l.cy - anchor.line.cy).abs() < _sameRow * gap)
          l,
    ];
    final byText = [
      for (final l in row)
        if (wanted.isNotEmpty && listEquals(parseReadings(l.text), wanted)) l,
    ];
    return minBy(
      byText.isNotEmpty ? byText : row,
      (l) => (l.cy - anchor.line.cy).abs(),
    );
  }

  /// A row whose number was not read was found from its reading; the number
  /// column is the one whose reading column holds that reading.
  double? _columnOfReading(List<String> wanted) {
    if (wanted.isEmpty) return null;
    for (final l in readings) {
      if (!listEquals(parseReadings(l.text), wanted)) continue;
      final xs = [
        for (final a in anchors)
          if (_inReadingColumn(l, a.line.x)) a.line.x,
      ];
      if (xs.isNotEmpty) return median(xs);
    }
    return null;
  }

  OcrLine? _readingByText(List<String> wanted, double ax) {
    for (final l in readings) {
      if (_inReadingColumn(l, ax) &&
          listEquals(parseReadings(l.text), wanted)) {
        return l;
      }
    }
    return null;
  }

  StarCell? _clipped(
    int index,
    String? no,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    final x0 = left.clamp(0.0, 1.0);
    final y0 = top.clamp(0.0, 1.0);
    final x1 = right.clamp(0.0, 1.0);
    final y1 = bottom.clamp(0.0, 1.0);
    if (x1 <= x0 || y1 <= y0) return null;
    return StarCell(
      entryIndex: index,
      no: no,
      x: x0,
      y: y0,
      width: x1 - x0,
      height: y1 - y0,
    );
  }
}

/// [draft] with the rows whose share reaches the threshold marked ★
/// (`important:inferred`). Without [ratios], or with one per cell missing or
/// extra, the draft comes back as it is.
CaptureDraft applyStarRatios(
  CaptureDraft draft,
  List<StarCell> cells,
  List<double>? ratios,
  StarColor color,
) {
  if (ratios == null || ratios.length != cells.length) return draft;
  final starred = {
    for (final (i, c) in cells.indexed)
      if (ratios[i] >= color.minShare) c.entryIndex,
  };
  if (starred.isEmpty) return draft;
  return draft.copyWith(
    entries: [
      for (final (i, e) in draft.entries.indexed)
        if (starred.contains(i) && !e.important)
          e.copyWith(
            important: true,
            issues: [
              ...e.issues,
              const EntryIssue.inferred(EntryField.important),
            ],
          )
        else
          e,
    ],
  );
}

/// The ★ check of one page: only ML Kit pages of a template with a ★ setting
/// are measured. Errors of [meter] reach the caller, which decides whether
/// the page goes on without the check.
Future<CaptureDraft> checkStars({
  required CaptureDraft draft,
  required OcrScan scan,
  required PageImage image,
  required StarMeter meter,
}) async {
  final color = starColorFor(draft.templateId);
  if (color == null || !scan.japanese.isMlKit) return draft;
  final cells = starCells(draft, scan);
  if (cells.isEmpty) return draft;
  final measured = await meter.measure(
    image,
    cells: cells,
    color: color,
    turned: scan.turned,
  );
  return applyStarRatios(draft, cells, measured?.ratios, color);
}
