/// What the learner does to an entry on the review screen.
library;

import 'package:shiori_core/src/capture/correctors/missing_field_flagger.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';

/// The learner chose [headword] from the dictionary candidates: it replaces
/// the headword (clearing its flags) and is marked as picked, which shows like
/// a fix but is not counted as an automatic one.
CapturedEntry pickHeadword(CapturedEntry entry, String headword) => entry
    .edit(headword: headword)
    .withIssue(
      EntryIssue.picked(EntryField.headword, note: '직접 고름 → $headword'),
    );

/// The learner pressed 고치기 with these values.
///
/// A changed cell loses all its flags. Looking at the entry and saving it
/// confirms the rest: "의심" and "사전에 없음" clear on every cell even when the
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

bool _confirmedByLooking(EntryIssue i) =>
    i.kind == IssueKind.suspect || i.kind == IssueKind.unverified;
