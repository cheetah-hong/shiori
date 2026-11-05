/// OCR output shared by every `TextRecognizer` block.
///
/// JSON shape (same as the research probe and both native channels):
/// `{"engine": "apple-vision", "langs": [...], "ms": 696,
///   "lines": [{"t": "1408 ロロロ", "c": 0.5, "x": .., "y": .., "w": .., "h": ..}]}`
/// Boxes are normalized to 0..1 with the origin at the top-left of the upright page.
library;

/// `OcrPage.engine` of the ML Kit channel (Android).
const String mlKitEngine = 'mlkit';

/// `OcrPage.engine` of the Apple Vision channel (iOS).
const String appleVisionEngine = 'apple-vision';

final class OcrLine {
  const OcrLine({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.confidence = 1.0,
  });

  /// Throws [FormatException] when a field is missing or has the wrong type,
  /// so a broken OCR block fails loudly instead of placing text at 0,0.
  factory OcrLine.fromJson(Map<String, Object?> json) {
    final text = json['t'];
    if (text is! String) {
      throw FormatException('OCR line needs a string "t"', json);
    }
    return OcrLine(
      text: text,
      confidence: json.containsKey('c') ? _requireNum(json, 'c') : 1.0,
      x: _requireNum(json, 'x'),
      y: _requireNum(json, 'y'),
      width: _requireNum(json, 'w'),
      height: _requireNum(json, 'h'),
    );
  }

  final String text;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  /// Vertical centre of the box.
  double get cy => y + height / 2;

  Map<String, Object?> toJson() => {
    't': text,
    'c': confidence,
    'x': x,
    'y': y,
    'w': width,
    'h': height,
  };

  @override
  String toString() => 'OcrLine("$text" @ $x,$y ${width}x$height)';
}

/// One recognition pass over a page (for example the Japanese-first pass).
final class OcrPage {
  const OcrPage({
    required this.lines,
    this.engine = 'unknown',
    this.languages = const [],
    this.elapsed = Duration.zero,
  });

  factory OcrPage.fromJson(Map<String, Object?> json) {
    final rawLines = json['lines'];
    if (rawLines is! List) {
      throw const FormatException('OcrPage JSON has no "lines" list');
    }
    // The engine switches confidence rules on, so it must be what it says.
    // The language list is only a label.
    final engine = json['engine'];
    if (engine != null && engine is! String) {
      throw FormatException('OcrPage "engine" must be a string', json);
    }
    return OcrPage(
      engine: engine as String? ?? 'unknown',
      languages: switch (json['langs']) {
        final List<Object?> langs => [for (final l in langs) '$l'],
        _ => const [],
      },
      elapsed: Duration(milliseconds: _optionalNum(json, 'ms').round()),
      lines: List.unmodifiable([
        for (final l in rawLines) OcrLine.fromJson(_map(l)),
      ]),
    );
  }

  final List<OcrLine> lines;
  final String engine;
  final List<String> languages;
  final Duration elapsed;

  /// Confidence values are on ML Kit's scale (continuous, meaningful), so rules
  /// with confidence thresholds may run. Vision reports only 0.3, 0.5 and 1.0.
  bool get isMlKit => engine == mlKitEngine;

  OcrPage withLines(List<OcrLine> lines) => OcrPage(
    lines: List.unmodifiable(lines),
    engine: engine,
    languages: languages,
    elapsed: elapsed,
  );

  Map<String, Object?> toJson() => {
    'engine': engine,
    'langs': languages,
    'ms': elapsed.inMilliseconds,
    'lines': [for (final l in lines) l.toJson()],
  };
}

/// The passes a page gets: Japanese-first and Korean-first, and optionally a
/// third Japanese pass that only contributes ★ marks.
///
/// Japanese text (headwords, readings, examples) is read from [japanese];
/// Korean text (meanings, translations, footer) from [korean].
final class OcrScan {
  const OcrScan({required this.japanese, required this.korean, this.stars});

  /// Accepts `{"ja": OcrPage, "ko": OcrPage, "star"?: OcrPage}`, the native
  /// channel payload.
  factory OcrScan.fromJson(Map<String, Object?> json) => OcrScan(
    japanese: OcrPage.fromJson(_map(json['ja'])),
    korean: OcrPage.fromJson(_map(json['ko'])),
    stars: json['star'] == null ? null : OcrPage.fromJson(_map(json['star'])),
  );

  final OcrPage japanese;
  final OcrPage korean;

  /// Japanese pass over a binarized copy of the same image (same frame).
  /// Vision misses some ★ marks on the colour photo and reads them here; only
  /// its ★ glyphs are used, everything else comes from [japanese].
  final OcrPage? stars;

  Duration get elapsed =>
      japanese.elapsed + korean.elapsed + (stars?.elapsed ?? Duration.zero);

  Map<String, Object?> toJson() => {
    'ja': japanese.toJson(),
    'ko': korean.toJson(),
    if (stars case final s?) 'star': s.toJson(),
  };
}

double _requireNum(Map<String, Object?> json, String key) {
  final v = json[key];
  if (v is num && v.isFinite) return v.toDouble();
  throw FormatException('OCR field "$key" must be a finite number', json);
}

double _optionalNum(Map<String, Object?> json, String key) {
  final v = json[key];
  return v is num && v.isFinite ? v.toDouble() : 0.0;
}

Map<String, Object?> _map(Object? v) {
  if (v is Map) return v.cast<String, Object?>();
  throw FormatException('expected a JSON object, got ${v.runtimeType}');
}
