/// Pieces of text the word extractor collects from both OCR passes.
library;

/// What a piece of text is, from its characters (and, for Japanese, its
/// punctuation and length).
enum FragmentKind {
  /// Kanji, maybe with kana after it (`運動`, `食べる`): a headword candidate.
  kanjiWord,

  /// Kana only (`ゆっくり`, `カメラ`, `うんどう`): a reading or a kana word.
  kana,

  /// Short Korean text: a meaning candidate.
  hangul,

  /// A Japanese sentence (sentence punctuation or long): split into words.
  japaneseSentence,

  /// A Korean sentence: a translation or an explanation.
  koreanSentence,

  /// Digits only: word and page numbers.
  number,

  /// Checkboxes, ★, stray symbols and OCR garbage.
  noise,
}

/// The lowest confidence Apple Vision gives (lines it barely made out).
const double lowestOcrConfidence = 0.3;

/// [confidence] is the engine's lowest or below. The device channel passes
/// Vision's 32-bit 0.3 on as 0.30000001192092896, so this allows for that.
bool atLowestConfidence(double confidence) =>
    confidence <= lowestOcrConfidence + 1e-6;

/// Which OCR pass a fragment's text came from.
enum OcrPass { japanese, korean }

final class Fragment {
  const Fragment({
    required this.id,
    required this.text,
    required this.kind,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pass,
    this.confidence = 1.0,
    this.inlineReadingOf,
    this.notes = const [],
    this.corrected = false,
    this.droppedPrefix,
    this.posBadge,
  });

  /// Position in the extractor's fragment list.
  final int id;
  final String text;
  final FragmentKind kind;

  /// Box on the upright page, normalized to 0..1 (as `OcrLine`).
  final double x;
  final double y;
  final double width;
  final double height;
  final OcrPass pass;

  /// OCR confidence of the line the fragment was cut from.
  final double confidence;

  /// For a reading printed in brackets right after its headword
  /// (`運動(うんどう)`, `図書館[としょかん]`): the headword fragment's [id].
  final int? inlineReadingOf;

  /// Explanations cut off a Korean meaning: a leading `(…)`, a trailing
  /// `(…)`, a `*…` supplement.
  final List<String> notes;

  /// Something was removed from the OCR text (checkbox glyphs, symbols,
  /// a line break joined).
  final bool corrected;

  /// A leading 口 or ロ taken off as a checkbox; the extractor puts it back
  /// when only the longer text is a dictionary word (`ロッカー`).
  final String? droppedPrefix;

  /// The POS badge printed before a Korean meaning (`명`, `동`, `い형`,
  /// `な형`, `부`…), as the row templates name it; null without one.
  final String? posBadge;

  /// JMdict POS codes the badge stands for (empty when it names none, as
  /// `형` alone).
  List<String> get badgeCodes => switch (posBadge) {
    '명' => const ['n'],
    '동' => const ['v'],
    'い형' => const ['adj-i'],
    'な형' => const ['adj-na'],
    '부' => const ['adv'],
    '감' => const ['int'],
    '접' => const ['conj'],
    '연' => const ['adj-pn'],
    '조' => const ['prt'],
    _ => const [],
  };

  double get cx => x + width / 2;
  double get cy => y + height / 2;
  double get right => x + width;
  double get bottom => y + height;

  bool get isJapanese =>
      kind == FragmentKind.kanjiWord ||
      kind == FragmentKind.kana ||
      kind == FragmentKind.japaneseSentence;

  bool get isKorean =>
      kind == FragmentKind.hangul || kind == FragmentKind.koreanSentence;

  /// Text a learner could save or that pairs with something.
  bool get isContent =>
      kind != FragmentKind.number && kind != FragmentKind.noise;

  Fragment copyWith({
    int? id,
    String? text,
    FragmentKind? kind,
    double? x,
    double? y,
    double? width,
    double? height,
    double? confidence,
    Object? inlineReadingOf = _unset,
    List<String>? notes,
    bool? corrected,
    Object? droppedPrefix = _unset,
  }) => Fragment(
    id: id ?? this.id,
    text: text ?? this.text,
    kind: kind ?? this.kind,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    pass: pass,
    confidence: confidence ?? this.confidence,
    inlineReadingOf: identical(inlineReadingOf, _unset)
        ? this.inlineReadingOf
        : inlineReadingOf as int?,
    notes: List.unmodifiable(notes ?? this.notes),
    corrected: corrected ?? this.corrected,
    droppedPrefix: identical(droppedPrefix, _unset)
        ? this.droppedPrefix
        : droppedPrefix as String?,
    posBadge: posBadge,
  );

  @override
  String toString() =>
      'Fragment#$id(${kind.name} "$text" @ ${x.toStringAsFixed(3)},'
      '${y.toStringAsFixed(3)}${inlineReadingOf == null ? '' : ' reading of #$inlineReadingOf'})';
}

const Object _unset = Object();
