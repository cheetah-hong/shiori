/// Layout A (N5·N4 PART 1): one row per word (rules 3–9).
///
/// `0015 □□□  川 ★  かわ  [명] 강, 개천`
library;

import 'package:shiori_core/src/capture/vocab/anchors.dart';
import 'package:shiori_core/src/capture/vocab/fields.dart';
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
  double match(OcrScan scan) {
    final gap = anchorGap(findAnchors(scan.japanese.lines));
    if (gap == null) return 0.5;
    return gap > entryLayoutMinGap ? 0.0 : 1.0;
  }

  @override
  TemplateResult parse(OcrScan scan) => TemplateResult(
    entries: List.unmodifiable(_parseRows(scan)),
    meta: readPageMeta(scan),
  );
}

// The legend at the top (`★ 표시 = …`), the DAY tab and the mp3 note are not words.
final RegExp _legend = RegExp(
  r'표시\s*=|기출 단어|^\s*DAY(?![\p{L}\p{N}_])|^\s*PART(?![\p{L}\p{N}_])|mp3',
  unicode: true,
);

const Set<String> _dashes = {'-', '–', '—', '−', '一'};

/// Column offsets from the row's number (x = ax), as page-width fractions (rule 6).
bool _isReading(OcrLine l, double ax) =>
    ax + 0.195 <= l.x &&
    l.x <= ax + 0.33 &&
    (kanaOnly(l.text) || _dashes.contains(nfkc(l.text).trim()));

int _byX(OcrLine a, OcrLine b) => cmpNum(a.x, b.x);

/// A word row: a point on the word column ([refX], [refY]) and the number's x.
typedef _Row = ({double refX, double refY, double anchorX, String? no});

List<CapturedEntry> _parseRows(OcrScan scan) {
  final ja = scan.japanese.lines;
  final ko = scan.korean.lines;
  final anchors = [
    for (final a in findAnchors(ja))
      if (a.no != null) a,
  ];
  final gap = anchorGap(anchors) ?? 0.045;
  final clusters = _clusterByX(anchors);
  return [
    for (final (i, cluster) in clusters.indexed)
      ..._parseCluster(
        cluster,
        right: i + 1 < clusters.length
            ? median(clusters[i + 1].map((a) => a.line.x)) - 0.03
            : 1.01,
        ja: ja,
        ko: ko,
        gap: gap,
      ),
  ];
}

/// Rule 3: a photo may include the neighbouring page; its numbers form another column.
List<List<Anchor>> _clusterByX(List<Anchor> anchors) {
  final clusters = <List<Anchor>>[];
  for (final a in stableSorted(anchors, (p, q) => cmpNum(p.line.x, q.line.x))) {
    if (clusters.isNotEmpty &&
        (a.line.x - clusters.last.last.line.x).abs() < 0.12) {
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
}) {
  final ax0 = median(cluster.map((a) => a.line.x));
  bool mine(OcrLine l) =>
      ax0 - 0.04 <= l.x && l.x < right && !_legend.hasMatch(l.text);
  final jaLines = ja.where(mine).toList();
  final koLines = ko.where(mine).toList();

  final (offset, slope) = _pageGeometry(cluster, jaLines, gap);
  final rows = _findRows(
    cluster,
    jaLines,
    ax0: ax0,
    offset: offset,
    slope: slope,
    gap: gap,
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

  final entries = <CapturedEntry>[];
  for (final (i, row) in rows.indexed) {
    final entry = _readRow(row, jaByRow[i], koByRow[i]);
    if (entry != null) entries.add(entry);
  }
  return entries;
}

/// Rule 5: id label offset (b) and row slope (s) from word/reading pairs, as medians.
(double, double) _pageGeometry(
  List<Anchor> cluster,
  List<OcrLine> ja,
  double gap,
) {
  final offsets = <double>[];
  final slopes = <double>[];
  for (final a in cluster) {
    final al = a.line;
    final word = minBy(
      ja.where(
        (l) =>
            al.x + 0.02 <= l.x &&
            l.x < al.x + 0.17 &&
            (l.cy - al.cy).abs() < 0.6 * gap &&
            l.height > 0.012,
      ),
      (l) => (l.cy - al.cy).abs(),
    );
    if (word == null) continue;
    offsets.add(word.cy - al.cy);
    final reading = minBy(
      ja.where((l) => _isReading(l, al.x) && (l.cy - al.cy).abs() < 0.6 * gap),
      (l) => (l.cy - word.cy).abs(),
    );
    if (reading != null && reading.x - word.x > 0.05) {
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
}) {
  final rows = <_Row>[
    for (final a in cluster)
      (
        refX: a.line.x + 0.045,
        refY: a.line.cy + offset,
        anchorX: a.line.x,
        no: a.no,
      ),
  ];
  for (final l in ja) {
    if (!_isReading(l, ax0)) continue;
    if (rows.every(
      (r) => (l.cy - (r.refY + slope * (l.x - r.refX))).abs() > 0.5 * gap,
    )) {
      rows.add((refX: l.x, refY: l.cy, anchorX: ax0, no: null));
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
    );
  }
  return sorted;
}

CapturedEntry? _readRow(_Row row, List<OcrLine> ja, List<OcrLine> ko) {
  final ax = row.anchorX;
  final readingCells = ja.where((l) => _isReading(l, ax)).toList();
  // Cut-off neighbour rows: no reading column visible.
  final reading = minBy(readingCells, (l) => l.x);
  if (reading == null) return null;

  final headParts = stableSorted(
    ja.where((l) => l.x < ax + 0.17 && l.x + l.width > ax + 0.02),
    _byX,
  );
  final headword = headParts
      .map((l) => cleanHead(l.text, overCheckbox: l.x < ax + 0.03))
      .join();
  final important = ja.any((l) => l.x < ax + 0.23 && l.text.contains('★'));
  final meaningParts = stableSorted(
    ko.where((l) => ax + 0.34 <= l.x && l.x <= ax + 0.56),
    _byX,
  );
  final (pos, meaning) = splitPos(
    cleanMeaning(meaningParts.map((l) => l.text).join(' ')),
  );

  return CapturedEntry(
    no: row.no,
    headword: headword,
    readings: parseReadings(reading.text),
    pos: pos,
    meaning: meaning,
    important: important,
  );
}
