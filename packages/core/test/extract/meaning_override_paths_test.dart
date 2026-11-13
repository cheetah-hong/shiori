// M1·M2: the table's meaning (시오리 보정) reaches every place a dictionary
// meaning is used — a built-in deck being added, a word typed on the word
// sheet, a dictionary word with no meaning on a page — through the
// glossary slot, and words already in the library keep what they have.
// Made-up words and senses only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

final InMemoryLexicon _lexicon = InMemoryLexicon([
  const LexiconWord(id: 9300001, kanji: ['月橋'], readings: ['つきはし'], pos: ['n']),
  const LexiconWord(
    id: 9300002,
    kanji: ['星林'],
    readings: ['ほしばやし'],
    pos: ['n'],
  ),
  const LexiconWord(
    id: 9300003,
    kanji: ['花居'],
    readings: ['はない'],
    pos: ['v1', 'vi'],
    usuallyKana: true,
  ),
  ...testWords,
]);

final class _Glossary implements KoreanGlossary {
  const _Glossary(this.senses);

  final Map<String, List<List<String>>> senses;

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => [
    for (final (i, words) in (senses[headword] ?? const []).take(limit).indexed)
      KoreanSense(words: words, source: GlossarySource.krdict, senseNo: i + 1),
  ];

  @override
  List<GlossarySourceInfo> get sources => const [];
}

const _krdict = _Glossary({
  '月橋': [
    ['돌다리'],
    ['달다리'],
  ],
  '星林': [
    ['별숲'],
  ],
  '花居': [
    ['보다'],
  ],
  'はない': [
    ['헛뜻'],
  ],
});

final _overrides = MeaningOverrides(const [
  MeaningOverride(forms: ['月橋'], reading: 'つきはし', meaning: '달빛 다리'),
  MeaningOverride(forms: ['はない', '花居'], reading: 'はない', meaning: '있다'),
]);

final KoreanGlossary _glossary = OverriddenKoreanGlossary(_krdict, _overrides);

List<OcrLine> _row(String headword, String reading, double y) => [
  line(headword, 0.10, y),
  line(reading, 0.25, y),
];

/// 月橋 and 星林 without a meaning on the page.
OcrScan _page() =>
    scan(ja: [..._row('月橋', 'つきはし', 0.10), ..._row('星林', 'ほしばやし', 0.20)]);

/// 月橋 with its meaning printed.
OcrScan _printedPage() =>
    scan(ja: _row('月橋', 'つきはし', 0.10), ko: [line('돌다리', 0.45, 0.10)]);

Future<ExtractionResult> _extract(KoreanGlossary glossary, OcrScan page) =>
    GeneralExtractor(lexicon: _lexicon, koreanGlossary: glossary).extract(page);

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

const _deck = BuiltinDeck(
  id: 'jlpt-n5',
  name: 'JLPT N5 대비',
  level: 'N5',
  words: [
    DeckWord(headword: '月橋', reading: 'つきはし', entryId: 9300001),
    // Asked as 花居 first: the table answers whichever spelling is asked.
    DeckWord(
      headword: 'はない',
      reading: 'はない',
      entryId: 9300003,
      lookupForm: '花居',
    ),
    DeckWord(headword: '星林', reading: 'ほしばやし', entryId: 9300002),
  ],
);

void main() {
  group('built-in deck', () {
    test('a word in the table gets its meaning, the others the '
        'glossary\'s', () async {
      final d = await deckDraft(_deck, lexicon: _lexicon, glossary: _glossary);

      expect(
        {for (final e in d.draft.entries) e.headword: e.meaning},
        {'月橋': '달빛 다리', 'はない': '있다', '星林': '별숲'},
      );
    });

    test('without the table the deck is what it was', () async {
      final d = await deckDraft(_deck, lexicon: _lexicon, glossary: _krdict);

      expect(
        {for (final e in d.draft.entries) e.headword: e.meaning},
        {'月橋': '돌다리', 'はない': '보다', '星林': '별숲'},
      );
    });
  });

  group('word sheet', () {
    test('a typed kanji word: the table\'s meaning first, the glossary\'s '
        'as the next suggestions', () async {
      final fill = await wordFill('月橋', lexicon: _lexicon, glossary: _glossary);

      expect(fill.meanings, ['달빛 다리', '돌다리', '달다리']);
    });

    test('a typed kana word and its kanji spelling', () async {
      final fill = await wordFill(
        'はない',
        lexicon: _lexicon,
        glossary: _glossary,
      );

      expect(fill.meanings.first, '있다');
      expect(fill.kanjiChoices.single.headword, '花居');
      expect(fill.kanjiChoices.single.meaning, '있다');
    });
  });

  group('page', () {
    test('a dictionary word with no meaning on the page takes the table\'s '
        'meaning, noted 사전 뜻: 시오리 보정, never high', () async {
      final r = await _extract(_glossary, _page());

      final w = _word(r, '月橋');
      expect(w.meaning, '달빛 다리');
      expect(w.meaningGlossary, GlossarySource.shiori);
      expect(w.meaningLink?.confidence, PairConfidence.medium);
      expect(w.meaningCandidates, contains('돌다리'));
      final cell = w.toCapturedEntry().evidence!.of(EntryField.meaning)!;
      expect(cell.note, '사전 뜻: 시오리 보정');
    });

    test('a word not in the table is what it was, byte for byte', () async {
      final r = await _extract(_glossary, _page());
      final before = await _extract(_krdict, _page());

      expect(_entry(_word(r, '星林')), _entry(_word(before, '星林')));
    });

    test('a meaning printed on the page stays; the table\'s is only a '
        'candidate', () async {
      final r = await _extract(_glossary, _printedPage());

      final w = _word(r, '月橋');
      expect(w.meaning, '돌다리');
      expect(w.meaningCandidates, contains('달빛 다리'));
    });
  });

  group('M2 words already in the library', () {
    final now = DateTime(2026, 11, 14, 9);
    late InMemoryLibraryRepository library;
    late LibraryService service;

    setUp(() {
      library = InMemoryLibraryRepository();
      service = LibraryService(library: library, clock: FixedClock(now));
    });

    test('adding the deck again keeps a stored meaning and a meaning the '
        'learner wrote', () async {
      final stored = Word(
        id: 'w-1',
        headword: '月橋',
        readings: const ['つきはし'],
        meaning: '돌다리',
        createdAt: now,
      );
      final written = Word(
        id: 'w-2',
        headword: 'はない',
        readings: const [],
        meaning: '내가 적은 뜻',
        createdAt: now,
      );
      await library.insertWords([stored, written]);

      await service.addDeck(
        await deckDraft(_deck, lexicon: _lexicon, glossary: _glossary),
      );

      final words = {for (final w in await library.words()) w.id: w};
      expect(words['w-1'], stored);
      expect(words['w-2'], written);
    });

    test('looking a saved word up again only suggests the table\'s '
        'meaning', () async {
      final fill = await wordFill('月橋', lexicon: _lexicon, glossary: _glossary);

      final merged = mergeFill(
        const WordEdit(headword: '月橋', readings: ['つきはし'], meaning: '돌다리'),
        fill,
      );

      expect(merged.edit.meaning, '돌다리');
      expect(merged.filled, isNot(contains(EntryField.meaning)));
      expect(merged.meaningSuggestions.first, '달빛 다리');
    });
  });
}
