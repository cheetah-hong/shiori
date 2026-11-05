import 'package:shiori_core/src/eval/ground_truth.dart';

/// Answers for word extraction, matched by headword (`ground_truth.json`
/// with `"format": "general-1"`).
///
/// `{"pages": [{"page", "fixture", "kind", "vocab": [{"headword",
/// "readings", "meaning"}], "sentence_words": [...], "ignore": [...]}]}`
final class ExtractTruth {
  const ExtractTruth(this.pages);

  /// Throws [FormatException] when a field has the wrong shape.
  factory ExtractTruth.fromJson(Map<String, Object?> json) {
    final pages = json['pages'];
    if (pages is! List) {
      throw const FormatException('answers need a "pages" list');
    }
    return ExtractTruth([
      for (final p in pages) ExtractTruthPage.fromJson(_map(p)),
    ]);
  }

  /// The template answers as extraction answers: every entry is a printed
  /// word; nothing comes from sentences.
  factory ExtractTruth.fromLegacy(GroundTruth truth) => ExtractTruth([
    for (final p in truth.pages)
      ExtractTruthPage(
        page: '${p.page}',
        fixture: p.fixture,
        kind: 'template',
        scoresSentences: false,
        vocab: [
          for (final e in p.entries)
            TruthWord(
              headword: e.headword,
              readings: e.readings,
              meaning: e.meaning,
            ),
        ],
      ),
  ]);

  /// Either answer format: `"format": "general-1"`, or the template answers.
  factory ExtractTruth.fromAnyJson(Map<String, Object?> json) =>
      json['format'] == 'general-1'
      ? ExtractTruth.fromJson(json)
      : ExtractTruth.fromLegacy(GroundTruth.fromJson(json));

  final List<ExtractTruthPage> pages;
}

final class ExtractTruthPage {
  const ExtractTruthPage({
    required this.page,
    required this.fixture,
    this.kind = '',
    this.vocab = const [],
    this.sentenceWords = const [],
    this.ignore = const {},
    this.scoresSentences = true,
  });

  factory ExtractTruthPage.fromJson(Map<String, Object?> json) =>
      ExtractTruthPage(
        page: _string(json, 'page'),
        fixture: _string(json, 'fixture'),
        kind: json['kind'] is String ? json['kind']! as String : '',
        vocab: [
          for (final v in _list(json, 'vocab')) TruthWord.fromJson(_map(v)),
        ],
        sentenceWords: [
          for (final w in _list(json, 'sentence_words')) _asString(w),
        ],
        ignore: {for (final w in _list(json, 'ignore')) _asString(w)},
        scoresSentences: json['scores_sentences'] != false,
      );

  final String page;
  final String fixture;
  final String kind;

  /// Words printed as words, with their readings and meanings.
  final List<TruthWord> vocab;

  /// Dictionary forms the page's sentences should give.
  final List<String> sentenceWords;

  /// Headwords that cost nothing when returned.
  final Set<String> ignore;

  /// False for template answers: they list no sentence words, so words from
  /// the page's example sentences are neither scored nor counted as extras.
  final bool scoresSentences;
}

final class TruthWord {
  const TruthWord({
    required this.headword,
    this.readings = const [],
    this.meaning,
  });

  factory TruthWord.fromJson(Map<String, Object?> json) => TruthWord(
    headword: _string(json, 'headword'),
    readings: [for (final r in _list(json, 'readings')) _asString(r)],
    meaning: switch (json['meaning']) {
      null => null,
      final String m => m,
      final m => throw FormatException('"meaning" must be a string', m),
    },
  );

  final String headword;

  /// Empty for kana words.
  final List<String> readings;

  /// Null when the page prints no meaning (not scored).
  final String? meaning;
}

Map<String, Object?> _map(Object? v) => v is Map
    ? v.cast<String, Object?>()
    : throw FormatException('expected an object', v);

List<Object?> _list(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      null => const [],
      final List<Object?> l => l,
      final v => throw FormatException('"$key" must be a list', v),
    };

String _string(Map<String, Object?> json, String key) => switch (json[key]) {
  final String s => s,
  final int n => '$n',
  final v => throw FormatException('"$key" must be a string', v),
};

String _asString(Object? v) =>
    v is String ? v : throw FormatException('expected a string', v);
