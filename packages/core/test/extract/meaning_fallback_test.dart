// W3: the word extractor fills a dictionary word's empty meaning from the
// fallback glossary only when the glossary has no sense for it. Everything
// else (pairing, a page's own meanings and their candidates, words the
// glossary knows) is what the extractor gives without the fallback.
// Made-up words and senses only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

final InMemoryLexicon _lexicon = InMemoryLexicon([
  const LexiconWord(id: 9200001, kanji: ['雪森'], readings: ['ゆきもり'], pos: ['n']),
  const LexiconWord(id: 9200002, kanji: ['月道'], readings: ['つきみち'], pos: ['n']),
  const LexiconWord(id: 9200003, kanji: ['風路'], readings: ['かぜじ'], pos: ['n']),
  const LexiconWord(id: 9200004, kanji: ['星波'], readings: ['ほしなみ'], pos: ['n']),
  ...testWords,
]);

final class _Glossary implements KoreanGlossary {
  _Glossary(this.senses, this.source);

  final Map<String, List<List<String>>> senses;
  final GlossarySource source;
  final List<({String headword, int limit})> calls = [];

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async {
    calls.add((headword: headword, limit: limit));
    return [
      for (final (i, words)
          in (senses[headword] ?? const []).take(limit).indexed)
        KoreanSense(words: words, source: source, senseNo: i + 1),
    ];
  }

  @override
  List<GlossarySourceInfo> get sources => const [];
}

_Glossary _krdict() => _Glossary({
  '雪森': [
    ['눈숲'],
    ['설산'],
  ],
}, GlossarySource.krdict);

_Glossary _wiktionary() => _Glossary({
  '雪森': [
    ['겨울 숲'],
  ],
  '月道': [
    ['달길', '월로'],
    ['달빛 길'],
  ],
  '星波': [
    ['별물결'],
  ],
}, GlossarySource.wiktionary);

List<OcrLine> _row(String headword, String reading, double y) => [
  line(headword, 0.10, y),
  line(reading, 0.25, y),
];

/// 雪森 and 月道 without a meaning on the page, 風路 known to neither,
/// 星波 with its meaning printed.
OcrScan _page() => scan(
  ja: [
    ..._row('雪森', 'ゆきもり', 0.10),
    ..._row('月道', 'つきみち', 0.20),
    ..._row('風路', 'かぜじ', 0.30),
    ..._row('星波', 'ほしなみ', 0.40),
  ],
  ko: [line('별의 물결', 0.45, 0.40)],
);

Future<ExtractionResult> _extract(
  _Glossary glossary, {
  KoreanGlossary? fallback,
}) => GeneralExtractor(
  lexicon: _lexicon,
  koreanGlossary: glossary,
  meaningFallback: fallback,
).extract(_page());

ExtractedWord _word(ExtractionResult r, String headword) =>
    r.words.singleWhere((w) => w.headword == headword);

String _entry(ExtractedWord w) {
  final e = w.toCapturedEntry();
  final cell = e.evidence?.of(EntryField.meaning);
  return [
    e.headword,
    e.readings.join('/'),
    e.meaning,
    cell?.source.name,
    cell?.confidence?.name,
    cell?.note,
    cell?.candidates.join('|'),
    e.issues.join(','),
  ].join('\t');
}

void main() {
  test('a word the glossary knows keeps the glossary\'s meaning, byte for '
      'byte', () async {
    final without = await _extract(_krdict());
    final withFallback = await _extract(_krdict(), fallback: _wiktionary());

    expect(_entry(_word(withFallback, '雪森')), _entry(_word(without, '雪森')));
    expect(_word(withFallback, '雪森').meaning, '눈숲');
  });

  test('a word the glossary lacks takes the fallback\'s first sense, the '
      'others as candidates, never high, shown as 위키낱말사전', () async {
    final r = await _extract(_krdict(), fallback: _wiktionary());

    final w = _word(r, '月道');
    expect(w.meaning, '달길, 월로');
    expect(w.meaningSource, FieldSource.dictionary);
    expect(w.meaningLink?.confidence, PairConfidence.medium);
    expect(w.meaningCandidates, ['달빛 길']);
    final cell = w.toCapturedEntry().evidence!.of(EntryField.meaning)!;
    expect(cell.source, FieldSource.dictionary);
    expect(cell.confidence, PairConfidence.medium);
    expect(cell.note, contains('위키낱말사전'));
    expect(cell.candidates, ['달빛 길']);
  });

  test('a meaning from the glossary is still noted 사전 뜻 alone', () async {
    final r = await _extract(_krdict(), fallback: _wiktionary());

    final cell = _word(
      r,
      '雪森',
    ).toCapturedEntry().evidence!.of(EntryField.meaning)!;
    expect(cell.note, '사전 뜻');
  });

  test('known to neither: no meaning, as without the fallback', () async {
    final without = await _extract(_krdict());
    final r = await _extract(_krdict(), fallback: _wiktionary());

    expect(_word(r, '風路').meaning, isNull);
    expect(_entry(_word(r, '風路')), _entry(_word(without, '風路')));
  });

  test(
    'a meaning read from the page stays, with no fallback candidates',
    () async {
      final without = await _extract(_krdict());
      final r = await _extract(_krdict(), fallback: _wiktionary());

      expect(_word(r, '星波').meaning, '별의 물결');
      expect(_word(r, '星波').meaningCandidates, isEmpty);
      expect(_entry(_word(r, '星波')), _entry(_word(without, '星波')));
    },
  );

  test('the fallback is asked only to fill an empty meaning the glossary '
      'cannot, never for pairing', () async {
    final fallback = _wiktionary();
    await _extract(_krdict(), fallback: fallback);

    expect({for (final c in fallback.calls) c.headword}, {'月道', '風路'});
    for (final c in fallback.calls) {
      expect(c.limit, meaningSenses);
    }
  });

  test('only the words the fallback filled differ', () async {
    final without = await _extract(_krdict());
    final r = await _extract(_krdict(), fallback: _wiktionary());

    expect(r.words.length, without.words.length);
    for (final (i, w) in r.words.indexed) {
      final before = without.words[i];
      expect(w.headword, before.headword);
      if (before.meaning == null && w.meaning != null) continue;
      expect(_entry(w), _entry(before), reason: w.headword);
    }
    expect(
      [for (final f in r.unpaired) f.text],
      [for (final f in without.unpaired) f.text],
    );
  });
}
