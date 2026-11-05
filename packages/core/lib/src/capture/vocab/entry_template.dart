/// Layout B (N3 PART 2): an entry block per word with an example (rules 3, 10).
///
/// ```
/// 1216 □□□
/// 降りる  おりる  [동] 내리다
///   忘れ物をしないように気をつけて降りてください。
///   잊은 물건이 없도록 조심해서 내려 주세요.
/// ```
library;

import 'package:shiori_core/src/capture/vocab/anchors.dart';
import 'package:shiori_core/src/capture/vocab/column_scale.dart';
import 'package:shiori_core/src/capture/vocab/fields.dart';
import 'package:shiori_core/src/capture/vocab/layout.dart';
import 'package:shiori_core/src/capture/vocab/page_meta.dart';
import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/column_scale.dart';
import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/ports/textbook_template.dart';

final class EntryPageTemplate implements TextbookTemplate {
  const EntryPageTemplate();

  @override
  String get id => 'vocab.entry';

  @override
  String get label => '항목형 (N3, 예문 포함)';

  @override
  String get suggestedTextbookTitle => 'JLPT 단어장';

  @override
  double match(OcrScan scan) =>
      detectLayout(scan) == PageLayout.entry ? 1.0 : 0.0;

  @override
  TemplateResult parse(OcrScan scan) {
    final read = findAnchors(scan.japanese.lines);
    final scale = columnScale(
      anchors: read,
      ja: scan.japanese.lines,
      ko: scan.korean.lines,
      shape: entryRow,
    );
    return TemplateResult(
      entries: List.unmodifiable(_parseEntries(scan, read, scale)),
      meta: readPageMeta(scan),
      columnScale: scale,
    );
  }
}

final RegExp _bracketStart = RegExp(r'^[\[【]');
final RegExp _spaces = RegExp(r'\s+');

int _byX(OcrLine a, OcrLine b) => cmpNum(a.x, b.x);
int _byCy(OcrLine a, OcrLine b) => cmpNum(a.cy, b.cy);

/// Reading order of Korean lines: rows (cy to 2 decimals), then left to right.
int _byRowThenX(OcrLine a, OcrLine b) {
  final c = cmpNum(pyRound2(a.cy), pyRound2(b.cy));
  return c != 0 ? c : cmpNum(a.x, b.x);
}

bool _isRelatedBox(String t) => t.contains('관련어') || t.contains('문형');

/// A number block: the number line and the block's lines.
typedef _Block = ({
  Anchor anchor,
  double bottom,
  List<OcrLine> row,
  OcrLine? reading,
});

/// Smallest confidence of an example line in ML Kit passes (the Japanese pass
/// reads translation lines as Japanese garbage at 0.13–0.23).
const double _mlKitSentenceConfidence = 0.4;

/// Height of a reading line when none was read on the page.
const double _defaultReadingHeight = 0.016;

/// Column offsets from the number (x = ax), as image-width fractions on the
/// photos they were set on, times the page's measured column scale (rule 6).
final class _Cols {
  const _Cols(this.s);

  final double s;

  /// The neighbouring page starts this far left of the leftmost number.
  double get pageLeft => 0.03 * s;
  double get headFrom => -0.02 * s;

  /// End of the headword, start of the reading and of the example column.
  double get column => 0.15 * s;
  double get readingTo => 0.32 * s;
  double get star => 0.2 * s;
  double get meaningFrom => 0.36 * s;

  /// A headword line (found without its number) starts near the number's x.
  double get headLineFrom => -0.03 * s;
  double get headLineTo => 0.05 * s;
  double get headLineMaxWidth => 0.16 * s;

  /// A reading line found without its number starts in this range.
  double get rowReadingTo => 0.22 * s;

  /// A sentence line is at least this wide (furigana sit on top of one).
  double get sentenceWidth => 0.2 * s;

  /// A long line whose box a stray glyph pulled left: width and right end.
  double get longLineWidth => 0.3 * s;
  double get longLineEnd => 0.35 * s;
}

// Vertical offsets, as image-height fractions.
/// The word row under the number line.
const double _rowTop = 0.002;
const double _rowBottom = 0.05;

/// Meaning lines may start a little above the number's centre.
const double _meaningAbove = 0.012;

/// Bottom of the last block when no footer line was read (the footer is below).
const double _lastBlockBottom = 0.93;

/// Gap kept above the next block or a box that ends the example.
const double _blockGap = 0.004;
const double _readingMinHeight = 0.012;

/// Without a reading, the example starts this far below the number.
const double _rowWithoutReading = 0.02;

/// The example starts this far below the reading.
const double _belowReading = 0.012;

/// Furigana sit at most this far above their sentence.
const double _furiganaAbove = 0.025;

/// Row lines closer than this belong to the same word row.
const double _sameRow = 0.035;

/// The number line sits this far above its word row, give or take [_numberNear].
const double _numberAboveRow = 0.018;
const double _numberNear = 0.03;

List<CapturedEntry> _parseEntries(
  OcrScan scan,
  List<Anchor> read,
  ColumnScale scale,
) {
  final ja = scan.japanese.lines;
  final ko = scan.korean.lines;
  if (read.isEmpty) return const [];
  // Column offsets from the number (x = ax) on the photos they were set on,
  // times the page's measured column scale (rule 6).
  final cols = _Cols(scale.value);
  final anchors = _withRowAnchors(ja, read, cols);

  // The neighbouring page shows up left of the leftmost number.
  final left =
      anchors.map((a) => a.line.x).reduce((a, b) => b < a ? b : a) -
      cols.pageLeft;
  List<OcrLine> inBlock(List<OcrLine> lines, double lo, double hi) => [
    for (final l in lines)
      if (lo <= l.cy && l.cy < hi && l.x >= left) l,
  ];

  // The last block ends at the footer: in a page crop it sits lower than in a photo.
  final footer = minBy(
    ko.where((l) => isFooterLine(l.text) && l.cy > anchors.last.line.cy),
    (l) => l.y,
  );
  final lastBottom = footer == null ? _lastBlockBottom : footer.y;
  final blocks = <_Block>[
    for (final (i, anchor) in anchors.indexed)
      _block(
        anchor,
        i + 1 < anchors.length ? anchors[i + 1] : null,
        ja,
        cols,
        inBlock,
        lastBottom,
      ),
  ];
  // A reading glued to the headword is as tall as the headword: the example
  // height threshold uses at most the page's usual reading height.
  final heights = [for (final b in blocks) ?b.reading?.height];
  final pageReadingHeight = heights.isEmpty
      ? _defaultReadingHeight
      : median(heights);

  return [
    for (final b in blocks)
      _entry(
        b,
        ja,
        ko,
        cols,
        inBlock,
        pageReadingHeight,
        scan.japanese.isMlKit,
      ),
  ];
}

_Block _block(
  Anchor anchor,
  Anchor? next,
  List<OcrLine> ja,
  _Cols cols,
  List<OcrLine> Function(List<OcrLine>, double, double) inBlock,
  double lastBottom,
) {
  final ax = anchor.line.x;
  final top = anchor.line.cy;
  final row = inBlock(ja, top + _rowTop, top + _rowBottom);
  // The reading has kana and does not sit right on top of a sentence (furigana).
  final reading = minBy(
    row.where(
      (l) =>
          ax + cols.column <= l.x &&
          l.x <= ax + cols.readingTo &&
          l.height >= _readingMinHeight &&
          isReadingCell(l.text, firstToken: true) &&
          !_onSentence(l, ja, cols),
    ),
    (l) => l.cy,
  );
  return (
    anchor: anchor,
    bottom: next == null ? lastBottom : next.line.cy - _blockGap,
    row: row,
    reading: reading,
  );
}

CapturedEntry _entry(
  _Block b,
  List<OcrLine> ja,
  List<OcrLine> ko,
  _Cols cols,
  List<OcrLine> Function(List<OcrLine>, double, double) inBlock,
  double pageReadingHeight,
  bool mlKit,
) {
  final ax = b.anchor.line.x;
  final top = b.anchor.line.cy;
  final reading = b.reading;
  final heads = stableSorted(
    b.row.where(
      (l) =>
          ax + cols.headFrom <= l.x &&
          l.x < ax + cols.column &&
          !idPattern.hasMatch(l.text),
    ),
    _byX,
  );
  final meaningParts = stableSorted(
    inBlock(ko, top - _meaningAbove, top + _rowBottom).where(
      (l) =>
          l.x >= ax + cols.meaningFrom &&
          // Korean text, or the 동 badge read as 8 on a piece of its own.
          (ratio(l.text, isHangul) > 0.3 || eightBadge.hasMatch(l.text)) &&
          // An anchor found from the word row of the first entry reaches up
          // to the legend line.
          !legendPattern.hasMatch(l.text),
    ),
    _byRowThenX,
  );
  final (pos, meaning) = splitPos(
    cleanMeaning(meaningParts.map((l) => l.text).join(' ')),
  );
  final readingHeight = reading?.height ?? _defaultReadingHeight;
  final example = _readExample(
    ja: ja,
    ko: ko,
    inBlock: inBlock,
    inColumn: (l) => _inExampleColumn(l, ax, cols),
    exampleTop:
        (reading != null ? reading.cy : top + _rowWithoutReading) +
        _belowReading,
    bottom: b.bottom,
    readingHeight: readingHeight < pageReadingHeight
        ? readingHeight
        : pageReadingHeight,
    minConfidence: mlKit ? _mlKitSentenceConfidence : 0.0,
  );
  final headword = heads.map((l) => cleanHead(l.text)).join();
  return CapturedEntry(
    no: b.anchor.no,
    headword: headword,
    ocrHeadword: headword,
    readings: reading == null ? const [] : parseReadings(reading.text),
    pos: pos,
    meaning: meaning,
    important: b.row.any((l) => l.x < ax + cols.star && l.text.contains('★')),
    example: example,
    issues: example == null
        ? const [EntryIssue.missing(EntryField.example)]
        : const [],
  );
}

/// In the example column, or a long line whose box a stray glyph glued in
/// front pulled to the left.
bool _inExampleColumn(OcrLine l, double ax, _Cols cols) =>
    l.x >= ax + cols.column ||
    (l.width >= cols.longLineWidth &&
        l.x >= ax &&
        l.x + l.width >= ax + cols.longLineEnd);

/// Furigana sit right on top of a long sentence line; a word's reading has a
/// gap below it.
bool _onSentence(OcrLine l, List<OcrLine> ja, _Cols cols) => ja.any(
  (o) =>
      !identical(o, l) &&
      o.width >= cols.sentenceWidth &&
      !kanaOnly(o.text) &&
      o.cy - l.cy >= 0 &&
      o.cy - l.cy <= _furiganaAbove,
);

/// A headword line: large Japanese text at the number's x.
bool _isHeadLine(OcrLine l, double ax, _Cols cols) =>
    ax + cols.headLineFrom <= l.x &&
    l.x <= ax + cols.headLineTo &&
    l.height >= 0.017 &&
    l.width <= cols.headLineMaxWidth &&
    l.text.trim().runes.length <= 8 &&
    !idPattern.hasMatch(l.text) &&
    ratio(l.text, isHangul) == 0 &&
    ratio(l.text, isJp) >= 0.6;

/// Some number lines are not read (they are small). Every word row (headword
/// or reading line) with no number above it gets one, numbered from its
/// neighbours.
List<Anchor> _withRowAnchors(List<OcrLine> ja, List<Anchor> read, _Cols cols) {
  final ax = median(read.map((a) => a.line.x));
  final rowLines = stableSorted(
    ja.where(
      (l) =>
          _isHeadLine(l, ax, cols) ||
          (ax + cols.column <= l.x &&
              l.x <= ax + cols.rowReadingTo &&
              l.height >= _readingMinHeight &&
              isReadingCell(l.text, firstToken: true) &&
              !_onSentence(l, ja, cols)),
    ),
    _byCy,
  );
  final rows = <List<OcrLine>>[];
  for (final l in rowLines) {
    if (rows.isNotEmpty && l.cy - rows.last.last.cy < _sameRow) {
      rows.last.add(l);
    } else {
      rows.add([l]);
    }
  }
  final all = [...read];
  for (final row in rows) {
    final top =
        row.map((l) => l.cy).reduce((a, b) => b < a ? b : a) - _numberAboveRow;
    if (read.any((a) => (a.line.cy - top).abs() <= _numberNear)) continue;
    all.add((
      line: OcrLine(
        text: '',
        x: ax,
        y: top - 0.003,
        width: 0.02,
        height: 0.006,
      ),
      no: null,
    ));
  }
  final sorted = stableSorted(all, (p, q) => cmpNum(p.line.cy, q.line.cy));
  final numbers = [for (final a in sorted) a.no];
  return [
    for (final (i, a) in sorted.indexed)
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

/// Rule 10: large Japanese lines under the word row (furigana are much shorter),
/// then the Korean translation; the 관련어 / 문형 boxes end the example.
Example? _readExample({
  required List<OcrLine> ja,
  required List<OcrLine> ko,
  required List<OcrLine> Function(List<OcrLine>, double, double) inBlock,

  /// Whether a line is in the example and translation column.
  required bool Function(OcrLine) inColumn,
  required double exampleTop,
  required double bottom,
  required double readingHeight,
  required double minConfidence,
}) {
  final cuts = [
    for (final l in inBlock(ko, exampleTop, bottom))
      if (_isRelatedBox(l.text)) l.cy,
  ];
  final exampleBottom = cuts.isNotEmpty
      ? cuts.reduce((a, b) => b < a ? b : a) - _blockGap
      : bottom;

  final sentence = stableSorted(
    inBlock(ja, exampleTop, exampleBottom).where(
      (l) =>
          inColumn(l) &&
          // Kana-only lines are furigana, not the sentence.
          !kanaOnly(l.text) &&
          l.confidence >= minConfidence &&
          l.height >= 0.75 * readingHeight &&
          ratio(l.text, isJp) >= 0.85 &&
          ratio(l.text, isHangul) == 0 &&
          !_bracketStart.hasMatch(l.text),
    ),
    _byCy,
  );
  final exJa = sentence.map((l) => l.text.trim()).join();
  if (exJa.isEmpty) return null;

  final translation = <String>[];
  for (final l in stableSorted(
    inBlock(ko, sentence.first.cy - 0.005, bottom),
    _byRowThenX,
  )) {
    if (!inColumn(l) || _isRelatedBox(l.text)) continue;
    final tokens = l.text.trim().isEmpty
        ? const <String>[]
        : l.text.trim().split(_spaces);
    // Drop a Japanese tail glued to the start of the line.
    final kept = tokens
        .skipWhile((t) => t.runes.where(isHangul).length < 2)
        .join(' ');
    if (kept.isNotEmpty && ratio(kept, isHangul) > 0.5) translation.add(kept);
  }
  return Example(ja: exJa, ko: translation.join(' '));
}
