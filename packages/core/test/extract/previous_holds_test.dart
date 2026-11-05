// E10: regression tests for the fixes of the previous review (merging だ
// forms, the checkbox column, several readings, katakana words) and the box
// column on a tall photo.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

final _extraWords = [
  ...testWords,
  const LexiconWord(
    id: 1580480,
    kanji: ['丈夫'],
    readings: ['じょうぶ'],
    pos: ['adj-na'],
    priority: 5,
    nf: 15,
  ),
  const LexiconWord(
    id: 1301940,
    kanji: ['傘'],
    readings: ['かさ'],
    pos: ['n'],
    priority: 5,
    nf: 11,
  ),
  const LexiconWord(id: 1147560, readings: ['ロッカー'], pos: ['n'], priority: 64),
  const LexiconWord(
    id: 1584660,
    kanji: ['明日'],
    readings: ['あした', 'あす', 'みょうにち'],
    pos: ['n', 'adv'],
    priority: 5,
    nf: 5,
  ),
  const LexiconWord(
    id: 1193290,
    kanji: ['歌手'],
    readings: ['かしゅ'],
    pos: ['n'],
    priority: 5,
    nf: 3,
  ),
];

InMemoryLexicon _lexicon() => InMemoryLexicon(_extraWords);

Future<ExtractionResult> _extract(OcrScan s) =>
    GeneralExtractor(lexicon: _lexicon()).extract(s);

/// A box column at [x]: three boxed words, then ロッカー whose ロ sits at the
/// column (its first letter, not a box). Values of the added words as in
/// JMdict (2026-11-04 edition).
List<OcrLine> _boxColumn(double x, double y0, {double h = 0.02}) => [
  line('□運動', x, y0, h: h),
  line('□学校', x, y0 + 2 * h, h: h),
  line('□部屋', x, y0 + 4 * h, h: h),
  line('ロッカー', x, y0 + 6 * h, h: h),
];

void main() {
  test('丈夫だ from the word list and 丈夫 in a sentence are one word', () async {
    final r = await _extract(
      scan(
        ja: [
          line('丈夫だ', 0.10, 0.10, c: 1.0),
          line('じょうぶだ', 0.25, 0.10, c: 1.0),
          line('この傘は丈夫です。', 0.10, 0.30, c: 1.0),
        ],
        ko: [line('튼튼하다', 0.45, 0.10, c: 1.0)],
      ),
    );

    final joubu = r.words.where((w) => headwordKey(w.headword) == '丈夫');
    expect(joubu, hasLength(1));
    expect(joubu.single.origin, WordOrigin.wordList);
    expect(joubu.single.meaning, '튼튼하다');
    expect(joubu.single.example?.ja, 'この傘は丈夫です。');
  });

  test('丈夫 already known also drops 丈夫だ', () async {
    final r = await GeneralExtractor(lexicon: _lexicon()).extract(
      scan(
        ja: [
          line('丈夫だ', 0.10, 0.10, c: 1.0),
          line('じょうぶだ', 0.25, 0.10, c: 1.0),
        ],
        ko: [line('튼튼하다', 0.45, 0.10, c: 1.0)],
      ),
      knownHeadwords: {'丈夫'},
    );

    expect(r.words, isEmpty);
  });

  for (final columns in [1, 2]) {
    test('checkbox column ($columns column page): the boxes go, ロッカー '
        'keeps its first letter', () async {
      final r = await _extract(
        scan(
          ja: [
            ..._boxColumn(0.10, 0.10),
            if (columns == 2) ..._boxColumn(0.55, 0.10),
          ],
        ),
      );

      final heads = r.words.map((w) => w.headword).toList();
      expect(heads.where((h) => h == 'ロッカー'), hasLength(1));
      expect(heads, isNot(contains('ッカー')));
      expect(heads.where((h) => h == '運動'), hasLength(1));
    });
  }

  test('あした/あす: both printed readings stay', () async {
    final r = await _extract(
      scan(
        ja: [
          line('明日', 0.10, 0.10, c: 1.0),
          line('あした/あす', 0.25, 0.10, c: 1.0),
        ],
        ko: [line('내일', 0.50, 0.10, c: 1.0)],
      ),
    );

    final w = r.words.singleWhere((w) => w.headword == '明日');
    expect(w.readings, ['あした', 'あす']);
    expect(w.readingSource, FieldSource.photo);
  });

  test('明日(あした/あす) in brackets: both readings, one word', () async {
    final r = await _extract(
      scan(
        ja: [line('明日(あした/あす)', 0.10, 0.10, c: 1.0)],
        ko: [line('내일', 0.50, 0.10, c: 1.0)],
      ),
    );

    expect(r.words.single.headword, '明日');
    expect(r.words.single.readings, ['あした', 'あす']);
  });

  test('a katakana word is never replaced by a kanji word of the same '
      'reading', () async {
    final r = await _extract(
      scan(
        ja: [line('カシュ', 0.10, 0.10, c: 1.0)],
        ko: [line('가수', 0.50, 0.10, c: 1.0)],
      ),
    );

    expect(r.words.where((w) => w.headword == '歌手'), isEmpty);
  });

  test('a tall photo gives the same words as a square one (box column '
      'tolerance)', () async {
    // The same print, once on a square photo and once on a photo 1.6 times
    // taller than wide: y and heights shrink, x and widths stay.
    List<OcrLine> page({double ys = 1.0}) => [
      line('□運動', 0.100, 0.10 * ys, h: 0.02 * ys, w: 0.06),
      line('□学校', 0.101, 0.14 * ys, h: 0.02 * ys, w: 0.06),
      line('□部屋', 0.099, 0.18 * ys, h: 0.02 * ys, w: 0.06),
      // the box drifts right by 0.016 of the width: within a line height of
      // the column on the square photo, so it is a box on both
      line('口食べる', 0.116, 0.22 * ys, h: 0.02 * ys, w: 0.08),
      line('ロッカー', 0.100, 0.26 * ys, h: 0.02 * ys, w: 0.08),
    ];
    List<String> heads(ExtractionResult r) =>
        [for (final w in r.words) w.headword]..sort();

    final square = await _extract(scan(ja: page()));
    final tall = await _extract(scan(ja: page(ys: 1 / 1.6)));

    expect(heads(square), contains('食べる'));
    expect(heads(square), contains('ロッカー'));
    expect(heads(tall), heads(square));
  });
}
