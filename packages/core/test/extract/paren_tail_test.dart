// P1-P4: what a word list prints around a bracketed reading and what OCR
// makes of a row with too little around it. P1 an ending after the brackets
// (`親切(しんせつ)だ`, `新(あたら)しい`, `練習(れんしゅう)する`) or an honorific in
// front (`お茶(ちゃ)`) splits into the headword and its reading only when the
// dictionary reads the word so; a bracket inside a sentence stays a
// sentence. P2 a checkbox read as ロ glued to the word goes on a page with
// too few rows for a checkbox column, when only the rest is a dictionary
// word. P3 a bracketed line the dictionary confirms, read at the engine's
// lowest confidence, is not lost to the Korean pass's garbage on the same
// place. P4 a mark set apart after a meaning (show-through, ` !`) does not
// make it a sentence. Invented rows; a memory lexicon with JMdict values.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

/// The rows' words, with JMdict values (2026-11-06 edition).
InMemoryLexicon _lexicon() => InMemoryLexicon(const [
  LexiconWord(
    id: 1365250,
    kanji: ['親切'],
    readings: ['しんせつ'],
    pos: ['adj-na', 'n'],
    priority: 5,
    nf: 15,
  ),
  LexiconWord(
    id: 1541620,
    kanji: ['有名'],
    readings: ['ゆうめい'],
    pos: ['adj-na'],
    priority: 5,
    nf: 3,
  ),
  LexiconWord(
    id: 1361490,
    kanji: ['新しい'],
    readings: ['あたらしい'],
    pos: ['adj-i'],
    priority: 5,
    nf: 8,
  ),
  LexiconWord(
    id: 1358280,
    kanji: ['食べる'],
    readings: ['たべる'],
    pos: ['v1', 'vt'],
    priority: 6,
    nf: 25,
  ),
  LexiconWord(
    id: 1559160,
    kanji: ['練習'],
    readings: ['れんしゅう'],
    pos: ['n', 'vs', 'vt'],
    priority: 5,
    nf: 2,
  ),
  LexiconWord(
    id: 1002430,
    kanji: ['お茶'],
    readings: ['おちゃ'],
    pos: ['n', 'vs', 'vi'],
    priority: 5,
    nf: 6,
  ),
  LexiconWord(
    id: 1002500,
    kanji: ['お土産'],
    readings: ['おみやげ'],
    pos: ['n'],
    priority: 4,
  ),
  LexiconWord(
    id: 1206730,
    kanji: ['学校'],
    readings: ['がっこう'],
    pos: ['n'],
    priority: 5,
    nf: 1,
  ),
  LexiconWord(
    id: 1276110,
    kanji: ['口紅'],
    readings: ['くちべに'],
    pos: ['n', 'adj-no'],
    priority: 5,
    nf: 16,
  ),
  LexiconWord(
    id: 1133830,
    readings: ['メモ'],
    pos: ['n', 'vs', 'vt'],
    priority: 68,
  ),
  LexiconWord(id: 2029010, readings: ['を'], pos: ['prt'], priority: 16),
  LexiconWord(
    id: 1338180,
    kanji: ['出る'],
    readings: ['でる'],
    pos: ['v1', 'vi'],
    priority: 5,
    nf: 3,
  ),
]);

/// Korean words for the headwords whose meaning is not their kanji's
/// Korean reading.
Future<List<String>> _glosses(String headword, List<String> readings) async =>
    const {
      '新しい': ['새롭다'],
      '食べる': ['먹다'],
      'お茶': ['차'],
      'お土産': ['선물', '기념품'],
      '口紅': ['립스틱'],
      'メモ': ['메모'],
    }[headword] ??
    const [];

GeneralExtractor _extractor() =>
    GeneralExtractor(lexicon: _lexicon(), koreanGlosses: _glosses);

const double _rowHeight = 0.03;

/// One row of a word list: [ja] read by the Japanese pass at [x], [ko] (the
/// meaning) by the Korean pass to its right; [garbage] is the Korean pass's
/// reading of the Japanese line's place.
({List<OcrLine> ja, List<OcrLine> ko}) _row(
  String ja,
  String ko,
  double y, {
  double x = 0.10,
  double c = 0.5,
  String? garbage,
  double garbageConfidence = 0.5,
}) {
  final head = line(ja, x, y, h: _rowHeight, c: c);
  return (
    ja: [head],
    ko: [
      if (garbage != null)
        line(garbage, x, y, w: head.width, h: _rowHeight, c: garbageConfidence),
      line(ko, 0.55, y + 0.002, h: _rowHeight * 0.9),
    ],
  );
}

OcrScan _page(List<({List<OcrLine> ja, List<OcrLine> ko})> rows) => scan(
  ja: [for (final r in rows) ...r.ja],
  ko: [for (final r in rows) ...r.ko],
);

Future<ExtractionResult> _read(
  List<({List<OcrLine> ja, List<OcrLine> ko})> rows, {
  GeneralExtractor? extractor,
}) => (extractor ?? _extractor()).extract(_page(rows));

ExtractedWord _word(ExtractionResult r, String headword) => r.words.singleWhere(
  (w) => w.headword == headword,
  orElse: () => throw StateError(
    'no $headword in ${[for (final w in r.words) w.headword]}',
  ),
);

Set<String> _heads(ExtractionResult r) => {for (final w in r.words) w.headword};

/// The bracketed readings the collector split off (reading fragment text by
/// headword fragment text).
Map<String, String> _splits(ExtractionResult r) => {
  for (final f in r.fragments)
    if (f.inlineReadingOf case final head?) r.fragments[head].text: f.text,
};

void main() {
  group('P1 an ending after the brackets, an honorific in front', () {
    test('a な-adjective printed with だ after its bracketed reading', () async {
      final r = await _read([_row('親切(しんせつ)だ', '친절하다', 0.10)]);
      expect(_splits(r), {'親切だ': 'しんせつだ'});
      final w = _word(r, '親切だ');
      expect(w.origin, WordOrigin.wordList);
      expect(w.readings, ['しんせつだ']);
      expect(w.readingSource, FieldSource.photo);
      expect(w.readingLink?.confidence, PairConfidence.high);
      expect(w.meaning, '친절하다');
    });

    test('kana of the word printed after the brackets (送り仮名)', () async {
      final r = await _read([
        _row('新(あたら)しい', '새롭다', 0.10),
        _row('食（た）べる', '먹다', 0.16),
      ]);
      expect(_splits(r), {'新しい': 'あたらしい', '食べる': 'たべる'});
      expect(_word(r, '新しい').readings, ['あたらしい']);
      expect(_word(r, '食べる').meaning, '먹다');
    });

    test(
      'する after the brackets: the noun the dictionary uses with する',
      () async {
        final r = await _read([_row('練習(れんしゅう)する', '연습하다', 0.10)]);
        expect(_splits(r), {'練習': 'れんしゅう'});
        final w = _word(r, '練習');
        expect(w.origin, WordOrigin.wordList);
        expect(w.readings, ['れんしゅう']);
        expect(w.meaning, '연습하다');
        expect(_heads(r), isNot(contains('する')));
      },
    );

    test('お before the word: the reading gets it too, unless the brackets '
        'already hold it', () async {
      final r = await _read([
        _row('お茶(ちゃ)', '차', 0.10),
        _row('お土産【おみやげ］', '선물', 0.16),
      ]);
      expect(_splits(r), {'お茶': 'おちゃ', 'お土産': 'おみやげ'});
      expect(_word(r, 'お茶').origin, WordOrigin.wordList);
      expect(_word(r, 'お茶').readings, ['おちゃ']);
      expect(_word(r, 'お土産').readings, ['おみやげ']);
      expect(_word(r, 'お土産').meaning, '선물');
    });

    test('no split when the dictionary reads the word otherwise', () async {
      final r = await _read([
        // a misread reading
        _row('親切(しんぜつ)だ', '친절하다', 0.10),
        // 学校 is no な-adjective: 学校だ is not a dictionary form
        _row('学校(がっこう)だ', '학교', 0.16),
      ]);
      expect(_splits(r), isEmpty);
      expect([
        for (final w in r.words)
          if (w.origin == WordOrigin.wordList) w.headword,
      ], isNot(anyOf(contains('親切だ'), contains('学校だ'))));
    });

    test('a bracketed reading inside a sentence stays a sentence', () async {
      final r = await _read([
        _row('学校（がっこう）を', '학교를', 0.10),
        _row('学校（がっこう）を出る。', '학교를 나온다.', 0.16),
      ]);
      expect(_splits(r), isEmpty);
      expect(
        r.fragments.where(
          (f) => f.pass == OcrPass.japanese && f.text.contains('（'),
        ),
        hasLength(2),
      );
    });

    test('without a dictionary nothing is split (no way to check)', () async {
      final r = await _read([
        _row('親切(しんせつ)だ', '친절하다', 0.10),
      ], extractor: GeneralExtractor());
      expect(_splits(r), isEmpty);
    });
  });

  group('P2 a checkbox glued to the word on a page of few rows', () {
    test('ロ goes when only the rest is a dictionary word', () async {
      final r = await _read([
        _row('ロ親切（しんせつ）だ', '친절하다', 0.10),
        _row('ロ食べる', '먹다', 0.16),
      ]);
      expect(_splits(r), {'親切だ': 'しんせつだ'});
      expect(_word(r, '親切だ').meaning, '친절하다');
      expect(_word(r, '食べる').meaning, '먹다');
      final head = r.fragments.singleWhere((f) => f.text == '親切だ');
      expect(head.droppedPrefix, 'ロ');
      expect(_heads(r).where((h) => h.startsWith('ロ')), isEmpty);
    });

    test('a word that starts with 口 stays whole', () async {
      final r = await _read([
        _row('口紅（くちべに）', '립스틱', 0.10),
        _row('口紅', '립스틱', 0.16),
      ]);
      expect(_splits(r), {'口紅': 'くちべに'});
      expect(_heads(r), contains('口紅'));
      expect(_heads(r), isNot(contains('紅')));
    });

    test('katakana after ロ may be a loanword: it stays', () async {
      final r = await _read([_row('ロメモ', '메모', 0.10)]);
      expect(_heads(r), isNot(contains('メモ')));
    });
  });

  group('P3 a bracketed line at the lowest confidence', () {
    test(
      'the Korean pass reading garbage over it does not take its place',
      () async {
        for (final c in [0.3, 0.30000001192092896]) {
          final r = await _read([
            _row('□ 有名（ゆうめい）だ', '유명하다', 0.10, c: c, garbage: '미바(Ah)'),
            _row('ロ親切（しんせつ）だ', '친절하다', 0.16),
          ]);
          expect(_splits(r), containsPair('有名だ', 'ゆうめいだ'), reason: '$c');
          final w = _word(r, '有名だ');
          expect(w.meaning, '유명하다', reason: '$c');
          expect(w.readingLink?.confidence, isNot(PairConfidence.low));
        }
      },
    );

    test('a line the dictionary does not confirm is still garbage', () async {
      final r = await _read([
        _row('有名（ゆうめ）だ', '유명하다', 0.10, c: 0.3, garbage: '미바(Ah)'),
      ]);
      expect(_heads(r).where((h) => h.contains('有名')), isEmpty);
      expect(r.fragments.where((f) => f.text.contains('有名')), isEmpty);
    });

    test('a kanji read at the lowest confidence over a Korean line is still '
        'garbage', () async {
      final r = await _read([
        _row(
          '学校',
          '학교',
          0.10,
          c: 0.3,
          garbage: '학교에 갑니다',
          garbageConfidence: 1,
        ),
      ]);
      expect(_heads(r), isNot(contains('学校')));
    });

    test('a line both passes read mixed keeps its meaning', () async {
      final mixed = [
        line('学校[がっこう] Vl', 0.10, 0.10, w: 0.40, h: _rowHeight, c: 0.5),
      ];
      final r = await _extractor().extract(
        scan(
          ja: mixed,
          ko: [line('XULYL4 학교', 0.10, 0.10, w: 0.40, h: _rowHeight, c: 0.5)],
        ),
      );
      expect(_word(r, '学校').meaning, '학교');
    });
  });

  group('P4 a mark set apart after a meaning', () {
    test('` !` and ` ？` are show-through, not the end of a sentence', () async {
      final r = await _read([
        _row('親切(しんせつ)だ', '친절하다 !', 0.10),
        _row('有名(ゆうめい)だ', '유명하다 ？', 0.16),
      ]);
      expect(_word(r, '親切だ').meaning, '친절하다');
      expect(_word(r, '有名だ').meaning, '유명하다');
      final meaning = r.fragments.singleWhere((f) => f.text == '친절하다');
      expect(meaning.kind, FragmentKind.hangul);
      expect(meaning.corrected, isTrue);
    });

    test('a mark against the text and a full stop set apart still end a '
        'sentence', () async {
      final r = await _extractor().extract(
        scan(
          ko: [
            line('정말 좋아요!', 0.10, 0.10, h: _rowHeight),
            line('학교에 갑니다 .', 0.10, 0.30, h: _rowHeight),
          ],
        ),
      );
      for (final f in r.fragments.where((f) => f.pass == OcrPass.korean)) {
        expect(f.kind, FragmentKind.koreanSentence, reason: f.text);
      }
    });
  });
}
