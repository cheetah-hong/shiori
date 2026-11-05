import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// A comma between two Korean words read as a period (`싸다. 포장하다` →
/// `싸다, 포장하다`). Meanings list their senses with commas.
final class MeaningPunctuationCorrector implements EntryCorrector {
  const MeaningPunctuationCorrector();

  @override
  String get id => 'meaning-punctuation';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    final fixed = fixKoreanPeriods(entry.meaning);
    if (fixed == entry.meaning) return entry;
    return entry.copyWith(
      meaning: fixed,
      issues: [
        ...entry.issues,
        EntryIssue.corrected(
          EntryField.meaning,
          note: '${entry.meaning} → $fixed',
        ),
      ],
    );
  }
}
