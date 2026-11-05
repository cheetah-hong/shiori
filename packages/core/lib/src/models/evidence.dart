/// Where each cell of a review entry came from and how sure its pairing is.
///
/// The general word extractor fills this in; the review screen shows it.
/// It is never saved: a saved `Word` keeps only the cell values.
library;

import 'package:shiori_core/src/models/captured_entry.dart';

/// Where a field's value came from.
enum FieldSource {
  /// Read from the photo.
  photo('사진'),

  /// Filled in from the dictionary (the photo did not print it).
  dictionary('사전'),

  /// From a translation (not produced yet).
  translation('번역');

  const FieldSource(this.label);

  /// Name shown on the review screen.
  final String label;
}

/// How sure a pairing is, from independent content evidence:
/// two or more content signals agree → [high], one → [medium], position only → [low].
enum PairConfidence {
  low('낮음'),
  medium('중간'),
  high('높음');

  const PairConfidence(this.label);

  /// Name shown on the review screen.
  final String label;
}

/// How a word got on the list.
enum WordOrigin {
  /// Printed as a word (word list, word box, side column, heading).
  wordList,

  /// A dictionary form of a word inside a Japanese sentence.
  sentence,
}

/// A box on the upright page, normalized to 0..1 (as `OcrLine`).
final class PhotoBox {
  const PhotoBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;

  /// Nothing left to show (outside the page, or not a number).
  bool get isEmpty =>
      !(width > 0 && height > 0) ||
      !x.isFinite ||
      !y.isFinite ||
      !width.isFinite ||
      !height.isFinite;

  /// The part of the box on the page. A box with a value that is not a
  /// number becomes empty: OCR blocks are outside data.
  PhotoBox clamped() {
    if (![x, y, width, height].every((v) => v.isFinite)) {
      return const PhotoBox(x: 0, y: 0, width: 0, height: 0);
    }
    final x0 = x.clamp(0.0, 1.0);
    final y0 = y.clamp(0.0, 1.0);
    final x1 = (x + width).clamp(0.0, 1.0);
    final y1 = (y + height).clamp(0.0, 1.0);
    return PhotoBox(
      x: x0,
      y: y0,
      width: x1 > x0 ? x1 - x0 : 0,
      height: y1 > y0 ? y1 - y0 : 0,
    );
  }

  /// The smallest box holding this one and [other].
  PhotoBox union(PhotoBox other) {
    final x0 = x < other.x ? x : other.x;
    final y0 = y < other.y ? y : other.y;
    final x1 = right > other.right ? right : other.right;
    final y1 = bottom > other.bottom ? bottom : other.bottom;
    return PhotoBox(x: x0, y: y0, width: x1 - x0, height: y1 - y0);
  }

  @override
  bool operator ==(Object other) =>
      other is PhotoBox &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() =>
      'PhotoBox(${x.toStringAsFixed(3)},${y.toStringAsFixed(3)} '
      '${width.toStringAsFixed(3)}x${height.toStringAsFixed(3)})';
}

/// The evidence behind one cell.
final class FieldEvidence {
  const FieldEvidence({
    required this.source,
    this.confidence,
    this.boxes = const [],
    this.candidates = const [],
    this.note,
    this.checked = false,
    this.original,
  });

  final FieldSource source;

  /// How sure the pairing with the headword is; null for the headword itself
  /// (nothing to pair) and for cells with no value.
  final PairConfidence? confidence;

  /// Where on the page the value was read; empty when it came from the
  /// dictionary.
  final List<PhotoBox> boxes;

  /// Other values the learner may pick (dictionary senses, other readings).
  final List<String> candidates;

  /// Why the value is what it is (`人ロ → 人口 (글자 보정+사전)`).
  final String? note;

  /// The learner looked at the cell and set or kept its value.
  final bool checked;

  /// The cell as extracted, with its value, before the learner picked a
  /// candidate (so picking the extracted value again restores its source and
  /// boxes); null while nothing was picked.
  final ({String value, FieldEvidence evidence})? original;

  FieldEvidence copyWith({
    FieldSource? source,
    Object? confidence = _unset,
    List<PhotoBox>? boxes,
    List<String>? candidates,
    Object? note = _unset,
    bool? checked,
    Object? original = _unset,
  }) => FieldEvidence(
    source: source ?? this.source,
    confidence: identical(confidence, _unset)
        ? this.confidence
        : confidence as PairConfidence?,
    boxes: List.unmodifiable(boxes ?? this.boxes),
    candidates: List.unmodifiable(candidates ?? this.candidates),
    note: identical(note, _unset) ? this.note : note as String?,
    checked: checked ?? this.checked,
    original: identical(original, _unset)
        ? this.original
        : original as ({String value, FieldEvidence evidence})?,
  );

  @override
  bool operator ==(Object other) =>
      other is FieldEvidence &&
      other.source == source &&
      other.confidence == confidence &&
      _listEquals(other.boxes, boxes) &&
      _listEquals(other.candidates, candidates) &&
      other.note == note &&
      other.checked == checked &&
      other.original == original;

  @override
  int get hashCode => Object.hash(
    source,
    confidence,
    Object.hashAll(boxes),
    Object.hashAll(candidates),
    note,
    checked,
    original,
  );

  @override
  String toString() =>
      'FieldEvidence(${source.name} ${confidence?.name ?? '-'}'
      '${checked ? ' checked' : ''})';
}

/// The evidence behind a review entry from the general extractor.
final class EntryEvidence {
  const EntryEvidence({
    required this.origin,
    this.fields = const {},
    this.confirmed = false,
  });

  final WordOrigin origin;
  final Map<EntryField, FieldEvidence> fields;

  /// The learner approved the whole entry ("높음 전체 승인").
  final bool confirmed;

  FieldEvidence? of(EntryField field) => fields[field];

  /// The weakest pairing of the meaning and (when there is one) the reading.
  /// No meaning, or a cell with no pairing (one the learner set), counts as
  /// [PairConfidence.low]: an entry without a meaning is never high.
  PairConfidence get confidence {
    final reading = fields[EntryField.readings];
    final levels = [
      fields[EntryField.meaning]?.confidence ?? PairConfidence.low,
      if (reading != null) reading.confidence ?? PairConfidence.low,
    ];
    return levels.reduce((a, b) => a.index <= b.index ? a : b);
  }

  bool get isHigh => confidence == PairConfidence.high;

  EntryEvidence confirm() =>
      EntryEvidence(origin: origin, fields: fields, confirmed: true);

  EntryEvidence withField(EntryField field, FieldEvidence evidence) =>
      EntryEvidence(
        origin: origin,
        fields: Map.unmodifiable({...fields, field: evidence}),
        confirmed: confirmed,
      );

  /// [touched] cells marked as checked by the learner.
  EntryEvidence checked(Set<EntryField> touched) => EntryEvidence(
    origin: origin,
    fields: Map.unmodifiable({
      for (final MapEntry(:key, :value) in fields.entries)
        key: touched.contains(key) ? value.copyWith(checked: true) : value,
    }),
    confirmed: confirmed,
  );

  @override
  bool operator ==(Object other) {
    if (other is! EntryEvidence ||
        other.origin != origin ||
        other.confirmed != confirmed ||
        other.fields.length != fields.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in fields.entries) {
      if (other.fields[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    origin,
    confirmed,
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in fields.entries)
        Object.hash(key, value),
    ]),
  );

  @override
  String toString() =>
      'EntryEvidence(${origin.name} ${confidence.name}'
      '${confirmed ? ' confirmed' : ''})';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const Object _unset = Object();
