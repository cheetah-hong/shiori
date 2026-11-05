import 'package:shiori_core/src/capture/vocab/fields.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// The POS badge 동 read as `8` in front of the meaning (`8 내리다`).
///
/// The template only splits off badges it knows, so the `8` is still the start
/// of the meaning and no POS was set.
final class BadgeMisreadCorrector implements EntryCorrector {
  const BadgeMisreadCorrector();

  @override
  String get id => 'badge-misreads';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    if (entry.pos != null) return entry;
    final m = eightBadge.firstMatch(entry.meaning);
    if (m == null) return entry;
    return entry.copyWith(
      pos: PartOfSpeech.verb,
      meaning: entry.meaning.substring(m.end).trim(),
      issues: [
        ...entry.issues,
        const EntryIssue.corrected(EntryField.pos, note: '8 → 동'),
      ],
    );
  }
}
