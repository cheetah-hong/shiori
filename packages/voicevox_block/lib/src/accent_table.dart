import 'package:voicevox_block/src/morae.dart';

/// Pitch accents by (written form, reading), read from the app's accent
/// asset: one `form\treading\taccents` line per entry, reading empty when it
/// is the form itself (kana words), accents as `0` or `2,1` (first = main).
final class AccentTable {
  AccentTable._(this._byKey);

  /// Throws [FormatException] on a line that is not `form\treading\taccents`
  /// with at least one accent number.
  factory AccentTable.parse(String tsv) {
    final byKey = <String, List<int>>{};
    for (final (i, line) in tsv.split('\n').indexed) {
      if (line.isEmpty) continue;
      final cols = line.split('\t');
      if (cols.length != 3 || cols[0].isEmpty || cols[2].isEmpty) {
        throw FormatException('accent line ${i + 1}: $line');
      }
      final accents = [
        for (final part in cols[2].split(','))
          int.tryParse(part) ??
              (throw FormatException('accent line ${i + 1}: $line')),
      ];
      if (accents.any((a) => a < 0)) {
        throw FormatException('accent line ${i + 1}: $line');
      }
      final reading = cols[1].isEmpty ? cols[0] : cols[1];
      byKey.putIfAbsent(
        _key(cols[0], reading),
        () => List.unmodifiable(accents),
      );
    }
    return AccentTable._(byKey);
  }

  /// A table with no entries (no accent asset in this build).
  static final AccentTable empty = AccentTable._(const {});

  final Map<String, List<int>> _byKey;

  int get length => _byKey.length;

  /// Accents of [form] read [reading] (hiragana or katakana), first one
  /// first; empty when the data has none.
  List<int> lookup(String form, String reading) {
    if (form.isEmpty) return const [];
    return _byKey[_key(form, reading)] ??
        _byKey[_key(form, toHiragana(reading))] ??
        const [];
  }

  static String _key(String form, String reading) => '$form\t$reading';
}
