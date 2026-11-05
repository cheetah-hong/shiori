// T8–T9: splitting sentences into dictionary words.
import 'package:shiori_core/src/extract/lattice.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

void main() {
  final segmenter = SentenceSegmenter(testLexicon());

  group(
    'T8 content words in dictionary form; particles, auxiliaries and です go',
    () {
      const cases = {
        'ご飯を食べます。': ['ご飯', '食べる'],
        'とても静かな部屋です。': ['とても', '静か', '部屋'],
        '学校に行きました。': ['学校', '行く'],
      };
      for (final MapEntry(key: sentence, value: words) in cases.entries) {
        test(sentence, () async {
          final content = await segmenter.contentWords(sentence);

          expect(content.map((t) => t.base), words);
        });
      }

      test('the full path keeps the particle as a function word', () async {
        final tokens = await segmenter.segment('ご飯を食べます。');

        final wo = tokens.firstWhere((t) => t.surface == 'を');
        expect(wo.isFunctionWord, isTrue);
        expect(tokens.firstWhere((t) => t.base == '食べる').steps, isNotEmpty);
      });

      test('a kana に is the particle, not the number 二', () async {
        final tokens = await segmenter.segment('学校に行きました。');

        final ni = tokens.firstWhere((t) => t.surface == 'に');
        expect(ni.partsOfSpeech, contains('prt'));
        expect(ni.isFunctionWord, isTrue);
      });
    },
  );

  test(
    'T9 an unknown glyph does not stop the split; known words still come out',
    () async {
      final content = await segmenter.contentWords('ご飯を△べます');

      expect(content.map((t) => t.base), contains('ご飯'));
      final tokens = await segmenter.segment('ご飯を△べます');
      expect(tokens.where((t) => !t.known), isNotEmpty);
    },
  );
}
