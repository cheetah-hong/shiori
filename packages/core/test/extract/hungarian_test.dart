// T10: minimum-cost assignment.
import 'package:shiori_core/src/extract/hungarian.dart';
import 'package:test/test.dart';

double _total(List<List<double>> cost, List<int?> a) => [
  for (final (r, c) in a.indexed)
    if (c != null) cost[r][c],
].fold(0.0, (s, v) => s + v);

void main() {
  group('T10 Hungarian assignment', () {
    test('3×3: the lowest total, worked out by hand', () {
      // Rows 0,1,2 → columns 1,0,2: 2 + 3 + 2 = 7 (every other choice costs more).
      const cost = [
        [4.0, 2.0, 8.0],
        [3.0, 7.0, 6.0],
        [5.0, 9.0, 2.0],
      ];

      final a = assignMinimumCost(cost);

      expect(a, [1, 0, 2]);
      expect(_total(cost, a), 7.0);
    });

    test('2×3: each row gets a different column', () {
      const cost = [
        [9.0, 1.0, 5.0],
        [9.0, 2.0, 3.0],
      ];

      expect(assignMinimumCost(cost), [1, 2]);
    });

    test('3×2: one row is left without a column', () {
      const cost = [
        [1.0, 9.0],
        [2.0, 3.0],
        [8.0, 1.5],
      ];

      final a = assignMinimumCost(cost);

      expect(a, [0, null, 1]);
    });

    test('rows stay unmatched when every cost is above the no-match cost', () {
      const cost = [
        [5.0, 6.0],
        [7.0, 5.5],
      ];

      expect(assignMinimumCost(cost, unmatchedCost: 1.0), [null, null]);
    });

    test('no-match cost: a cheap pair is kept, an expensive one dropped', () {
      const cost = [
        [0.2, 3.0],
        [3.0, 2.5],
      ];

      expect(assignMinimumCost(cost, unmatchedCost: 1.0), [0, null]);
    });

    test('an empty matrix gives no assignment', () {
      expect(assignMinimumCost(const []), isEmpty);
      expect(assignMinimumCost(const [[], []]), [null, null]);
    });
  });
}
