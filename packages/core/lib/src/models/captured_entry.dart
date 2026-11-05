import 'package:shiori_core/src/models/evidence.dart';
import 'package:shiori_core/src/models/list_equality.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';

/// Editable fields of a captured entry, used to attach review flags.
enum EntryField { headword, readings, pos, meaning, example }

enum IssueKind {
  /// The field could not be read. The review screen asks the learner to check it.
  missing,

  /// A corrector changed what OCR read. Shown as "자동 보정됨".
  corrected,

  /// OCR read nothing and a corrector filled in a likely value (a POS guessed
  /// from the headword). Lighter than [missing]: usually right.
  inferred,

  /// The field was read but looks incomplete (a meaning ending in a comma).
  /// The learner should check it, like [missing].
  suspect,

  /// The dictionary does not have the headword with its reading, and no
  /// look-alike glyph explains it. Shown as "사전에 없음"; counts as "확인 필요".
  unverified,

  /// The learner chose the value (a dictionary candidate for an unread
  /// headword). Shown like [corrected], but not counted as an automatic fix.
  picked,
}

/// How the review screen should present a field.
enum FieldStatus { ok, inferred, corrected, suspect, unverified, needsReview }

final class EntryIssue {
  const EntryIssue(this.field, this.kind, {this.note});

  const EntryIssue.missing(this.field) : kind = IssueKind.missing, note = null;

  const EntryIssue.corrected(this.field, {this.note})
    : kind = IssueKind.corrected;

  const EntryIssue.inferred(this.field, {this.note})
    : kind = IssueKind.inferred;

  const EntryIssue.suspect(this.field, {this.note}) : kind = IssueKind.suspect;

  const EntryIssue.unverified(this.field, {this.note})
    : kind = IssueKind.unverified;

  const EntryIssue.picked(this.field, {this.note}) : kind = IssueKind.picked;

  final EntryField field;
  final IssueKind kind;

  /// Human readable detail, for example `ー → 一`.
  final String? note;

  /// Same code as the reference parser, for example `headword:missing`.
  String get code => '${field.name}:${kind.name}';

  @override
  bool operator ==(Object other) =>
      other is EntryIssue &&
      other.field == field &&
      other.kind == kind &&
      other.note == note;

  @override
  int get hashCode => Object.hash(field, kind, note);

  @override
  String toString() => note == null ? code : '$code($note)';
}

/// Example sentence printed under an N3 entry, with its Korean translation.
final class Example {
  const Example({required this.ja, required this.ko});

  final String ja;
  final String ko;

  @override
  bool operator ==(Object other) =>
      other is Example && other.ja == ja && other.ko == ko;

  @override
  int get hashCode => Object.hash(ja, ko);

  @override
  String toString() => 'Example($ja / $ko)';
}

const Object _unset = Object();

/// A word read from a page, before the learner saves it (review draft).
final class CapturedEntry {
  const CapturedEntry({
    required this.no,
    required this.headword,
    required this.readings,
    required this.pos,
    required this.meaning,
    this.example,
    this.issues = const [],
    this.headwordCandidates = const [],
    this.included = true,
    this.ocrHeadword,
    this.evidence,
  });

  /// Textbook word number (`0001`), or null when it could not be inferred.
  final String? no;
  final String headword;

  /// Readings in kana. Empty for kana-only words (printed as `–`).
  final List<String> readings;
  final PartOfSpeech? pos;
  final String meaning;
  final Example? example;
  final List<EntryIssue> issues;

  /// Suggestions from a `Dictionary` block when the headword was not read.
  final List<String> headwordCandidates;

  /// Whether the learner keeps this entry when saving.
  final bool included;

  /// The headword as the template read it, before any corrector ran. Lets a
  /// later corrector undo an earlier one. Null for entries made by hand.
  final String? ocrHeadword;

  /// Where each cell came from and how sure its pairing is (general
  /// extractor only; null for the row templates). Shown on the review
  /// screen, never saved.
  final EntryEvidence? evidence;

  /// The strongest flag on [field]: missing, then unverified, suspect,
  /// corrected (or picked by the learner), inferred.
  FieldStatus statusOf(EntryField field) {
    final kinds = {
      for (final i in issues)
        if (i.field == field) i.kind,
    };
    if (kinds.contains(IssueKind.missing)) return FieldStatus.needsReview;
    if (kinds.contains(IssueKind.unverified)) return FieldStatus.unverified;
    if (kinds.contains(IssueKind.suspect)) return FieldStatus.suspect;
    if (kinds.contains(IssueKind.corrected) ||
        kinds.contains(IssueKind.picked)) {
      return FieldStatus.corrected;
    }
    if (kinds.contains(IssueKind.inferred)) return FieldStatus.inferred;
    return FieldStatus.ok;
  }

  /// A field is missing, looks wrong or is not in the dictionary: the learner
  /// should look at the entry.
  bool get needsReview => issues.any(
    (i) =>
        i.kind == IssueKind.missing ||
        i.kind == IssueKind.suspect ||
        i.kind == IssueKind.unverified,
  );

  /// A corrector changed a cell (not a value the learner picked).
  bool get wasCorrected => issues.any((i) => i.kind == IssueKind.corrected);

  /// Flagged for the learner in any way other than a missing example
  /// (the scorer's definition of "shown on the review screen").
  bool get isFlagged => issues.any((i) => i.field != EntryField.example);

  CapturedEntry copyWith({
    Object? no = _unset,
    String? headword,
    List<String>? readings,
    Object? pos = _unset,
    String? meaning,
    Object? example = _unset,
    List<EntryIssue>? issues,
    List<String>? headwordCandidates,
    bool? included,
    Object? ocrHeadword = _unset,
    Object? evidence = _unset,
  }) => CapturedEntry(
    no: identical(no, _unset) ? this.no : no as String?,
    headword: headword ?? this.headword,
    readings: List.unmodifiable(readings ?? this.readings),
    pos: identical(pos, _unset) ? this.pos : pos as PartOfSpeech?,
    meaning: meaning ?? this.meaning,
    example: identical(example, _unset) ? this.example : example as Example?,
    issues: List.unmodifiable(issues ?? this.issues),
    headwordCandidates: List.unmodifiable(
      headwordCandidates ?? this.headwordCandidates,
    ),
    included: included ?? this.included,
    ocrHeadword: identical(ocrHeadword, _unset)
        ? this.ocrHeadword
        : ocrHeadword as String?,
    evidence: identical(evidence, _unset)
        ? this.evidence
        : evidence as EntryEvidence?,
  );

  CapturedEntry withIssue(EntryIssue issue) =>
      copyWith(issues: [...issues, issue]);

  /// Applies the learner's edits. A field the learner touched counts as checked,
  /// so its review flags are cleared.
  CapturedEntry edit({
    String? headword,
    List<String>? readings,
    Object? pos = _unset,
    String? meaning,
    Object? example = _unset,
  }) {
    final touched = <EntryField>{
      if (headword != null) EntryField.headword,
      if (readings != null) EntryField.readings,
      if (!identical(pos, _unset)) EntryField.pos,
      if (meaning != null) EntryField.meaning,
      if (!identical(example, _unset)) EntryField.example,
    };
    return copyWith(
      headword: headword,
      readings: readings,
      pos: pos,
      meaning: meaning,
      example: example,
      issues: [
        for (final i in issues)
          if (!touched.contains(i.field)) i,
      ],
      evidence: evidence?.checked(touched),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CapturedEntry &&
      other.no == no &&
      other.headword == headword &&
      listEquals(other.readings, readings) &&
      other.pos == pos &&
      other.meaning == meaning &&
      other.example == example &&
      listEquals(other.issues, issues) &&
      listEquals(other.headwordCandidates, headwordCandidates) &&
      other.included == included &&
      other.ocrHeadword == ocrHeadword &&
      other.evidence == evidence;

  @override
  int get hashCode => Object.hash(
    no,
    headword,
    Object.hashAll(readings),
    pos,
    meaning,
    example,
    Object.hashAll(issues),
    Object.hashAll(headwordCandidates),
    included,
    ocrHeadword,
    evidence,
  );

  @override
  String toString() =>
      'CapturedEntry($no $headword|${readings.join('/')}|${pos?.badge}|$meaning'
      ' issues=$issues)';
}
