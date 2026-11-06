// Q1: an adverb with a negative after it in its clause takes the sense a
// Korean adverb used with a negative gives (별로 … 않다) when the glossary
// has one; without a negative, the glossary's order stands. The printed
// translation still names the sense first. Made-up words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/small_quality_fixtures.dart';
import 'support/stem_fixtures.dart';

KoreanSense _sense(List<String> words) =>
    KoreanSense(words: words, source: GlossarySource.krdict, senseNo: 1);

List<String> _firsts(List<KoreanSense> senses) => [
  for (final s in senses) s.words.first,
];

void main() {
  group('Q1 orderMeaningSenses with a negative after the word', () {
    final senses = [
      _sense(['따로']),
      _sense(['별로']),
      _sense(['달리']),
    ];

    test('a negative: the first sense used with a negative comes first', () {
      expect(_firsts(orderMeaningSenses('霧別に', senses, negated: true)), [
        '별로',
        '따로',
        '달리',
      ]);
    });

    test('no negative: the glossary order', () {
      expect(_firsts(orderMeaningSenses('霧別に', senses)), ['따로', '별로', '달리']);
    });

    test('such a sense first already: as it is', () {
      final first = [
        _sense(['그다지']),
        _sense(['따로']),
      ];
      expect(_firsts(orderMeaningSenses('霧別に', first, negated: true)), [
        '그다지',
        '따로',
      ]);
    });

    test('no such sense: as it is', () {
      final none = [
        _sense(['따로']),
        _sense(['달리']),
      ];
      expect(_firsts(orderMeaningSenses('霧別に', none, negated: true)), [
        '따로',
        '달리',
      ]);
    });

    test('the printed translation names a sense: that sense first', () {
      expect(
        _firsts(
          orderMeaningSenses(
            '霧別に',
            senses,
            negated: true,
            translation: '따로 가지 않습니다.',
          ),
        ).first,
        '따로',
      );
    });

    test('the Korean adverbs used with a negative', () {
      expect(negativePolarityWords, hasLength(24));
      expect(
        negativePolarityWords,
        containsAll(['별로', '그다지', '전혀', '결코', '도저히', '좀처럼', '차마']),
      );
      expect(negativePolarityWords, isNot(contains('따로')));
    });
  });

  group('Q1 a sentence word', () {
    Future<ExtractedWord> adverbIn(String sentence) async {
      final glossary = MemoryKoreanGlossary({
        '霧別に': [
          ['따로'],
          ['별로'],
        ],
      });
      final r = await GeneralExtractor(
        lexicon: smallQualityLexicon(),
        koreanGlossary: glossary,
      ).extract(sentencePage([sentence]));
      return r.words.singleWhere((w) => w.headword == '霧別に');
    }

    test('a negative after it: the sense used with a negative', () async {
      final w = await adverbIn('霧別に走らなかった。');
      expect(w.meaning, '별로');
      expect(w.meaningCandidates, ['따로']);
      expect(w.meaningSource, FieldSource.dictionary);
    });

    test('no negative: the glossary order', () async {
      final w = await adverbIn('霧別に走った。');
      expect(w.meaning, '따로');
      expect(w.meaningCandidates, ['별로']);
    });

    test('a negative after the clause ends: the glossary order', () async {
      final w = await adverbIn('霧別に走った、走らなかった。');
      expect(w.meaning, '따로');
    });
  });
}
