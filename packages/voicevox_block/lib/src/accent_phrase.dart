import 'dart:convert';

/// One accent phrase of a VOICEVOX audio query, kept as the engine's JSON so
/// nothing the engine needs is lost on the way back.
final class AccentPhrase {
  AccentPhrase._(this._json, this.moraTexts, this.accent);

  /// Throws [FormatException] when [json] has no moras or no accent.
  factory AccentPhrase.fromJson(Map<String, Object?> json) {
    final moras = json['moras'];
    final accent = json['accent'];
    if (moras is! List<Object?> || moras.isEmpty || accent is! int) {
      throw const FormatException('accent phrase: no moras or no accent');
    }
    final texts = [
      for (final m in moras)
        switch (m) {
          {'text': final String t} => t,
          _ => throw const FormatException('accent phrase: a mora has no text'),
        },
    ];
    return AccentPhrase._(
      jsonDecode(jsonEncode(json)) as Map<String, Object?>,
      List.unmodifiable(texts),
      accent,
    );
  }

  /// The phrases of an `accent_phrases` JSON array.
  static List<AccentPhrase> listFromJson(String json) =>
      switch (jsonDecode(json)) {
        final List<Object?> list => List.unmodifiable([
          for (final p in list)
            if (p is Map<String, Object?>)
              AccentPhrase.fromJson(p)
            else
              throw const FormatException('accent phrases: not an object'),
        ]),
        _ => throw const FormatException('accent phrases: not a list'),
      };

  /// JSON array of [phrases] for the engine.
  static String listToJson(List<AccentPhrase> phrases) =>
      jsonEncode([for (final p in phrases) p._json]);

  final Map<String, Object?> _json;

  /// Kana of each mora (`ハ`, `シ`, …).
  final List<String> moraTexts;

  /// The engine's accent: 1…n, where n (the number of morae) means flat.
  final int accent;

  /// A copy with another accent; the pitches are made again by the engine
  /// ([VoicevoxOps.replaceMoraPitch]).
  AccentPhrase withAccent(int accent) =>
      AccentPhrase.fromJson({...toJson(), 'accent': accent});

  /// A deep copy of the engine's JSON.
  Map<String, Object?> toJson() =>
      jsonDecode(jsonEncode(_json)) as Map<String, Object?>;
}
