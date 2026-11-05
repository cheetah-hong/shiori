/// Small helpers that reproduce Python semantics the reference parser relies on.
///
/// The Dart port must give the same numbers as `parse_eval.py`, so sorting must be
/// stable, `min` must return the first minimum, and `round(x, 2)` must round
/// half to even on the exact binary value.
library;

import 'package:shiori_core/src/capture/text/chars.dart';

/// Python-style comparison: equal unless one is strictly smaller (so -0.0 == 0.0).
int cmpNum(num a, num b) => a < b ? -1 : (a > b ? 1 : 0);

/// A stable sort (Python `sorted`). Returns a new list; [items] is not touched.
List<T> stableSorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final indexed = items.indexed.toList();
  indexed.sort((p, q) {
    final c = compare(p.$2, q.$2);
    return c != 0 ? c : p.$1 - q.$1;
  });
  return [for (final (_, item) in indexed) item];
}

/// First element with the smallest key (Python `min(xs, key=...)`), or null when empty.
T? minBy<T>(Iterable<T> items, num Function(T) key) {
  T? best;
  num? bestKey;
  for (final item in items) {
    final k = key(item);
    if (bestKey == null || k < bestKey) {
      best = item;
      bestKey = k;
    }
  }
  return best;
}

/// First element with the largest key, or null when empty.
T? maxBy<T>(Iterable<T> items, num Function(T) key) {
  T? best;
  num? bestKey;
  for (final item in items) {
    final k = key(item);
    if (bestKey == null || k > bestKey) {
      best = item;
      bestKey = k;
    }
  }
  return best;
}

/// `statistics.median`: the middle value, or the mean of the two middle values.
double median(Iterable<double> values) {
  final sorted = stableSorted(values, cmpNum);
  if (sorted.isEmpty) throw StateError('median of no values');
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Python `round(x, 2)`.
///
/// `toStringAsFixed` already rounds the exact binary value; only exact ties
/// (multiples of 1/8 such as 0.125) differ, where Python rounds half to even.
double pyRound2(double x) {
  final scaled = x * 100;
  final isExactTie =
      x * 8 == (x * 8).truncateToDouble() &&
      (scaled - scaled.truncateToDouble()).abs() == 0.5;
  if (isExactTie) {
    final lower = scaled.floor();
    final even = lower.isEven ? lower : lower + 1;
    return even / 100;
  }
  return double.parse(x.toStringAsFixed(2));
}

/// Python `f"{k:04d}"`.
String pad4(int k) => k < 0
    ? '-${(-k).toString().padLeft(3, '0')}'
    : k.toString().padLeft(4, '0');

/// Python `s.strip(chars)`.
String stripChars(String s, String chars) {
  final drop = chars.runes.toSet();
  final runes = s.runes.toList();
  var start = 0;
  var end = runes.length;
  while (start < end && drop.contains(runes[start])) {
    start++;
  }
  while (end > start && drop.contains(runes[end - 1])) {
    end--;
  }
  return String.fromCharCodes(runes.sublist(start, end));
}

final RegExp _decimal = RegExp(r'^\p{Nd}+$', unicode: true);

/// Python `str.isdigit()` for the decimal digits OCR can produce.
bool isDecimal(String s) => _decimal.hasMatch(s);

/// Python `int(s)` for decimal digit strings, including full-width digits.
/// Null where Python would raise (digits of other scripts, empty text).
int? pyInt(String s) => int.tryParse(nfkc(s).trim());
