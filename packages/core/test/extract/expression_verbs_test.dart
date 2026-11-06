// Q2: an expression entry (exp, maybe adj-f) that is a conjugated form of a
// verb is read as that verb (読み・品詞 of the verb, the token's surface and
// place as they are). Left as they are: a polite set phrase (ends in ます),
// a negative one, a prenominal registered only as adj-f, an expression whose
// kanji the verb does not keep, and an expression that is no verb's form.
// Made-up words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/extract/lattice.dart';
import 'package:test/test.dart';

import 'support/small_quality_fixtures.dart';
import 'support/stem_fixtures.dart';

Future<List<LatticeToken>> _tokens(String sentence) =>
    SentenceSegmenter(smallQualityLexicon()).segment(sentence);

Future<LatticeToken> _token(String sentence, String surface) async =>
    (await _tokens(sentence)).singleWhere((t) => t.surface == surface);

void main() {
  group('Q2 an expression entry read as its verb', () {
    test('the past form registered as an expression: the verb', () async {
      final t = await _token('霧ったね。', '霧った');
      expect(t.base, '霧る');
      expect(t.readings, ['むる']);
      expect(t.partsOfSpeech, contains('v5r'));
      expect(t.steps, isNotEmpty);
      expect((t.start, t.end), (0, 3));
    });

    test(
      'as a sentence word: the verb, read and classed as the verb',
      () async {
        final r = await GeneralExtractor(
          lexicon: smallQualityLexicon(),
        ).extract(sentencePage(['走って霧ったね。']));
        final heads = r.words.map((w) => w.headword).toList();
        expect(heads, contains('霧る'));
        expect(heads, isNot(contains('霧った')));
        final w = r.words.singleWhere((w) => w.headword == '霧る');
        expect(w.readings, ['むる']);
        expect(w.partsOfSpeech, contains('v5r'));
        expect(w.example?.ja, '走って霧ったね。');
      },
    );

    test('a polite set phrase: as it is', () async {
      final t = await _token('霧ります。', '霧ります');
      expect(t.base, '霧ります');
      expect(t.partsOfSpeech, ['exp']);
    });

    test('a negative expression: as it is', () async {
      final t = await _token('霧らない。', '霧らない');
      expect(t.base, '霧らない');
    });

    test('a prenominal registered only as adj-f: as it is', () async {
      final t = await _token('雲った部屋です。', '雲った');
      expect(t.base, '雲った');
      expect(t.partsOfSpeech, ['adj-f']);
    });

    test('an expression that is no verb form: as it is', () async {
      final t = await _token('霧霧です。', '霧霧');
      expect(t.base, '霧霧');
    });
  });
}
