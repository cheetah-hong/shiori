// Shared blocks for the capture tests: an in-memory Korean glossary and the
// local page sets.
import 'dart:io';

import 'package:shiori_core/shiori_core.dart';

import '../../support/fixtures.dart';
import 'extract_fixtures.dart';

/// A Korean glossary held in memory: headword → senses, each a list of
/// Korean words (first sense first). [readings] (headword → kana) let it be
/// read backwards: the spellings of a reading with their senses' words.
final class MemoryKoreanGlossary
    implements KoreanGlossary, KoreanReverseGlossary {
  MemoryKoreanGlossary(this.senses, {this.readings = const {}});

  final Map<String, List<List<String>>> senses;
  final Map<String, List<String>> readings;

  /// Headwords asked for, in order (to check what the extractor looks up).
  final List<String> asked = [];

  /// The readings of each backward lookup, in order.
  final List<List<String>> askedBackwards = [];

  @override
  Future<List<GlossedSpelling>> reverseLookup(Iterable<String> readings) async {
    final wanted = readings.toList();
    askedBackwards.add(wanted);
    return [
      for (final MapEntry(key: written, value: kana) in this.readings.entries)
        for (final r in kana)
          if (wanted.contains(r))
            for (final words in senses[written] ?? const <List<String>>[])
              GlossedSpelling(written: written, reading: r, words: words),
    ];
  }

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
  }) async {
    asked.add(headword);
    final found = senses[headword] ?? const [];
    return [
      for (final (i, words) in found.take(limit).indexed)
        KoreanSense(
          words: words,
          source: GlossarySource.krdict,
          senseNo: i + 1,
        ),
    ];
  }

  @override
  List<GlossarySourceInfo> get sources => const [];
}

/// The synthetic general pages' gloss stand-in (korean_glosses.json) as a
/// glossary: every listed word one sense.
MemoryKoreanGlossary generalGlossary() {
  final table = (readGeneralJson('korean_glosses.json')['glosses'] as Map)
      .cast<String, Object?>();
  final entries = [
    for (final e in readGeneralJson('lexicon.json')['entries']! as List)
      LexiconWord.fromJson((e as Map).cast<String, Object?>()),
  ];
  return MemoryKoreanGlossary(
    {
      for (final MapEntry(:key, :value) in table.entries)
        key: [
          [for (final w in value! as List) w as String],
        ],
    },
    // The kanji words of the table with their readings, for the backward
    // lookup (kana words are not read back).
    readings: {
      for (final key in table.keys)
        for (final e in entries)
          if (e.kanji.contains(key)) key: e.readings,
    },
  );
}

/// The word extractor on the synthetic general lexicon.
GeneralExtractor syntheticExtractor({KoreanGlossary? glossary}) =>
    GeneralExtractor(lexicon: generalLexicon(), koreanGlossary: glossary);

String get _textbook => '${privateDir()}/textbook';

/// A curled page photographed on a phone (local only, general answers).
FixtureSet get recordedCurledPage => FixtureSet(
  'curled page photographed on a phone',
  '$_textbook/device-iphone13mini/fixtures',
  truthDir: '$_textbook/device-iphone13mini/general',
);

/// Three pages of another textbook (local only, general answers).
FixtureSet get recordedOtherBook => FixtureSet(
  'pages of another textbook',
  '$_textbook/other-books/fixtures',
  truthDir: '$_textbook/other-books',
);

/// Fixture names of a folder of recorded passes, sorted.
List<String> fixturesIn(String dir) => [
  for (final f in Directory(dir).listSync())
    if (f.path.endsWith('.ja.json'))
      f.uri.pathSegments.last.replaceAll('.ja.json', ''),
]..sort();
