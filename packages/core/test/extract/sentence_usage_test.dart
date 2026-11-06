// C7: a sentence word that is an adverb, a な-adjective and a noun at once
// asks the glossary for the class its sentence uses it as (だ・な・で after
// it: な-adjective; a verb or adjective after it: adverb; が・を・は・の:
// noun), else the dictionary's first class. The pairing lookup is as
// before. And a page band: a kanji line with no kana that splits into
// dictionary words gives them no example, and a counter right after a
// number is not a word. Made-up words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';
import 'support/stem_fixtures.dart';

void main() {
  group('C7 the class a sentence uses the word as', () {
    Future<PartOfSpeech?> hintFor(String sentence) async {
      final glossary = MemoryKoreanGlossary({
        '霧変': [
          ['몹시'],
          ['고되다'],
          ['큰일'],
        ],
      });
      final r = await GeneralExtractor(
        lexicon: stemLexicon(),
        koreanGlossary: glossary,
      ).extract(sentencePage([sentence]));
      expect(r.words.map((w) => w.headword), contains('霧変'), reason: sentence);
      final asked = glossary.calls.where(
        (c) => c.headword == '霧変' && c.limit == meaningSenses,
      );
      expect(asked, isNotEmpty, reason: sentence);
      // The pairing lookup has no class hint, as before.
      expect(
        glossary.calls
            .where((c) => c.headword == '霧変' && c.limit != meaningSenses)
            .every((c) => c.pos == null),
        isTrue,
        reason: sentence,
      );
      return asked.last.pos;
    }

    test('だ after it: な-adjective', () async {
      expect(await hintFor('霧変だけど、行きます。'), PartOfSpeech.naAdjective);
    });

    test('な after it: な-adjective', () async {
      expect(await hintFor('霧変な部屋です。'), PartOfSpeech.naAdjective);
    });

    test('a verb after it: adverb', () async {
      expect(await hintFor('霧変走ります。'), PartOfSpeech.adverb);
    });

    test('が after it: noun', () async {
      expect(await hintFor('霧変が来ます。'), PartOfSpeech.noun);
    });

    test('nothing that tells: the dictionary\'s first class', () async {
      expect(await hintFor('霧変。'), PartOfSpeech.adverb);
    });
  });

  group('a page band of kanji and numbers', () {
    Future<ExtractionResult> extract(OcrScan s) =>
        GeneralExtractor(lexicon: stemLexicon()).extract(s);

    test('a kanji line with no kana gives its words no example and no '
        'counter after the number', () async {
      final r = await extract(scan(ja: [line('第9課霧話', 0.7, 0.9)]));

      final heads = r.words.map((w) => w.headword).toList();
      expect(heads, contains('霧話'));
      expect(heads, isNot(contains('課')));
      expect(r.words.firstWhere((w) => w.headword == '霧話').example, isNull);
      expect(r.unpaired.map((f) => f.text), isNot(contains('第9課霧話')));
    });

    test('a band of a number and its counter only is no word and no '
        'unpaired fragment', () async {
      final r = await extract(scan(ja: [line('第9課', 0.7, 0.9)]));

      expect(r.words, isEmpty);
      expect(r.unpaired, isEmpty);
    });

    test('a counter after a number in a sentence is no word; the sentence '
        'still gives its words with the example', () async {
      final r = await extract(sentencePage(['第9課の霧話です。']));

      final heads = r.words.map((w) => w.headword).toList();
      expect(heads, isNot(contains('課')));
      expect(
        r.words.firstWhere((w) => w.headword == '霧話').example?.ja,
        '第9課の霧話です。',
      );
    });

    test('the same noun with no number before it is a word', () async {
      final r = await extract(sentencePage(['課の霧話です。']));

      expect(r.words.map((w) => w.headword), containsAll(['課', '霧話']));
    });
  });
}
