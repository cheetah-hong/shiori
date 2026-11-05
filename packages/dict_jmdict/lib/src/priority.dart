/// JMdict priority tags (`ke_pri` / `re_pri`) and the ranking built on them.
library;

/// Priority tags stored as bits in the `pri` columns (see build_jmdict_db.py).
enum PriorityTag {
  news1(1),
  news2(2),
  ichi1(4),
  ichi2(8),
  spec1(16),
  spec2(32),
  gai1(64),
  gai2(128);

  const PriorityTag(this.bit);

  final int bit;
}

/// news1, ichi1, spec1, spec2, gai1: JMdict's own definition of a common word.
const int commonMask = 1 | 4 | 16 | 32 | 64;

/// How frequent a form (or a headword/reading pair) is, as JMdict records it.
final class Priority implements Comparable<Priority> {
  const Priority(this.bits, [this.nf]);

  /// JMdict tags a kanji form and a reading separately, and a priority can
  /// belong to one particular pair only. A pair keeps the tags both carry.
  factory Priority.pair(Priority kanji, Priority reading) => Priority(
    kanji.bits & reading.bits,
    kanji.nf == null || reading.nf == null
        ? null
        : (kanji.nf! > reading.nf! ? kanji.nf : reading.nf),
  );

  static const none = Priority(0);

  final int bits;

  /// nfXX band: 1 means among the 500 most frequent words in the news corpus.
  final int? nf;

  bool get isCommon => bits & commonMask != 0;

  List<PriorityTag> get tags => [
    for (final t in PriorityTag.values)
      if (bits & t.bit != 0) t,
  ];

  /// Codes as JMdict writes them, for example `[news1, ichi1, nf01]`.
  List<String> get codes => [
    for (final t in tags) t.name,
    if (nf != null) 'nf${nf.toString().padLeft(2, '0')}',
  ];

  /// Common first, then lower nf band, then any tag at all, then more tags.
  @override
  int compareTo(Priority other) {
    if (isCommon != other.isCommon) return isCommon ? -1 : 1;
    final byNf = (nf ?? 99).compareTo(other.nf ?? 99);
    if (byNf != 0) return byNf;
    if ((bits == 0) != (other.bits == 0)) return bits == 0 ? 1 : -1;
    return _bitCount(other.bits).compareTo(_bitCount(bits));
  }

  @override
  bool operator ==(Object other) =>
      other is Priority && other.bits == bits && other.nf == nf;

  @override
  int get hashCode => Object.hash(bits, nf);

  @override
  String toString() => codes.isEmpty ? 'none' : codes.join(' ');
}

int _bitCount(int v) {
  var n = 0;
  for (var x = v; x != 0; x &= x - 1) {
    n++;
  }
  return n;
}
