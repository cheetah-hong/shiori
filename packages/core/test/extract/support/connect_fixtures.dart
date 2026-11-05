// Shared blocks for the tests of the routed capture (row template or general
// extractor): an in-memory Korean glossary and the local page sets.
import 'dart:io';

import 'package:shiori_core/shiori_core.dart';

import '../../support/fixtures.dart';
import 'extract_fixtures.dart';

/// A Korean glossary held in memory: headword → senses, each a list of
/// Korean words (first sense first).
final class MemoryKoreanGlossary implements KoreanGlossary {
  MemoryKoreanGlossary(this.senses);

  final Map<String, List<List<String>>> senses;

  /// Headwords asked for, in order (to check what the extractor looks up).
  final List<String> asked = [];

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
  return MemoryKoreanGlossary({
    for (final MapEntry(:key, :value) in table.entries)
      key: [
        [for (final w in value! as List) w as String],
      ],
  });
}

/// The row-template pipeline the reference scores were measured with.
CapturePipeline templatePipeline() => CapturePipeline.standard();

/// The routed capture on the synthetic general lexicon.
CaptureRouter syntheticRouter({KoreanGlossary? glossary}) => CaptureRouter(
  template: templatePipeline(),
  general: GeneralExtractor(
    lexicon: generalLexicon(),
    koreanGlossary: glossary,
  ),
);

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
