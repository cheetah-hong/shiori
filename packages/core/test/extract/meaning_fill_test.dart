// M2–M4, R5: the meaning a dictionary word gets when the page gives none,
// and the senses offered as candidates. The pairing lookup is as before;
// the meaning lookup takes the class the word is printed as (the page's
// badge, else the dictionary's), asks for five senses, puts the sense that
// spells the kanji in Korean readings first (two syllables or more, one for
// a numeral, never an affix) and, for a sentence word, the sense its printed
// translation names. A meaning read from the page never changes.
// Made-up words and senses only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

/// Made-up words (ids out of JMdict's range).
final InMemoryLexicon _lexicon = InMemoryLexicon([
  const LexiconWord(id: 9100001, kanji: ['雪森'], readings: ['ゆきもり'], pos: ['n']),
  const LexiconWord(
    id: 9100002,
    kanji: ['静走'],
    readings: ['せいそう'],
    pos: ['n', 'vs'],
  ),
  const LexiconWord(id: 9100003, kanji: ['三'], readings: ['さん'], pos: ['num']),
  const LexiconWord(id: 9100004, kanji: ['二'], readings: ['に'], pos: ['num']),
  const LexiconWord(id: 9100005, kanji: ['森'], readings: ['もり'], pos: ['n']),
  const LexiconWord(id: 9100006, kanji: ['風路'], readings: ['かぜじ'], pos: ['n']),
  const LexiconWord(
    id: 9100007,
    kanji: ['空言'],
    readings: ['そらごと'],
    pos: ['exp'],
  ),
  const LexiconWord(id: 9100008, readings: ['ふわり'], pos: ['n']),
  const LexiconWord(id: 9100009, readings: ['ころり'], pos: ['n']),
  const LexiconWord(id: 9100010, readings: ['ぽかる'], pos: ['v5r', 'vi']),
  const LexiconWord(
    id: 9100011,
    kanji: ['灯台草'],
    readings: ['とうだいぐさ'],
    pos: ['n'],
  ),
  ...testWords,
]);

MemoryKoreanGlossary _glossary() => MemoryKoreanGlossary({
  '雪森': [
    ['눈숲'],
    ['설삼'],
  ],
  '静走': [
    ['조용히달리기'],
    ['정주하다'],
  ],
  '三': [
    ['셋'],
    ['삼'],
  ],
  '二': [
    ['둘'],
    ['-이'],
  ],
  '森': [
    ['숲'],
    ['삼'],
  ],
  '風路': [
    ['바람길'],
    ['바람골'],
    ['샛길'],
    ['갈림길'],
    ['하늬길'],
    ['마파람길'],
  ],
  '空言': [
    ['빈말'],
    ['헛소리'],
  ],
  'ふわり': [
    ['보송'],
    ['솜사탕'],
  ],
  'ころり': [
    ['데굴'],
    ['구름'],
  ],
  'ぽかる': [
    ['빛나다'],
    ['반짝이다'],
  ],
  '灯台草': [
    ['등대풀'],
    ['갯버들'],
    ['물매화'],
  ],
});

/// One word-list row: [headword] and [reading], and [meaning] to the right
/// when the page prints one.
List<OcrLine> _row(String headword, String reading, double y) => [
  line(headword, 0.10, y),
  line(reading, 0.25, y),
];

Future<ExtractionResult> _extract(
  OcrScan page,
  MemoryKoreanGlossary glossary,
) =>
    GeneralExtractor(lexicon: _lexicon, koreanGlossary: glossary).extract(page);

ExtractedWord _word(ExtractionResult r, String headword) =>
    r.words.singleWhere((w) => w.headword == headword);

/// The class hints of the lookups for [headword] that asked for five senses.
List<PartOfSpeech?> _meaningHints(MemoryKoreanGlossary g, String headword) => [
  for (final c in g.calls)
    if (c.headword == headword && c.limit == 5) c.pos,
];

void main() {
  group('M2 where the class hint comes from', () {
    test('no badge on the page: the dictionary\'s class', () async {
      final g = _glossary();
      await _extract(scan(ja: _row('雪森', 'ゆきもり', 0.10)), g);

      expect(_meaningHints(g, '雪森'), isNotEmpty);
      expect(_meaningHints(g, '雪森').toSet(), {PartOfSpeech.noun});
    });

    test(
      'the badge printed before the meaning wins over the dictionary',
      () async {
        final g = _glossary();
        final r = await _extract(
          scan(ja: _row('雪森', 'ゆきもり', 0.10), ko: [line('동 눈숲', 0.45, 0.10)]),
          g,
        );

        final w = _word(r, '雪森');
        expect(w.meaning, '눈숲');
        expect(w.meaningSource, FieldSource.photo);
        expect(w.printedPos, PartOfSpeech.verb);
        expect(_meaningHints(g, '雪森').toSet(), {PartOfSpeech.verb});
      },
    );

    test('neither a badge nor a class the dictionary names: no hint', () async {
      final g = _glossary();
      final r = await _extract(scan(ja: _row('空言', 'そらごと', 0.10)), g);

      expect(_word(r, '空言').meaning, '빈말');
      expect(_meaningHints(g, '空言'), isNotEmpty);
      expect(_meaningHints(g, '空言').toSet(), {null});
    });

    test('the pairing lookup is as before: three senses, no hint', () async {
      final g = _glossary();
      await _extract(
        scan(ja: _row('雪森', 'ゆきもり', 0.10), ko: [line('동 눈숲', 0.45, 0.10)]),
        g,
      );

      final pairing = [
        for (final c in g.calls)
          if (c.headword == '雪森' && c.limit != 5) c,
      ];
      expect(pairing, isNotEmpty);
      for (final c in pairing) {
        expect(c.limit, 3);
        expect(c.pos, isNull);
      }
    });
  });

  group('the sense that spells the kanji in Korean readings comes first', () {
    Future<ExtractedWord> filled(String headword, String reading) async {
      final r = await _extract(
        scan(ja: _row(headword, reading, 0.10)),
        _glossary(),
      );
      final w = _word(r, headword);
      expect(w.meaningSource, FieldSource.dictionary, reason: headword);
      return w;
    }

    test('two syllables: 雪森 → 설삼, 눈숲 a candidate', () async {
      final w = await filled('雪森', 'ゆきもり');
      expect(w.meaning, '설삼');
      expect(w.meaningCandidates, ['눈숲']);
    });

    test('the reading with 하다 counts: 静走 → 정주하다', () async {
      expect((await filled('静走', 'せいそう')).meaning, '정주하다');
    });

    test('a numeral needs one syllable: 三 → 삼', () async {
      expect((await filled('三', 'さん')).meaning, '삼');
    });

    test('one syllable of another kanji does not count: 森 stays 숲', () async {
      expect((await filled('森', 'もり')).meaning, '숲');
    });

    test('an affix does not count: 二 stays 둘', () async {
      expect((await filled('二', 'に')).meaning, '둘');
    });

    test('no sense spells it: the glossary\'s order', () async {
      final w = await filled('灯台草', 'とうだいぐさ');
      expect(w.meaning, '등대풀');
      expect(w.meaningCandidates, ['갯버들', '물매화']);
    });
  });

  group('M4 at most four candidates, in order', () {
    test('a filled meaning: the first sense, then the next four', () async {
      final r = await _extract(scan(ja: _row('風路', 'かぜじ', 0.10)), _glossary());

      final w = _word(r, '風路');
      expect(w.meaning, '바람길');
      expect(w.meaningCandidates, ['바람골', '샛길', '갈림길', '하늬길']);
      final cell = w
          .toCapturedEntry(fragments: r.fragments)
          .evidence!
          .of(EntryField.meaning)!;
      expect(cell.candidates, ['바람골', '샛길', '갈림길', '하늬길']);
    });

    test(
      'a meaning read from the page: the other senses, at most four',
      () async {
        final r = await _extract(
          scan(ja: _row('風路', 'かぜじ', 0.10), ko: [line('샛길', 0.45, 0.10)]),
          _glossary(),
        );

        final w = _word(r, '風路');
        expect(w.meaning, '샛길');
        expect(w.meaningSource, FieldSource.photo);
        expect(w.meaningCandidates, ['바람길', '바람골', '갈림길', '하늬길']);
      },
    );
  });

  group('M3 a meaning read from the page never changes', () {
    test('even when a sense spells the kanji', () async {
      final r = await _extract(
        scan(ja: _row('雪森', 'ゆきもり', 0.10), ko: [line('눈숲', 0.45, 0.10)]),
        _glossary(),
      );

      final w = _word(r, '雪森');
      expect(w.meaning, '눈숲');
      expect(w.meaningSource, FieldSource.photo);
      expect(w.meaningCandidates, ['설삼']);
    });

    test(
      'and a meaning of no sense keeps every sense as a candidate',
      () async {
        final r = await _extract(
          scan(ja: _row('灯台草', 'とうだいぐさ', 0.10), ko: [line('들풀', 0.45, 0.10)]),
          _glossary(),
        );

        final w = _word(r, '灯台草');
        expect(w.meaning, '들풀');
        expect(w.meaningCandidates, ['등대풀', '갯버들', '물매화']);
      },
    );
  });

  group('R5 a sentence word takes the sense its translation names', () {
    Future<ExtractedWord> sentenceWord(
      String ja,
      String ko,
      String headword,
    ) async {
      final r = await _extract(
        scan(
          ja: [line(ja, 0.1, 0.3, w: 0.2)],
          ko: [line(ko, 0.5, 0.3, w: 0.16)],
        ),
        _glossary(),
      );
      final w = _word(r, headword);
      expect(w.origin, WordOrigin.sentence, reason: headword);
      expect(w.example?.ko, ko, reason: headword);
      expect(w.meaningSource, FieldSource.dictionary, reason: headword);
      return w;
    }

    test('a noun spelled as in the translation', () async {
      final w = await sentenceWord('ふわりです。', '솜사탕입니다.', 'ふわり');
      expect(w.meaning, '솜사탕');
      expect(w.meaningCandidates, ['보송']);
    });

    test('a verb whose stem is in the translation, conjugated', () async {
      final w = await sentenceWord('ぽかりました。', '반짝였습니다.', 'ぽかる');
      expect(w.meaning, '반짝이다');
      expect(w.meaningCandidates, ['빛나다']);
    });

    test('a translation that names no sense keeps the order', () async {
      final w = await sentenceWord('ころりです。', '굴렁쇠입니다.', 'ころり');
      expect(w.meaning, '데굴');
      expect(w.meaningCandidates, ['구름']);
    });
  });
}
