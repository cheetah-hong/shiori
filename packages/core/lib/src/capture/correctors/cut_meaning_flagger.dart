import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// A meaning ending in a comma or a middle dot lost its last word (OCR stopped
/// early). Flagged so the learner checks it; nothing is changed.
final class CutMeaningFlagger implements EntryCorrector {
  const CutMeaningFlagger();

  @override
  String get id => 'cut-meanings';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    final m = entry.meaning.trimRight();
    if (!(m.endsWith(',') || m.endsWith('·'))) return entry;
    return entry.withIssue(
      const EntryIssue.suspect(EntryField.meaning, note: '뜻 끝이 잘렸을 수 있음'),
    );
  }
}
