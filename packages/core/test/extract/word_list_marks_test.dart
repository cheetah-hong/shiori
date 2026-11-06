// V1, V7, V8 on hand-made scans: POS badges and the passes fighting over a
// badge line or a one-syllable misread, blank reading cells by their height,
// box glyphs, and when a headword is read back from its kana and meaning.
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/extract/fragment_collector.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

List<(FragmentKind, String)> _content(List<Fragment> fragments) => [
  for (final f in fragments)
    if (f.isContent) (f.kind, f.text),
];

/// Words of the read-back cases, with JMdict values.
InMemoryLexicon _lexicon() => InMemoryLexicon(const [
  LexiconWord(
    id: 1585650,
    kanji: ['箱'],
    readings: ['はこ'],
    pos: ['n', 'suf', 'ctr'],
    priority: 5,
    nf: 9,
  ),
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
  LexiconWord(
    id: 1003430,
    readings: ['きっと'],
    pos: ['adv'],
    priority: 4,
    usuallyKana: true,
  ),
  LexiconWord(
    id: 1160790,
    kanji: ['一'],
    readings: ['いち'],
    pos: ['num', 'pref', 'adj-no', 'suf', 'n', 'n-pref'],
    priority: 6,
    nf: 33,
  ),
]);

MemoryKoreanGlossary _glossary() => MemoryKoreanGlossary(
  {
    '箱': [
      ['상자'],
    ],
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
    '箱': ['はこ'],
    '暑い': ['あつい'],
    '熱い': ['あつい'],
    '沢山': ['たくさん'],
  },
);

/// A glossary that only reads forwards.
final class _ForwardOnly implements KoreanGlossary {
  const _ForwardOnly();

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => const [];

  @override
  List<GlossarySourceInfo> get sources => const [];
}

/// A glossary whose backward lookup fails (a damaged file).
final class _BrokenBackwards implements KoreanGlossary, KoreanReverseGlossary {
  const _BrokenBackwards();

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => const [];

  @override
  Future<List<GlossedSpelling>> reverseLookup(Iterable<String> readings) =>
      Future.error(const FormatException('damaged'));

  @override
  List<GlossarySourceInfo> get sources => const [];
}

/// One word-list row: [left] (what was read where the headword is), the
/// kana and the meaning, with three checkbox rows above it so the page has
/// a checkbox column at x 0.15.
OcrScan _row({
  required OcrLine? left,
  required String kana,
  required String meaning,
  double kanaConfidence = 1.0,
  List<OcrLine> koExtra = const [],
}) => scan(
  ja: [
    for (var i = 0; i < 3; i++) line('ロロロ', 0.15, 0.10 + 0.05 * i, c: 0.3),
    ?left,
    line(kana, 0.42, 0.30, c: kanaConfidence),
  ],
  ko: [line(meaning, 0.60, 0.30, h: 0.015, c: 0.5), ...koExtra],
);

void main() {
  group('V1 POS badges in the collector', () {
    test('badges as OCR reads them come off the meaning', () {
      for (final (read, meaning) in [
        ('동사 열다', '열다'),
        ('몀. 책상', '책상'),
        ('니형 가늘다', '가늘다'),
        ('⅓형 친절하다', '친절하다'),
        ('명 상자', '상자'),
      ]) {
        final fragments = collectFragments(
          scan(ko: [line(read, 0.6, 0.3, h: 0.015)]),
        );
        expect(_content(fragments), [
          (FragmentKind.hangul, meaning),
        ], reason: read);
      }
    });

    test('a badge alone on its line is no content', () {
      final fragments = collectFragments(
        scan(ko: [line('명', 0.6, 0.3, h: 0.015)]),
      );
      expect(_content(fragments), isEmpty);
    });

    test('a meaning that only starts like a badge keeps its text', () {
      final fragments = collectFragments(
        scan(ko: [line('동사무소', 0.6, 0.3, h: 0.015)]),
      );
      expect(_content(fragments), [(FragmentKind.hangul, '동사무소')]);
    });

    test('a badge line the Japanese pass read as 8 and kanji at full '
        'confidence stays Korean', () {
      final box = (x: 0.6, y: 0.3, w: 0.08, h: 0.015);
      final fragments = collectFragments(
        scan(
          ja: [line('8叉', box.x, box.y, w: box.w, h: box.h)],
          ko: [line('명 창문', box.x, box.y, w: box.w, h: box.h, c: 0.5)],
        ),
      );
      expect(_content(fragments), [(FragmentKind.hangul, '창문')]);
    });
  });

  group('one place read by both passes', () {
    test('one Korean syllable over a 0.3 kanji keeps the kanji', () {
      final fragments = collectFragments(
        scan(
          ja: [line('箱', 0.2, 0.3, w: 0.025, c: 0.3)],
          ko: [line('트', 0.2, 0.3, w: 0.025, c: 0.5)],
        ),
      );
      expect(_content(fragments), contains((FragmentKind.kanjiWord, '箱')));
    });

    test('one Korean syllable over 0.3 kana of two or more keeps the '
        'kana', () {
      final fragments = collectFragments(
        scan(
          ja: [line('かがみ', 0.42, 0.3, w: 0.05, h: 0.016, c: 0.3)],
          ko: [line('(다', 0.42, 0.3, w: 0.05, h: 0.016, c: 0.5)],
        ),
      );
      expect(_content(fragments), [(FragmentKind.kana, 'かがみ')]);
    });

    test('a Korean word over Japanese garbage at 0.3 is still Korean', () {
      final fragments = collectFragments(
        scan(
          ja: [line('己乙', 0.6, 0.3, w: 0.05, h: 0.015, c: 0.3)],
          ko: [line('거울', 0.6, 0.3, w: 0.05, h: 0.015, c: 0.5)],
        ),
      );
      expect(_content(fragments), [(FragmentKind.hangul, '거울')]);
    });
  });

  group('box glyphs', () {
    test('only box glyphs at the checkbox column are no content', () {
      final fragments = collectFragments(
        scan(
          ja: [
            for (var i = 0; i < 3; i++)
              line('■口口', 0.15, 0.10 + 0.05 * i, w: 0.036, h: 0.009, c: 0.3),
            line('コロロ', 0.151, 0.30, w: 0.036, h: 0.009, c: 0.3),
            line('ロロー', 0.150, 0.35, w: 0.036, h: 0.009, c: 0.3),
          ],
        ),
      );
      expect(_content(fragments), isEmpty);
    });

    test('問 at the checkbox column, set off by a space, is a box', () {
      final fragments = collectFragments(
        scan(
          ja: [
            for (var i = 0; i < 3; i++)
              line('ロロロ', 0.15, 0.10 + 0.05 * i, w: 0.036, h: 0.009, c: 0.3),
            line('問 傘', 0.15, 0.30, w: 0.07, h: 0.019, c: 0.5),
          ],
        ),
      );
      expect(_content(fragments), [(FragmentKind.kanjiWord, '傘')]);
    });
  });

  group('V7 blank reading cells', () {
    for (final dash in ['一', 'ー', '-', '–', '—', '−']) {
      test('a flat $dash beside a kana headword is no word and takes no '
          'meaning', () async {
        final s = scan(
          ja: [
            line('きっと', 0.20, 0.30, h: 0.019),
            line(dash, 0.42, 0.306, w: 0.014, h: 0.006, c: 0.5),
          ],
          ko: [line('꼭, 분명히', 0.60, 0.302, h: 0.0135, c: 0.5)],
        );
        final r = await GeneralExtractor(lexicon: _lexicon()).extract(s);
        expect([for (final w in r.words) w.headword], ['きっと']);
        expect(r.words.single.meaning, '꼭, 분명히');
        expect(r.unpaired.map((f) => f.text), isNot(contains(dash)));
      });
    }

    test('a 一 as tall as the line is a word', () async {
      final s = scan(
        ja: [
          line('一', 0.20, 0.30, w: 0.019, h: 0.019),
          line('いち', 0.42, 0.30, h: 0.016, c: 0.5),
        ],
        ko: [line('하나, 일', 0.60, 0.302, h: 0.0135, c: 0.5)],
      );
      final r = await GeneralExtractor(lexicon: _lexicon()).extract(s);
      expect(r.words.single.headword, '一');
      expect(r.words.single.readings, ['いち']);
    });
  });

  group('V8 a headword read back from its kana and meaning', () {
    test('a 0.3 dictionary word with another reading is a trace', () async {
      final r =
          await GeneralExtractor(
            lexicon: _lexicon(),
            koreanGlossary: _glossary(),
          ).extract(
            _row(
              left: line('一', 0.20, 0.30, w: 0.019, h: 0.019, c: 0.3),
              kana: 'はこ',
              meaning: '상자',
            ),
          );
      final w = r.words.singleWhere((w) => w.meaning == '상자');
      expect(w.headword, '箱');
      expect(w.readings, ['はこ']);
      expect(w.headwordSource, FieldSource.dictionary);
      expect(w.headwordNote, contains('사전 역조회'));
      expect(w.partsOfSpeech, contains('n'));
    });

    test('an unread kanji run (no dictionary word) is a trace', () async {
      final r =
          await GeneralExtractor(
            lexicon: _lexicon(),
            koreanGlossary: _glossary(),
          ).extract(
            _row(
              left: line('己乙', 0.20, 0.30, w: 0.04, h: 0.019, c: 0.5),
              kana: 'はこ',
              meaning: '상자',
            ),
          );
      expect(r.words.map((w) => w.headword), contains('箱'));
    });

    test('one Korean syllable where the headword is is a trace', () async {
      final r =
          await GeneralExtractor(
            lexicon: _lexicon(),
            koreanGlossary: _glossary(),
          ).extract(
            _row(
              left: null,
              kana: 'はこ',
              meaning: '상자',
              koExtra: [line('트', 0.20, 0.30, w: 0.019, h: 0.019, c: 0.5)],
            ),
          );
      expect(r.words.map((w) => w.headword), contains('箱'));
    });

    test('with no trace a printed kana headword stays kana', () async {
      for (final left in [
        null,
        line('LON', 0.15, 0.30, w: 0.036, h: 0.009, c: 0.3),
      ]) {
        final r = await GeneralExtractor(
          lexicon: _lexicon(),
          koreanGlossary: _glossary(),
        ).extract(_row(left: left, kana: 'たくさん', meaning: '많이'));
        final w = r.words.singleWhere((w) => w.meaning == '많이');
        expect(w.headword, 'たくさん', reason: '$left');
        expect(w.headwordSource, FieldSource.photo);
      }
    });

    test('two kanji spellings: the kana stays and both are '
        'candidates', () async {
      final r =
          await GeneralExtractor(
            lexicon: _lexicon(),
            koreanGlossary: _glossary(),
          ).extract(
            _row(
              left: line('己', 0.20, 0.30, w: 0.019, h: 0.019, c: 0.3),
              kana: 'あつい',
              meaning: '덥다, 뜨겁다',
            ),
          );
      final w = r.words.singleWhere((w) => w.meaning == '덥다, 뜨겁다');
      expect(w.headword, 'あつい');
      expect(w.headwordCandidates, unorderedEquals(['暑い', '熱い']));
      final entry = w.toCapturedEntry(fragments: r.fragments);
      expect(entry.headwordCandidates, unorderedEquals(['暑い', '熱い']));
      final head = entry.evidence!.of(EntryField.headword)!;
      expect(head.candidates, unorderedEquals(['暑い', '熱い']));
      expect(head.note, contains('사전 역조회 후보 2'));
    });

    test('a glossary that cannot read backwards, or fails to, leaves the '
        'kana', () async {
      for (final glossary in [const _ForwardOnly(), const _BrokenBackwards()]) {
        final r =
            await GeneralExtractor(
              lexicon: _lexicon(),
              koreanGlossary: glossary,
            ).extract(
              _row(
                left: line('一', 0.20, 0.30, w: 0.019, h: 0.019, c: 0.3),
                kana: 'はこ',
                meaning: '상자',
              ),
            );
        final w = r.words.singleWhere((w) => w.meaning == '상자');
        expect(w.headword, 'はこ', reason: '$glossary');
      }
    });

    test('the page asks the glossary backwards once', () async {
      final glossary = _glossary();
      await GeneralExtractor(
        lexicon: _lexicon(),
        koreanGlossary: glossary,
      ).extract(
        _row(
          left: line('一', 0.20, 0.30, w: 0.019, h: 0.019, c: 0.3),
          kana: 'はこ',
          meaning: '상자',
        ),
      );
      expect(glossary.askedBackwards, hasLength(1));
    });
  });
}
