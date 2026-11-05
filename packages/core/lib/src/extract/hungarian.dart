/// Minimum-cost assignment (Hungarian method) with an optional "no match".
///
/// The O(n³) shortest-augmenting-path form (Jonker–Volgenant style potentials)
/// on a square matrix: rectangular input is padded, and "no match" is one
/// extra column per row that only that row may take.
library;

/// For each row, the column it is assigned to so that the total cost is
/// lowest, or null for no column. The matrix may be rectangular (each column
/// is used at most once). With [unmatchedCost], a row may stay unmatched at
/// that cost; without it every row gets a column while columns last.
List<int?> assignMinimumCost(List<List<double>> cost, {double? unmatchedCost}) {
  final rows = cost.length;
  if (rows == 0) return const [];
  final cols = cost.fold(0, (m, r) => r.length > m ? r.length : m);
  if (cols == 0) return List.filled(rows, null);

  // Columns: the real ones, then (with unmatchedCost) one "none" per row.
  final width = cols + (unmatchedCost == null ? 0 : rows);
  final n = rows > width ? rows : width;
  final big = _forbidden(cost, unmatchedCost);
  double at(int r, int c) {
    if (r >= rows) return 0; // padding rows take any column for free
    if (c < cols) return c < cost[r].length ? cost[r][c] : big;
    if (unmatchedCost != null && c < width) {
      return c - cols == r ? unmatchedCost : big;
    }
    return 0; // padding columns: a row left without a real column
  }

  final assigned = _solve(n, at);
  return [
    for (var r = 0; r < rows; r++)
      if (assigned[r] < cols && at(r, assigned[r]) < big) assigned[r] else null,
  ];
}

/// A cost no real choice reaches (an unusable cell).
double _forbidden(List<List<double>> cost, double? unmatched) {
  var top = unmatched?.abs() ?? 0.0;
  for (final r in cost) {
    for (final v in r) {
      if (v.isFinite && v.abs() > top) top = v.abs();
    }
  }
  return (top + 1) * (cost.length + 1) * 4;
}

/// Column of every row of an n×n matrix, minimizing the total.
List<int> _solve(int n, double Function(int r, int c) at) {
  // 1-based arrays as in the classic formulation; index 0 is the virtual row.
  final u = List<double>.filled(n + 1, 0);
  final v = List<double>.filled(n + 1, 0);
  final p = List<int>.filled(n + 1, 0); // p[c]: row matched to column c
  final way = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= n; i++) {
    p[0] = i;
    var j0 = 0;
    final minv = List<double>.filled(n + 1, double.infinity);
    final used = List<bool>.filled(n + 1, false);
    do {
      used[j0] = true;
      final i0 = p[j0];
      var delta = double.infinity;
      var j1 = 0;
      for (var j = 1; j <= n; j++) {
        if (used[j]) continue;
        final c = _finite(at(i0 - 1, j - 1)) - u[i0] - v[j];
        if (c < minv[j]) {
          minv[j] = c;
          way[j] = j0;
        }
        if (minv[j] < delta) {
          delta = minv[j];
          j1 = j;
        }
      }
      for (var j = 0; j <= n; j++) {
        if (used[j]) {
          u[p[j]] += delta;
          v[j] -= delta;
        } else {
          minv[j] -= delta;
        }
      }
      j0 = j1;
    } while (p[j0] != 0);
    do {
      final j1 = way[j0];
      p[j0] = p[j1];
      j0 = j1;
    } while (j0 != 0);
  }
  final rowToCol = List<int>.filled(n, 0);
  for (var j = 1; j <= n; j++) {
    if (p[j] > 0) rowToCol[p[j] - 1] = j - 1;
  }
  return rowToCol;
}

/// Infinite or NaN cells would poison the potentials; treat them as very costly.
double _finite(double v) => v.isFinite ? v : 1e12;
