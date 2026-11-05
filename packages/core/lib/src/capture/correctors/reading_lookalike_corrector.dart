import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// Katakana that look like hiragana inside a hiragana reading (`のリかえる`
/// → `のりかえる`). Readings that are katakana words stay as they are.
final class ReadingLookalikeCorrector implements EntryCorrector {
  const ReadingLookalikeCorrector();

  static const Map<String, String> _lookalikes = {
    'リ': 'り',
    'ヘ': 'へ',
    'ベ': 'べ',
    'ペ': 'ぺ',
  };

  @override
  String get id => 'reading-lookalikes';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    final fixed = [for (final r in entry.readings) _fix(r)];
    final changed = [
      for (final (i, r) in entry.readings.indexed)
        if (fixed[i] != r) '$r → ${fixed[i]}',
    ];
    if (changed.isEmpty) return entry;
    return entry.copyWith(
      readings: fixed,
      issues: [
        ...entry.issues,
        EntryIssue.corrected(EntryField.readings, note: changed.join(', ')),
      ],
    );
  }

  static String _fix(String reading) {
    if (!reading.runes.any(isHira)) return reading;
    // Kana are single UTF-16 code units, so splitting by code unit is safe.
    final fixed = reading.split('').map((c) => _lookalikes[c] ?? c).join();
    // Only when the whole reading becomes hiragana (ー may stay).
    return fixed.runes.every((c) => isHira(c) || c == 0x30FC) ? fixed : reading;
  }
}
