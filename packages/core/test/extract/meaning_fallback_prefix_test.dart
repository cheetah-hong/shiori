// A word with an optional prefix in brackets (`(お)X`): when the glossary has
// one of its forms (おX), that meaning stays even though the fallback has
// another form (X). The fallback is asked only when no form is in the
// glossary. Made-up words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

/// Looks a headword up as the glossary block does: bracketed parts dropped
/// (`(お)雪森` → 雪森).
final class _Glossary implements KoreanGlossary {
  _Glossary(this.senses, this.source);

  final Map<String, String> senses;
  final GlossarySource source;
  final List<String> asked = [];

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async {
    asked.add(headword);
    final key = headword.replaceAll(RegExp(r'[(（][^)）]*[)）]'), '');
    return [
      if (senses[key] case final w?) KoreanSense(words: [w], source: source),
    ];
  }

  @override
  List<GlossarySourceInfo> get sources => const [];
}

final InMemoryLexicon _lexicon = InMemoryLexicon(const [
  LexiconWord(
    id: 9400001,
    kanji: ['(お)雪森', 'お雪森', '雪森'],
    readings: ['おゆきもり', 'ゆきもり'],
    pos: ['n'],
  ),
]);

OcrScan _page() =>
    scan(ja: [line('(お)雪森', 0.10, 0.10), line('おゆきもり', 0.25, 0.10)]);

Future<ExtractedWord> _word(
  KoreanGlossary glossary,
  KoreanGlossary? fb,
) async => (await GeneralExtractor(
  lexicon: _lexicon,
  koreanGlossary: glossary,
  meaningFallback: fb,
).extract(_page())).words.single;

void main() {
  test('the glossary\'s おX wins over the fallback\'s X', () async {
    final glossary = _Glossary({'お雪森': '눈숲'}, GlossarySource.krdict);
    final fallback = _Glossary({'雪森': '겨울 숲'}, GlossarySource.wiktionary);

    final alone = await _word(glossary, null);
    final w = await _word(glossary, fallback);

    expect(alone.meaning, '눈숲');
    expect(w.meaning, '눈숲');
    expect(w.meaningGlossary, GlossarySource.krdict);
    expect(fallback.asked, isEmpty);
  });

  test('no form in the glossary: the fallback, under the same forms', () async {
    final glossary = _Glossary(const {}, GlossarySource.krdict);
    final fallback = _Glossary({'お雪森': '겨울 숲'}, GlossarySource.wiktionary);

    final w = await _word(glossary, fallback);

    expect(w.meaning, '겨울 숲');
    expect(w.meaningGlossary, GlossarySource.wiktionary);
    expect(fallback.asked, contains('お雪森'));
  });
}
