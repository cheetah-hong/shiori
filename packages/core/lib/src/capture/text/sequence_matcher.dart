/// Port of Python's `difflib.SequenceMatcher(None, a, b).ratio()` over code points.
///
/// Used to score example sentences against the ground truth (similarity ≥ 0.9),
/// exactly like the reference scorer. Includes difflib's "autojunk" heuristic.
library;

double sequenceRatio(String a, String b) {
  final sa = a.runes.toList();
  final sb = b.runes.toList();
  final length = sa.length + sb.length;
  if (length == 0) return 1.0;
  return 2.0 * _SequenceMatcher(sa, sb).matchingCharacters() / length;
}

final class _SequenceMatcher {
  _SequenceMatcher(this.a, this.b) : b2j = _chainB(b);

  final List<int> a;
  final List<int> b;
  final Map<int, List<int>> b2j;

  static Map<int, List<int>> _chainB(List<int> b) {
    final b2j = <int, List<int>>{};
    for (final (j, elt) in b.indexed) {
      (b2j[elt] ??= <int>[]).add(j);
    }
    // difflib autojunk: drop elements that make up more than 1% of a long b.
    if (b.length >= 200) {
      final ntest = b.length ~/ 100 + 1;
      b2j.removeWhere((_, idxs) => idxs.length > ntest);
    }
    return b2j;
  }

  (int, int, int) _findLongestMatch(int alo, int ahi, int blo, int bhi) {
    var besti = alo, bestj = blo, bestsize = 0;
    var j2len = <int, int>{};
    for (var i = alo; i < ahi; i++) {
      final newj2len = <int, int>{};
      for (final j in b2j[a[i]] ?? const <int>[]) {
        if (j < blo) continue;
        if (j >= bhi) break;
        final k = newj2len[j] = (j2len[j - 1] ?? 0) + 1;
        if (k > bestsize) {
          besti = i - k + 1;
          bestj = j - k + 1;
          bestsize = k;
        }
      }
      j2len = newj2len;
    }
    // No junk set (isjunk=None): extend the match over equal neighbours.
    while (besti > alo && bestj > blo && a[besti - 1] == b[bestj - 1]) {
      besti--;
      bestj--;
      bestsize++;
    }
    while (besti + bestsize < ahi &&
        bestj + bestsize < bhi &&
        a[besti + bestsize] == b[bestj + bestsize]) {
      bestsize++;
    }
    return (besti, bestj, bestsize);
  }

  int matchingCharacters() {
    var total = 0;
    final queue = <(int, int, int, int)>[(0, a.length, 0, b.length)];
    while (queue.isNotEmpty) {
      final (alo, ahi, blo, bhi) = queue.removeLast();
      final (i, j, k) = _findLongestMatch(alo, ahi, blo, bhi);
      if (k == 0) continue;
      total += k;
      if (alo < i && blo < j) queue.add((alo, i, blo, j));
      if (i + k < ahi && j + k < bhi) queue.add((i + k, ahi, j + k, bhi));
    }
    return total;
  }
}
