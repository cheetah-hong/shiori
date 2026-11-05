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
import 'package:shiori_core/src/capture/vocab/fields.dart';
import 'package:shiori_core/src/capture/vocab/page_meta.dart';
import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
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
  double match(OcrScan scan) {
    final gap = anchorGap(findAnchors(scan.japanese.lines));
    if (gap == null) return 0.0;
    return gap > entryLayoutMinGap ? 1.0 : 0.0;
  }

  @override
  TemplateResult parse(OcrScan scan) => TemplateResult(
    entries: List.unmodifiable(_parseEntries(scan)),
    meta: readPageMeta(scan),
  );
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

List<CapturedEntry> _parseEntries(OcrScan scan) {
  final ja = scan.japanese.lines;
  final ko = scan.korean.lines;
  final anchors = findAnchors(ja);
  if (anchors.isEmpty) return const [];

  // The neighbouring page shows up left of the leftmost number.
  final left =
      anchors.map((a) => a.line.x).reduce((a, b) => b < a ? b : a) - 0.03;
  List<OcrLine> inBlock(List<OcrLine> lines, double lo, double hi) => [
    for (final l in lines)
      if (lo <= l.cy && l.cy < hi && l.x >= left) l,
  ];

  final entries = <CapturedEntry>[];
  for (final (i, anchor) in anchors.indexed) {
    final ax = anchor.line.x;
    final top = anchor.line.cy;
    final bottom = i + 1 < anchors.length
        ? anchors[i + 1].line.cy - 0.004
        : 0.93;

    final row = inBlock(ja, top + 0.002, top + 0.05);
    final heads = stableSorted(
      row.where(
        (l) =>
            ax - 0.02 <= l.x && l.x < ax + 0.15 && !idPattern.hasMatch(l.text),
      ),
      _byX,
    );
    final headword = heads.map((l) => cleanHead(l.text)).join();
    final important = row.any((l) => l.x < ax + 0.2 && l.text.contains('★'));
    final reading = minBy(
      row.where(
        (l) => ax + 0.15 <= l.x && l.x <= ax + 0.32 && l.height >= 0.012,
      ),
      (l) => l.cy,
    );

    final meaningParts = stableSorted(
      inBlock(
        ko,
        top - 0.012,
        top + 0.05,
      ).where((l) => l.x >= ax + 0.36 && ratio(l.text, isHangul) > 0.3),
      _byRowThenX,
    );
    final (pos, meaning) = splitPos(
      cleanMeaning(meaningParts.map((l) => l.text).join(' ')),
    );

    final example = _readExample(
      ja: ja,
      ko: ko,
      inBlock: inBlock,
      ax: ax,
      exampleTop: (reading != null ? reading.cy : top + 0.02) + 0.012,
      bottom: bottom,
      readingHeight: reading?.height ?? 0.016,
    );

    entries.add(
      CapturedEntry(
        no: anchor.no,
        headword: headword,
        readings: reading == null ? const [] : parseReadings(reading.text),
        pos: pos,
        meaning: meaning,
        important: important,
        example: example,
        issues: example == null
            ? const [EntryIssue.missing(EntryField.example)]
            : const [],
      ),
    );
  }
  return entries;
}

/// Rule 10: large Japanese lines under the word row (furigana are much shorter),
/// then the Korean translation; the 관련어 / 문형 boxes end the example.
Example? _readExample({
  required List<OcrLine> ja,
  required List<OcrLine> ko,
  required List<OcrLine> Function(List<OcrLine>, double, double) inBlock,
  required double ax,
  required double exampleTop,
  required double bottom,
  required double readingHeight,
}) {
  final cuts = [
    for (final l in inBlock(ko, exampleTop, bottom))
      if (_isRelatedBox(l.text)) l.cy,
  ];
  final exampleBottom = cuts.isNotEmpty
      ? cuts.reduce((a, b) => b < a ? b : a) - 0.004
      : bottom;

  final sentence = stableSorted(
    inBlock(ja, exampleTop, exampleBottom).where(
      (l) =>
          l.x >= ax + 0.15 &&
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
    if (l.x < ax + 0.15 || _isRelatedBox(l.text)) continue;
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
