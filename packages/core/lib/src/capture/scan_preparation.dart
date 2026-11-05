/// Line clean-up that every template needs, run once before layout detection.
///
/// 1. ML Kit only: drop lines read with very low confidence. They are one
///    language's pass reading the other language (Korean read as Japanese).
/// 2. Add the ★ glyphs of the optional star pass to the Japanese pass.
/// 3. Split a ★ (or `*`) glued to its neighbour (`★かわ`, `乗り換える*のりかえる`)
///    into a line of its own, so the reading cell stays kana only.
library;

import 'package:shiori_core/src/models/ocr.dart';

/// Glyphs OCR returns for the printed ★ mark.
const String starGlyphs = '★*☆＊';

/// ML Kit lines below this confidence are garbage (other-language passes).
const double mlKitLowConfidence = 0.2;

/// Stars taken from the star pass: ★ and ☆ only (`*` is common noise there).
final RegExp _starPassGlyph = RegExp('[★☆]');

/// The legend at the top of a page (`★ 표시 = …`) also prints a ★.
final RegExp _starLegend = RegExp(r'표시|[=＝]|[0-9]{4}');

OcrScan prepareScan(OcrScan scan) {
  var ja = scan.japanese.lines;
  var ko = scan.korean.lines;
  if (scan.japanese.isMlKit) {
    // A lone star scores low but is placed by position; keep it.
    ja = [
      for (final l in ja)
        if (l.confidence >= mlKitLowConfidence || _isLoneStar(l.text)) l,
    ];
  }
  if (scan.korean.isMlKit) {
    ko = [
      for (final l in ko)
        if (l.confidence >= mlKitLowConfidence) l,
    ];
  }
  if (scan.stars case final stars?) {
    ja = [...ja, ...starPassMarks(stars.lines)];
  }
  // The star pass is merged now; dropping it keeps a second call from adding
  // its marks twice.
  return OcrScan(
    japanese: scan.japanese.withLines(splitGluedStars(ja)),
    korean: scan.korean.withLines(ko),
  );
}

bool _isLoneStar(String text) {
  final t = text.trim();
  return t.runes.length == 1 && starGlyphs.contains(t);
}

/// Every ★ / ☆ of the star pass as a `★` line at its estimated place
/// (characters are taken as equally wide; the pass gives no glyph boxes).
List<OcrLine> starPassMarks(List<OcrLine> lines) => [
  for (final l in lines)
    if (!_starLegend.hasMatch(l.text))
      for (final m in _starPassGlyph.allMatches(l.text))
        OcrLine(
          text: '★',
          confidence: l.confidence,
          x: l.x + _runeIndex(l.text, m.start) * _charWidth(l),
          y: l.y,
          width: _charWidth(l),
          height: l.height,
        ),
];

double _charWidth(OcrLine l) {
  final n = l.text.runes.length;
  return l.width / (n == 0 ? 1 : n);
}

int _runeIndex(String s, int codeUnitIndex) =>
    s.substring(0, codeUnitIndex).runes.length;

final RegExp _starSplit = RegExp('([${RegExp.escape(starGlyphs)}])');

/// Lines with a star glyph and other text become one line per piece, with x and
/// width shared out by character count. A lone `*` / `☆` becomes `★`.
List<OcrLine> splitGluedStars(List<OcrLine> lines) {
  final out = <OcrLine>[];
  for (final l in lines) {
    final runes = l.text.runes.toList();
    final hasStar = runes.any((c) => starGlyphs.runes.contains(c));
    if (!hasStar || l.text.trim().runes.length <= 1) {
      out.add(_isLoneStar(l.text) ? _withText(l, '★') : l);
      continue;
    }
    final cw = l.width / runes.length;
    var pos = 0;
    for (final piece in _pieces(l.text)) {
      final body = piece.trim();
      if (body.isNotEmpty) {
        final lead = piece.runes.length - piece.trimLeft().runes.length;
        out.add(
          OcrLine(
            text: _isLoneStar(body) ? '★' : body,
            confidence: l.confidence,
            x: l.x + (pos + lead) * cw,
            y: l.y,
            width: body.runes.length * cw,
            height: l.height,
          ),
        );
      }
      pos += piece.runes.length;
    }
  }
  return out;
}

/// `a★b` → [`a`, `★`, `b`] (Python `re.split` with a capture group).
List<String> _pieces(String s) {
  final out = <String>[];
  var start = 0;
  for (final m in _starSplit.allMatches(s)) {
    out
      ..add(s.substring(start, m.start))
      ..add(m.group(0)!);
    start = m.end;
  }
  out.add(s.substring(start));
  return out;
}

OcrLine _withText(OcrLine l, String text) => OcrLine(
  text: text,
  confidence: l.confidence,
  x: l.x,
  y: l.y,
  width: l.width,
  height: l.height,
);
