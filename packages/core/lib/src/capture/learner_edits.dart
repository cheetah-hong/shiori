/// What the learner does to an entry on the review screen.
library;

import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';

/// The learner pressed 고치기 with these values.
///
/// A changed cell loses all its flags. Looking at the entry and saving it
/// confirms the rest: "의심" clears on every cell even when the
/// value is unchanged, while automatic fixes and guesses on unchanged cells
/// stay. The example is confirmed only when [checksExample] (it was shown),
/// including "this word has none". A cell left empty is flagged missing again.
CapturedEntry applyLearnerEdits(
  CapturedEntry entry, {
  required String headword,
  required List<String> readings,
  required PartOfSpeech? pos,
  required String meaning,
  Example? example,
  bool checksExample = false,
}) {
  var e = entry;
  if (headword != entry.headword) e = e.edit(headword: headword);
  if (readings.join('/') != entry.readings.join('/')) {
    e = e.edit(readings: readings);
  }
  if (pos != entry.pos) e = e.edit(pos: pos);
  if (meaning != entry.meaning) e = e.edit(meaning: meaning);
  if (checksExample &&
      (example != entry.example ||
          entry.statusOf(EntryField.example) == FieldStatus.needsReview)) {
    e = e.edit(example: example);
  }
  if (e.issues.any(_confirmedByLooking)) {
    e = e.copyWith(
      issues: [
        for (final i in e.issues)
          if (!_confirmedByLooking(i)) i,
      ],
    );
  }
  return flagMissingFields(e);
}

bool _confirmedByLooking(EntryIssue i) => i.kind == IssueKind.suspect;

/// Core cells that are empty. Used after the learner edits an entry, so
/// clearing a cell by hand flags it again.
List<EntryField> missingFieldsOf(CapturedEntry entry) => [
  if (entry.headword.trim().isEmpty) EntryField.headword,
  // A kanji word must have a reading; kana words have none.
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
