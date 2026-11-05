import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// Marks empty cells for the review screen. Runs last in the chain.
final class MissingFieldFlagger implements EntryCorrector {
  const MissingFieldFlagger();

  @override
  String get id => 'missing-fields';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async =>
      flagMissingFields(entry);
}

/// Core cells that are empty. Also used after the learner edits an entry,
/// so clearing a cell by hand flags it again.
List<EntryField> missingFieldsOf(CapturedEntry entry) => [
  if (entry.headword.trim().isEmpty) EntryField.headword,
  // A kanji word must have a reading; kana words print `–` instead.
  if (containsKanji(entry.headword) && entry.readings.isEmpty)
    EntryField.readings,
  if (entry.meaning.trim().isEmpty) EntryField.meaning,
  if (entry.pos == null) EntryField.pos,
];

/// Adds a `missing` issue for every empty core cell not flagged yet.
CapturedEntry flagMissingFields(CapturedEntry entry) {
  final already = {
    for (final i in entry.issues)
      if (i.kind == IssueKind.missing) i.field,
  };
  final missing = [
    for (final f in missingFieldsOf(entry))
      if (!already.contains(f)) f,
  ];
  if (missing.isEmpty) return entry;
  return entry.copyWith(
    issues: [...entry.issues, for (final f in missing) EntryIssue.missing(f)],
  );
}
