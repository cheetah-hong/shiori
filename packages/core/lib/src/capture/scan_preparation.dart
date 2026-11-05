/// Line clean-up that every template needs, run once before layout detection.
///
/// 1. ML Kit only: drop lines read with very low confidence. They are one
///    language's pass reading the other language (Korean read as Japanese).
/// 2. Symbol noise: cut ★ ☆ * ＊ out of the Japanese lines and drop them
///    (`★かわ`, `乗り換える*のりかえる`, a lone `*`). The textbook prints a ★
///    beside some words; it means nothing to the learner, and left in a line
///    it would end up in a headword or a reading.
library;

import 'package:shiori_core/src/models/ocr.dart';

/// Symbols that are noise in a cell: the textbook's ★ and how OCR misreads it.
const String symbolNoiseGlyphs = '★*☆＊';

/// ML Kit lines below this confidence are garbage (other-language passes).
const double mlKitLowConfidence = 0.2;

OcrScan prepareScan(OcrScan scan) {
  var ja = scan.japanese.lines;
  var ko = scan.korean.lines;
  if (scan.japanese.isMlKit) {
    ja = [
      for (final l in ja)
        if (l.confidence >= mlKitLowConfidence) l,
    ];
  }
  if (scan.korean.isMlKit) {
    ko = [
      for (final l in ko)
        if (l.confidence >= mlKitLowConfidence) l,
    ];
  }
  return OcrScan(
    japanese: scan.japanese.withLines(dropSymbolNoise(ja)),
    korean: scan.korean.withLines(ko),
    turned: scan.turned,
  );
}

final RegExp _symbolSplit = RegExp('([${RegExp.escape(symbolNoiseGlyphs)}])');

bool _isSymbol(String piece) =>
    piece.runes.length == 1 && symbolNoiseGlyphs.contains(piece);

/// Lines without a noise symbol stay as they are. The others are cut at each
/// symbol into the pieces between them, with x and width shared out by
/// character count; the symbols and blank pieces are dropped.
List<OcrLine> dropSymbolNoise(List<OcrLine> lines) {
  final out = <OcrLine>[];
  for (final l in lines) {
    if (!_symbolSplit.hasMatch(l.text)) {
      out.add(l);
      continue;
    }
    final cw = l.width / l.text.runes.length;
    var pos = 0;
    for (final piece in _pieces(l.text)) {
      final body = piece.trim();
      if (body.isNotEmpty && !_isSymbol(body)) {
        final lead = piece.runes.length - piece.trimLeft().runes.length;
        out.add(
          OcrLine(
            text: body,
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
  for (final m in _symbolSplit.allMatches(s)) {
    out
      ..add(s.substring(start, m.start))
      ..add(m.group(0)!);
    start = m.end;
  }
  out.add(s.substring(start));
  return out;
}
