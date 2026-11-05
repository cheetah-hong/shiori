import 'package:shiori_core/src/capture/correctors/confusables.dart';
import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// `ー` → `一`, `+` → `十` (whole headword, only when a reading was read),
/// and look-alike katakana inside kanji words (`タ` → `夕`).
final class ConfusableGlyphCorrector implements EntryCorrector {
  const ConfusableGlyphCorrector();

  @override
  String get id => 'confusable-glyphs';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    final h = entry.headword;
    final whole = confusableWhole[h];
    if (whole != null && entry.readings.isNotEmpty) {
      return _fixed(entry, whole);
    }
    if (containsKanji(h) && h.runes.any(confusableInKanji.containsKey)) {
      return _fixed(
        entry,
        String.fromCharCodes(h.runes.map((c) => confusableInKanji[c] ?? c)),
      );
    }
    return entry;
  }

  CapturedEntry _fixed(CapturedEntry entry, String headword) => entry.copyWith(
    headword: headword,
    issues: [
      ...entry.issues,
      EntryIssue.corrected(
        EntryField.headword,
        note: '${entry.headword} → $headword',
      ),
    ],
  );
}
