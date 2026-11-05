/// Layout A (N5·N4 PART 1): one row per word (rules 3–9).
///
/// `0015 □□□  川 ★  かわ  [명] 강, 개천`
library;

import 'package:shiori_core/src/capture/vocab/anchors.dart';
import 'package:shiori_core/src/capture/vocab/column_scale.dart';
import 'package:shiori_core/src/capture/vocab/fields.dart';
import 'package:shiori_core/src/capture/vocab/layout.dart';
import 'package:shiori_core/src/capture/vocab/page_meta.dart';
import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/ports/textbook_template.dart';

final class ListPageTemplate implements TextbookTemplate {
  const ListPageTemplate();

  @override
  String get id => 'vocab.list';

  @override
  String get label => '목록형 (N5·N4)';

  @override
  String get suggestedTextbookTitle => 'JLPT 단어장';

  /// The default layout: also chosen when too few numbers were read to tell.
  @override
  double match(OcrScan scan) =>
      detectLayout(scan) == PageLayout.list ? 1.0 : 0.0;

  @override
  TemplateResult parse(OcrScan scan) => TemplateResult(
    entries: List.unmodifiable(_parseRows(scan)),
    meta: readPageMeta(scan),
  );
}

/// Column offsets from the row's number (x = ax), as image-width fractions on
/// the photos they were set on, times the page's measured column scale (rule 6).
final class _Cols {
  const _Cols(this.s);

  final double s;

  double get clusterGap => 0.12 * s;
  double get pageLeft => 0.04 * s;
  double get pageRight => 0.03 * s;
  double get headFrom => 0.02 * s;
  double get headTo => 0.17 * s;
  double get checkbox => 0.03 * s;
  double get star => 0.23 * s;
  double get readingFrom => 0.195 * s;
  double get readingTo => 0.33 * s;
  double get meaningFrom => 0.34 * s;
  double get meaningTo => 0.56 * s;

  /// A point on the word column, right of the number.
  double get wordRef => 0.045 * s;

  /// Shortest word → reading distance that gives a usable row slope.
  double get slopeBase => 0.05 * s;

  /// How close a glued badge must start to the badges of nearby rows.
  double get badgeZone => 0.012 * s;

  bool isReading(OcrLine l, double ax) =>
      ax + readingFrom <= l.x && l.x <= ax + readingTo && isReadingCell(l.text);
}

int _byX(OcrLine a, OcrLine b) => cmpNum(a.x, b.x);

/// A word row: a point on the word column ([refX], [refY]) and the number's x.
/// [anchored]: the row's own number was read (not found from its reading).
typedef _Row = ({
  double refX,
  double refY,
  double anchorX,
  String? no,
  bool anchored,
});

/// Rows above and below whose badges a glued badge is compared with.
const int _badgeRows = 3;

List<CapturedEntry> _parseRows(OcrScan scan) {
  final ja = scan.japanese.lines;
  final ko = scan.korean.lines;
  final anchors = [
    for (final a in findAnchors(ja))
      if (a.no != null) a,
  ];
  final gap = anchorGap(anchors) ?? 0.045;
  final cols = _Cols(
    columnScale(anchors: anchors, ja: ja, ko: ko, shape: listRow),
  );
  final clusters = _clusterByX(anchors, cols);
  return [
    for (final (i, cluster) in clusters.indexed)
      ..._parseCluster(
        cluster,
        right: i + 1 < clusters.length
            ? median(clusters[i + 1].map((a) => a.line.x)) - cols.pageRight
            : 1.01,
        ja: ja,
        ko: ko,
        gap: gap,
        cols: cols,
      ),
  ];
}

/// Rule 3: a photo may include the neighbouring page; its numbers form another column.
List<List<Anchor>> _clusterByX(List<Anchor> anchors, _Cols cols) {
  final clusters = <List<Anchor>>[];
  for (final a in stableSorted(anchors, (p, q) => cmpNum(p.line.x, q.line.x))) {
    if (clusters.isNotEmpty &&
        (a.line.x - clusters.last.last.line.x).abs() < cols.clusterGap) {
      clusters.last.add(a);
    } else {
      clusters.add([a]);
    }
  }
  return clusters;
}

List<CapturedEntry> _parseCluster(
  List<Anchor> cluster, {
  required double right,
  required List<OcrLine> ja,
  required List<OcrLine> ko,
  required double gap,
  required _Cols cols,
}) {
  final ax0 = median(cluster.map((a) => a.line.x));
  bool mine(OcrLine l) =>
      ax0 - cols.pageLeft <= l.x &&
      l.x < right &&
      !legendPattern.hasMatch(l.text);
  final jaLines = ja.where(mine).toList();
  final koLines = ko.where(mine).toList();

  final (offset, slope) = _pageGeometry(cluster, jaLines, gap, cols);
  final rows = _findRows(
    cluster,
    jaLines,
    ax0: ax0,
    offset: offset,
    slope: slope,
    gap: gap,
    cols: cols,
  );

  // Assign every line to the nearest row along the slope.
  final jaByRow = List.generate(rows.length, (_) => <OcrLine>[]);
  final koByRow = List.generate(rows.length, (_) => <OcrLine>[]);
  for (final (lines, target) in [(jaLines, jaByRow), (koLines, koByRow)]) {
    for (final l in lines) {
      var best = double.infinity;
      var bestRow = 0;
      for (final (i, r) in rows.indexed) {
        final d = (l.cy - (r.refY + slope * (l.x - r.refX))).abs();
        if (d < best) {
          best = d;
          bestRow = i;
        }
      }
      if (best < 0.55 * gap) target[bestRow].add(l);
    }
  }

  final cells = _unglueBadges([
    for (final (i, row) in rows.indexed)
      _readCells(row, jaByRow[i], koByRow[i], cols),
  ], cols);
  // A cut-off neighbour page shows numbers but no reading column: only a page
  // whose rows mostly have a reading keeps the rows where OCR missed it.
  final withReading = cells.where((c) => c.reading != null).length;
  final keepUnread = withReading * 2 >= cells.length;
  return [for (final c in cells) ?_entryOf(c, keepUnread: keepUnread)];
}

/// Rule 5: id label offset (b) and row slope (s) from word/reading pairs, as medians.
(double, double) _pageGeometry(
  List<Anchor> cluster,
  List<OcrLine> ja,
  double gap,
  _Cols cols,
) {
  final offsets = <double>[];
  final slopes = <double>[];
  for (final a in cluster) {
    final al = a.line;
    final word = minBy(
      ja.where(
        (l) =>
            al.x + cols.headFrom <= l.x &&
            l.x < al.x + cols.headTo &&
            (l.cy - al.cy).abs() < 0.6 * gap &&
            l.height > 0.012,
      ),
      (l) => (l.cy - al.cy).abs(),
    );
    if (word == null) continue;
    offsets.add(word.cy - al.cy);
    final reading = minBy(
      ja.where(
        (l) => cols.isReading(l, al.x) && (l.cy - al.cy).abs() < 0.6 * gap,
      ),
      (l) => (l.cy - word.cy).abs(),
    );
    if (reading != null && reading.x - word.x > cols.slopeBase) {
      slopes.add((reading.cy - word.cy) / (reading.x - word.x));
    }
  }
  return (
    offsets.isEmpty ? 0.0 : median(offsets),
    slopes.isEmpty ? 0.0 : median(slopes),
  );
}

/// Rule 4: rows come from numbers and from reading cells whose number was not read.
List<_Row> _findRows(
  List<Anchor> cluster,
  List<OcrLine> ja, {
  required double ax0,
  required double offset,
  required double slope,
  required double gap,
  required _Cols cols,
}) {
  final rows = <_Row>[
    for (final a in cluster)
      (
        refX: a.line.x + cols.wordRef,
        refY: a.line.cy + offset,
        anchorX: a.line.x,
        no: a.no,
        anchored: true,
      ),
  ];
  for (final l in ja) {
    if (!cols.isReading(l, ax0)) continue;
    if (rows.every(
      (r) => (l.cy - (r.refY + slope * (l.x - r.refX))).abs() > 0.5 * gap,
    )) {
      rows.add((
        refX: l.x,
        refY: l.cy,
        anchorX: ax0,
        no: null,
        anchored: false,
      ));
    }
  }
  final sorted = stableSorted(rows, (p, q) => cmpNum(p.refY, q.refY));
  // Missing numbers continue from the previous row, or count back from the
  // next known row by distance (so leading gaps never reuse a number).
  for (var i = 0; i < sorted.length; i++) {
    final r = sorted[i];
    if (r.no != null) continue;
    final k = inferNumber([for (final x in sorted) x.no], i);
    sorted[i] = (
      refX: r.refX,
      refY: r.refY,
      anchorX: r.anchorX,
      no: k == null ? null : pad4(k),
      anchored: r.anchored,
    );
  }
  return sorted;
}

/// The cells of one row before they become an entry.
typedef _Cells = ({
  _Row row,
  String headword,
  bool important,
  OcrLine? reading,
  String meaning,

  /// x of the first meaning piece, where the POS badge sits.
  double? meaningX,
});

_Cells _readCells(_Row row, List<OcrLine> ja, List<OcrLine> ko, _Cols cols) {
  final ax = row.anchorX;
  final headParts = stableSorted(
    ja.where(
      (l) => l.x < ax + cols.headTo && l.x + l.width > ax + cols.headFrom,
    ),
    _byX,
  );
  final meaningParts = stableSorted(
    ko.where((l) => ax + cols.meaningFrom <= l.x && l.x <= ax + cols.meaningTo),
    _byX,
  );
  return (
    row: row,
    headword: headParts
        .map((l) => cleanHead(l.text, overCheckbox: l.x < ax + cols.checkbox))
        .join(),
    important: ja.any((l) => l.x < ax + cols.star && l.text.contains('★')),
    reading: minBy(ja.where((l) => cols.isReading(l, ax)), (l) => l.x),
    meaning: cleanMeaning(meaningParts.map((l) => l.text).join(' ')),
    meaningX: meaningParts.firstOrNull?.x,
  );
}

CapturedEntry? _entryOf(_Cells c, {required bool keepUnread}) {
  final reading = c.reading;
  // Cut-off neighbour rows: no reading column visible. On the page itself a
  // row whose number was read stays even so (OCR skipped its reading or the
  // dash of a kana word); the empty reading is flagged for review.
  if (reading == null &&
      !(keepUnread &&
          c.row.anchored &&
          (c.headword.isNotEmpty || c.meaning.isNotEmpty))) {
    return null;
  }
  final (pos, meaning) = splitPos(c.meaning);
  return CapturedEntry(
    no: c.row.no,
    headword: c.headword,
    readings: reading == null ? const [] : parseReadings(reading.text),
    pos: pos,
    meaning: meaning,
    important: c.important,
    ocrHeadword: c.headword,
  );
}

/// A POS badge glued to the meaning (`명3, 셋`, `명낮`) gets its space back.
///
/// Before a digit the badge is always split. Before Hangul only when the line
/// starts where the separate badges of nearby rows start: a meaning that merely
/// begins with 명, 동, 부 … starts further right.
List<_Cells> _unglueBadges(List<_Cells> rows, _Cols cols) {
  final separate = {
    for (final (i, r) in rows.indexed)
      if (_hasSeparateBadge(r.meaning)) i: ?r.meaningX,
  };
  return [
    for (final (i, r) in rows.indexed)
      if (_glued(r, i, separate, cols))
        (
          row: r.row,
          headword: r.headword,
          important: r.important,
          reading: r.reading,
          meaning:
              '${String.fromCharCode(r.meaning.runes.first)} '
              '${String.fromCharCodes(r.meaning.runes.skip(1))}',
          meaningX: r.meaningX,
        )
      else
        r,
  ];
}

bool _hasSeparateBadge(String meaning) =>
    splitPos(meaning).$1 != null || eightBadge.hasMatch(meaning);

bool _glued(_Cells r, int i, Map<int, double> separate, _Cols cols) {
  final runes = r.meaning.runes.toList();
  if (runes.length < 2 ||
      !badgeGlyphs.contains(String.fromCharCode(runes[0])) ||
      splitPos(r.meaning).$1 != null) {
    return false;
  }
  if (runes[1] >= 0x30 && runes[1] <= 0x39) return true;
  final x = r.meaningX;
  if (x == null || !isHangul(runes[1])) return false;
  final near = [
    for (final MapEntry(key: j, value: v) in separate.entries)
      if (j != i && (j - i).abs() <= _badgeRows) v,
  ];
  return near.isNotEmpty && (x - median(near)).abs() < cols.badgeZone;
}
