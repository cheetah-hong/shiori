// T16–T17: sentences become dictionary-form words with the sentence as example.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

void main() {
  test(
    'T16 words of a sentence carry it and the translation beside it',
    () async {
      final r = await GeneralExtractor(lexicon: testLexicon()).extract(
        scan(
          ja: [line('学校に行きました。', 0.1, 0.3, w: 0.2)],
          ko: [line('학교에 갔습니다.', 0.5, 0.3, w: 0.16)],
        ),
      );

      expect(r.words.map((w) => w.headword), ['学校', '行く']);
      for (final w in r.words) {
        expect(w.origin, WordOrigin.sentence, reason: w.headword);
        expect(
          w.example,
          const WordExample(ja: '学校に行きました。', ko: '학교에 갔습니다.'),
          reason: w.headword,
        );
      }
      expect(r.words.first.readings, ['がっこう']);
      expect(r.words.first.readingSource, FieldSource.dictionary);
      expect(r.unpaired.where((f) => f.text == '학교에 갔습니다.'), isEmpty);
    },
  );

  test(
    'T17 one word per dictionary form on a page; known words are left out',
    () async {
      final s = scan(
        ja: [
          line('学校に行きました。', 0.1, 0.3, w: 0.2),
          line('学校は高いです。', 0.1, 0.4, w: 0.18),
        ],
      );

      final all = await GeneralExtractor(lexicon: testLexicon()).extract(s);
      expect(all.words.where((w) => w.headword == '学校'), hasLength(1));
      expect(all.words.map((w) => w.headword).toSet(), {'学校', '行く', '高い'});

      final unknown = await GeneralExtractor(
        lexicon: testLexicon(),
      ).extract(s, knownHeadwords: {'高い'});
      expect(unknown.words.map((w) => w.headword).toSet(), {'学校', '行く'});
    },
  );
}
