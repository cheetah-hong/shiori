// T6–T7: dictionary forms from conjugated words (rules confirmed by the lexicon).
import 'package:shiori_core/src/extract/deconjugator.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

void main() {
  final lemmatizer = Lemmatizer(testLexicon());

  group('T6 the most likely dictionary form, with the rule steps', () {
    const cases = {
      '食べました': '食べる',
      '書いて': '書く',
      '行った': '行く', // v5k-s: 行って/行った, not 行いて; 行う past loses
      '来なかった': '来る',
      'した': 'する',
      '静かな': '静か',
      '高くない': '高い',
      '読まれた': '読む',
    };
    for (final MapEntry(key: surface, value: base) in cases.entries) {
      test('$surface → $base', () async {
        final lemmas = await lemmatizer.lemmas(surface);

        expect(lemmas, isNotEmpty);
        expect(lemmas.first.base, base);
        expect(lemmas.first.conjugated, isTrue);
        expect(lemmas.first.steps, isNotEmpty);
      });
    }

    test(
      'a word already in dictionary form is its own lemma, no steps',
      () async {
        final lemmas = await lemmatizer.lemmas('学校');

        expect(lemmas.first.base, '学校');
        expect(lemmas.first.conjugated, isFalse);
        expect(lemmas.first.steps, isEmpty);
      },
    );
  });

  test(
    'T7 a base whose POS does not fit the rule is dropped (no v1 高くる)',
    () async {
      final raw = Deconjugator.standard.deconjugate('高くない');
      expect(
        raw.any((d) => d.base == '高くる'),
        isTrue,
        reason: 'the rules do propose it',
      );

      final lemmas = await lemmatizer.lemmas('高くない');

      expect(lemmas.map((l) => l.base), isNot(contains('高くる')));
      expect(lemmas.map((l) => l.base), contains('高い'));
    },
  );

  test('every deinflection carries the POS tag its rule needs', () {
    final raw = Deconjugator.standard.deconjugate('食べました');

    final taberu = raw.firstWhere((d) => d.base == '食べる');
    expect(taberu.tag, 'v1');
    expect(raw.firstWhere((d) => d.tag == null).base, '食べました');
  });
}
