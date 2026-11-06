/// What the review screen does with an entry: pick a
/// candidate, place an unpaired fragment, make an entry from one, approve
/// every high entry. All return new values.
library;

import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/extract/fragment.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/evidence.dart';

/// Readings typed or picked as one text (`あした/あす`, `ねん・とし`).
List<String> splitReadings(String text) => [
  for (final r in text.split(RegExp(r'[/／・,，、\s]+')))
    if (r.trim().isNotEmpty) r.trim(),
];

String _valueOf(CapturedEntry e, EntryField field) => switch (field) {
  EntryField.headword => e.headword,
  EntryField.readings => e.readings.join('/'),
  EntryField.meaning => e.meaning,
  EntryField.pos || EntryField.example => '',
};

CapturedEntry _set(CapturedEntry e, EntryField field, String value) =>
    switch (field) {
      EntryField.headword => e.edit(headword: value),
      EntryField.readings => e.edit(readings: splitReadings(value)),
      EntryField.meaning => e.edit(meaning: value),
      EntryField.pos || EntryField.example => e,
    };

/// The learner chose [value] from the cell's candidates. The value it
/// replaces becomes a candidate, so the choice can be undone. A candidate
/// other than the extracted value comes from the dictionary (its senses):
/// the cell then says so, with no photo boxes and no pairing; picking the
/// extracted value again restores its source and boxes.
///
/// A kanji spelling picked for a headword left as kana with no reading (the
/// dictionary had several spellings of its kana and meaning) takes the kana
/// as its reading; a kanji headword left without any reading is flagged.
CapturedEntry pickCandidate(
  CapturedEntry entry,
  EntryField field,
  String value,
) {
  final old = _valueOf(entry, field);
  final picked = _keepKanaAsReading(
    entry,
    field,
    old,
    _set(
      entry,
      field,
      value,
    ).withIssue(EntryIssue.picked(field, note: '후보에서 고름 → $value')),
  );
  final evidence = picked.evidence;
  final cell = evidence?.of(field);
  if (evidence == null || cell == null) return picked;
  final original = cell.original ?? (value: old, evidence: cell);
  final candidates = [
    if (old.trim().isNotEmpty) old,
    for (final c in cell.candidates)
      if (c != value && c != old) c,
  ];
  final next = value == original.value
      ? original.evidence.copyWith(
          candidates: candidates,
          checked: true,
          original: null,
        )
      : FieldEvidence(
          source: FieldSource.dictionary,
          candidates: candidates,
          note: '후보에서 고름',
          checked: true,
          original: original,
        );
  return picked.copyWith(evidence: evidence.withField(field, next));
}

/// [picked] with the kana headword [old] of [entry] as its reading, when a
/// kanji spelling replaced it and the entry had no reading; with no kana to
/// keep, the missing reading is flagged.
CapturedEntry _keepKanaAsReading(
  CapturedEntry entry,
  EntryField field,
  String old,
  CapturedEntry picked,
) {
  if (field != EntryField.headword ||
      entry.readings.isNotEmpty ||
      !containsKanji(picked.headword)) {
    return picked;
  }
  final kana = old.trim();
  if (kana.isNotEmpty && kanaOnly(kana)) {
    return picked.copyWith(readings: [kana]);
  }
  // No kana to keep: the reading is missing (only that cell is flagged).
  return picked.issues.any(
        (i) => i.field == EntryField.readings && i.kind == IssueKind.missing,
      )
      ? picked
      : picked.withIssue(const EntryIssue.missing(EntryField.readings));
}

/// The learner placed an unpaired [fragment] on [field] of [entry].
CapturedEntry attachFragment(
  CapturedEntry entry,
  EntryField field,
  Fragment fragment,
) {
  final placed = _set(
    entry,
    field,
    fragment.text,
  ).withIssue(EntryIssue.picked(field, note: '조각을 붙임 → ${fragment.text}'));
  final box = boxOf(fragment);
  final cell = FieldEvidence(
    source: FieldSource.photo,
    boxes: [box],
    candidates: [
      if (_valueOf(entry, field).trim().isNotEmpty) _valueOf(entry, field),
    ],
    note: '직접 붙임',
    checked: true,
  );
  final evidence =
      placed.evidence ?? const EntryEvidence(origin: WordOrigin.wordList);
  return placed.copyWith(evidence: evidence.withField(field, cell));
}

/// A new entry from an unpaired [fragment]: Japanese text is the headword,
/// Korean text the meaning; the other cells are left for the learner.
CapturedEntry entryFromFragment(Fragment fragment) {
  final korean = fragment.isKorean;
  final field = korean ? EntryField.meaning : EntryField.headword;
  return CapturedEntry(
    headword: korean ? '' : fragment.text,
    readings: const [],
    pos: null,
    meaning: korean ? fragment.text : '',
    issues: [
      if (korean) const EntryIssue.missing(EntryField.headword),
      if (!korean) const EntryIssue.missing(EntryField.meaning),
    ],
    evidence: EntryEvidence(
      origin: WordOrigin.wordList,
      fields: {
        field: FieldEvidence(
          source: FieldSource.photo,
          boxes: [boxOf(fragment)],
          note: '직접 만듦',
          checked: true,
        ),
      },
    ),
  );
}

/// The fragment's box on the page.
PhotoBox boxOf(Fragment f) =>
    PhotoBox(x: f.x, y: f.y, width: f.width, height: f.height);

/// Entries whose every pairing is high (and not yet approved).
int highConfidenceCount(CaptureDraft draft) => draft.entries
    .where((e) => (e.evidence?.isHigh ?? false) && !e.evidence!.confirmed)
    .length;

/// "높음 전체 승인": every entry whose pairings are all high is confirmed;
/// the others are left for the learner.
CaptureDraft approveHighConfidence(CaptureDraft draft) => draft.copyWith(
  entries: [
    for (final e in draft.entries)
      if (e.evidence case final ev? when ev.isHigh)
        e.copyWith(evidence: ev.confirm())
      else
        e,
  ],
);
