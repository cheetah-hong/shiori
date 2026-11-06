// Q3: sentence words that are no words. A token whose surface is one kana
// (な cut off a line, read as the stem of a verb's negative) even when its
// dictionary form is longer; a kanji alone right after a number (a counter,
// or OCR debris glued to one); and a related-word note `*X：…`: cut at the
// colon (what follows sits where the Korean pass reads the note's meaning)
// and without its star. A colon in a line without the star stays. Made-up
// words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';
import 'support/small_quality_fixtures.dart';
import 'support/stem_fixtures.dart';

Future<ExtractionResult> _extract(OcrScan s) =>
    GeneralExtractor(lexicon: smallQualityLexicon()).extract(s);

Future<List<String>> _heads(OcrScan s) async => [
  for (final w in (await _extract(s)).words) w.headword,
];

void main() {
  group('Q3 one kana', () {
    test('a one-kana token read as a longer word is no word', () async {
      final heads = await _heads(sentencePage(['な霧話です。']));
      expect(heads, contains('霧話'));
      expect(heads, isNot(contains('在る')));
    });

    test('the same verb written out stays a word', () async {
      final heads = await _heads(sentencePage(['霧話が在る。']));
      expect(heads, containsAll(['霧話', '在る']));
    });
  });

  group('Q3 a kanji right after a number', () {
    test('no word', () async {
      final heads = await _heads(sentencePage(['7霧を走る。']));
      expect(heads, isNot(contains('霧')));
      expect(heads, contains('走る'));
    });

    test('without the number: a word', () async {
      final heads = await _heads(sentencePage(['霧を走る。']));
      expect(heads, containsAll(['霧', '走る']));
    });

    test('two kanji after a number: a word', () async {
      final heads = await _heads(sentencePage(['7霧話を走る。']));
      expect(heads, contains('霧話'));
    });
  });

  group('Q3 a related-word note', () {
    OcrScan note(String ja) => scan(
      ja: [line(ja, 0.40, 0.30, w: 0.20)],
      ko: [line('미역국', 0.56, 0.30, w: 0.07)],
    );

    test('cut at the colon, without the star; the part after it is no '
        'word', () async {
      final r = await _extract(note('*霧話：霧'));
      final texts = r.fragments.map((f) => f.text).toList();
      expect(texts, contains('霧話'));
      expect(texts.where((t) => t.contains('：') || t.contains('*')), isEmpty);
      final heads = r.words.map((w) => w.headword).toList();
      expect(heads, contains('霧話'));
      expect(heads, isNot(contains('霧')));
      expect(heads.where((h) => h.contains('*')), isEmpty);
    });

    test('a full-width star too', () async {
      final r = await _extract(note('＊霧話：霧'));
      expect(r.fragments.map((f) => f.text), contains('霧話'));
    });

    test('a colon in a line without the star stays', () async {
      final r = await _extract(sentencePage(['ユミ：霧話を走る。']));
      expect(r.fragments.map((f) => f.text), contains('ユミ：霧話を走る。'));
    });
  });
}
