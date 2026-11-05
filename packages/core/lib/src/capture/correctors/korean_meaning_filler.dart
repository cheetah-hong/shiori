import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';
import 'package:shiori_core/src/ports/korean_glossary.dart';

/// Fills an empty meaning cell with the glossary's first meaning, marked as a
/// guess ("추정", the note names the dictionary).
///
/// A meaning read from the page is never changed, even one flagged as cut.
/// Nothing is filled when the headword itself is in doubt (not read, or not
/// in the dictionary): a meaning for a misread word would look checked.
/// Without a dictionary block (`PairStatus.unavailable`) that check cannot
/// run; the glossary's own reading-and-spelling match is then the only one.
///
/// Runs after the dictionary check and before the missing-field flags.
final class KoreanMeaningFiller implements EntryCorrector {
  const KoreanMeaningFiller(this.glossary);

  final KoreanGlossary glossary;

  @override
  String get id => 'korean-meaning';

  static const _doubtful = {
    IssueKind.missing,
    IssueKind.suspect,
    IssueKind.unverified,
  };

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    if (entry.meaning.trim().isNotEmpty) return entry;
    if (entry.headword.trim().isEmpty) return entry;
    if (entry.issues.any(
      (i) => i.field == EntryField.headword && _doubtful.contains(i.kind),
    )) {
      return entry;
    }
    final List<KoreanSense> senses;
    try {
      senses = await glossary.lookup(
        entry.headword,
        readings: entry.readings,
        limit: 1,
      );
    } on Exception {
      // A damaged glossary file must not stop the page: the cell stays empty
      // and is flagged as missing, as without a glossary.
      return entry;
    }
    if (senses.isEmpty) return entry;
    final first = senses.first;
    return entry.copyWith(
      meaning: first.text,
      issues: [
        ...entry.issues,
        EntryIssue.inferred(
          EntryField.meaning,
          note: '사전 뜻: ${first.source.label}',
        ),
      ],
    );
  }
}
