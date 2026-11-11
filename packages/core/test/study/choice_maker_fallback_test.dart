// A question exists for a word whenever three wrong options can stand side
// by side, whatever the seed: when the shuffled pick blocks itself, the
// options are picked again in a fixed order. Made-up words.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime(2026, 11, 12, 9);
  const maker = ChoiceMaker();

  Word w(String id, String meaning) => Word(
    id: id,
    headword: '語$id',
    readings: const ['ご'],
    meaning: meaning,
    createdAt: at,
  );

  // For c: b2 overlaps a and b; picking b2 first leaves only e.
  final pool = [
    w('a', '하나'),
    w('b', '둘'),
    w('b2', '하나, 둘'),
    w('c', '셋'),
    w('e', '넷'),
  ];

  test('every seed gives a question when one can be made', () {
    final c = pool[3];
    expect(maker.canAskFor(c, pool), isTrue);
    for (var seed = 0; seed < 200; seed++) {
      final q = maker.make(answer: c, pool: pool, seed: seed);
      expect(q, isNotNull, reason: 'seed $seed');
      final glosses = [
        for (final o in q!.options) ...meaningGlosses(o.meaning),
      ];
      expect(glosses.toSet(), hasLength(glosses.length));
    }
  });

  test('canAskFor: no question when the wrong options cannot stand apart', () {
    expect(maker.canAskFor(pool[2], pool), isFalse, reason: 'b2: only c, e');
    expect(maker.canAskFor(pool[0], pool), isTrue);
    expect(maker.canAskFor(w('x', ''), [w('x', ''), ...pool]), isFalse);
    expect(maker.canAskFor(pool[0], const []), isFalse);
  });

  test('canAskFor agrees with make for every word and seed', () {
    for (final answer in pool) {
      final can = maker.canAskFor(answer, pool);
      for (var seed = 0; seed < 50; seed++) {
        expect(
          maker.make(answer: answer, pool: pool, seed: seed) != null,
          can,
          reason: '${answer.id} seed $seed',
        );
      }
    }
  });
}
