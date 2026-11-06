// R6: what OCR reads of a checkbox column (boxes, one ticked) beside a kana
// headword printed as kana is no trace of a lost headword: the kana is not
// read back and gets no headword candidates. Box glyphs off the column, or
// with more than a tick beside them, are traces as before.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import 'support/confidence_fixtures.dart';
import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

/// The read-back rows' words, with JMdict values.
InMemoryLexicon _lexicon() => InMemoryLexicon(const [
  LexiconWord(
    id: 1343460,
    kanji: ['暑い'],
    readings: ['あつい'],
    pos: ['adj-i'],
    priority: 6,
    nf: 34,
  ),
  LexiconWord(
    id: 1467720,
    kanji: ['熱い'],
    readings: ['あつい'],
    pos: ['adj-i'],
    priority: 5,
    nf: 14,
  ),
  LexiconWord(
    id: 1415870,
    kanji: ['沢山'],
    readings: ['たくさん'],
    pos: ['adj-no', 'adj-na', 'n', 'adv', 'n-suf'],
    priority: 6,
    nf: 43,
    usuallyKana: true,
  ),
]);

MemoryKoreanGlossary _glossary() => MemoryKoreanGlossary(
  {
    '暑い': [
      ['덥다'],
    ],
    '熱い': [
      ['뜨겁다'],
    ],
    '沢山': [
      ['많이'],
    ],
  },
  readings: {
    '暑い': ['あつい'],
    '熱い': ['あつい'],
    '沢山': ['たくさん'],
  },
);

/// One word-list row under [boxRows] rows of boxes at x 0.15: [left] (what
/// was read where the checkbox or the headword is), the kana and the
/// meaning.
OcrScan _row({
  required OcrLine left,
  required String kana,
  required String meaning,
  int boxRows = 3,
}) => scan(
  ja: [
    for (var i = 0; i < boxRows; i++)
      line('ロロロ', 0.15, 0.10 + 0.05 * i, c: 0.3),
    left,
    line(kana, 0.42, 0.30),
  ],
  ko: [line(meaning, 0.60, 0.30, h: 0.015, c: 0.5)],
);

Future<ExtractedWord> _word(OcrScan s, String meaning) async =>
    (await GeneralExtractor(
      lexicon: _lexicon(),
      koreanGlossary: _glossary(),
    ).extract(s)).words.singleWhere((w) => w.meaning == meaning);

void main() {
  group('R6 the checkbox column is no trace of a lost headword', () {
    test('s010: the kana headword beside a ticked box row keeps no '
        'headword candidates', () async {
      final draft = await pageDraft(
        confidenceExtractor(rowLexicon(), glossary: realReverseGlossary()),
        await synthetic.loadScan('s010'),
      );
      final e = entryOf(draft, 'ちょっと');
      expect(e.headwordCandidates, isEmpty);
      expect(e.evidence!.of(EntryField.headword)!.candidates, isEmpty);
      expect(
        e.evidence!.of(EntryField.meaning)?.note ?? '',
        isNot('표제어 자리 판독 실패'),
      );
    });

    for (final mark in ['ロロレ', 'ロレ', 'ロ', '口口']) {
      test('$mark on the box column: a printed kana headword with one '
          'spelling stays kana', () async {
        final w = await _word(
          _row(
            left: line(mark, 0.15, 0.30, c: 0.3),
            kana: 'たくさん',
            meaning: '많이',
          ),
          '많이',
        );
        expect(w.headword, 'たくさん');
        expect(w.headwordSource, FieldSource.photo);
        expect(w.headwordCandidates, isEmpty);
      });

      test('$mark on the box column: a kana headword with two spellings '
          'gets no candidates', () async {
        final w = await _word(
          _row(
            left: line(mark, 0.15, 0.30, c: 0.3),
            kana: 'あつい',
            meaning: '덥다, 뜨겁다',
          ),
          '덥다, 뜨겁다',
        );
        expect(w.headword, 'あつい');
        expect(w.headwordCandidates, isEmpty);
      });
    }

    test('the ticked box row off the box column is still a trace', () async {
      final w = await _word(
        _row(
          left: line('ロロレ', 0.25, 0.30, c: 0.3),
          kana: 'たくさん',
          meaning: '많이',
        ),
        '많이',
      );
      expect(w.headword, '沢山');
      expect(w.headwordSource, FieldSource.dictionary);
    });

    test('a box glyph with two other kana on the column is still a '
        'trace', () async {
      final w = await _word(
        _row(
          left: line('ロレレ', 0.15, 0.30, c: 0.3),
          kana: 'たくさん',
          meaning: '많이',
        ),
        '많이',
      );
      expect(w.headword, '沢山');
    });

    test('one box row alone is no column: the ticked row is still a '
        'trace', () async {
      final w = await _word(
        _row(
          left: line('ロロレ', 0.15, 0.30, c: 0.3),
          kana: 'たくさん',
          meaning: '많이',
          boxRows: 1,
        ),
        '많이',
      );
      expect(w.headword, '沢山');
    });

    test('a misread headword in the headword column is read back as '
        'before', () async {
      final w = await _word(
        _row(
          left: line('己', 0.20, 0.30, w: 0.019, h: 0.019, c: 0.3),
          kana: 'あつい',
          meaning: '덥다, 뜨겁다',
        ),
        '덥다, 뜨겁다',
      );
      expect(w.headword, 'あつい');
      expect(w.headwordCandidates, unorderedEquals(['暑い', '熱い']));
    });
  });
}
