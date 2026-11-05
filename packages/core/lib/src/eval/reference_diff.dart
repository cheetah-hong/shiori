/// Cell-by-cell comparison with the frozen reference parser's output.
///
/// The Dart parser has moved on from the reference (`tools/reference/parse_eval.py`,
/// dumped to `reference_output.json`). Every cell where the two differ must be
/// listed, with a reason, in `intended_differences.json` next to the fixtures,
/// so an unintended change cannot slip through as "the parser moved on".
library;

import 'package:shiori_core/src/capture/capture_pipeline.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/ocr.dart';

const Map<String, String> _templateIds = {
  'list': 'vocab.list',
  'entry': 'vocab.entry',
};

/// One cell where the Dart output differs from the reference output.
final class CellDifference {
  const CellDifference({
    required this.fixture,
    required this.no,
    required this.field,
    required this.reference,
    required this.dart,
    this.reason = '',
  });

  factory CellDifference.fromJson(Map<String, Object?> json) => CellDifference(
    fixture: json['fixture']! as String,
    no: json['no'] as String?,
    field: json['field']! as String,
    reference: json['reference'],
    dart: json['dart'],
    reason: json['reason'] as String? ?? '',
  );

  final String fixture;

  /// Word number, or null for page cells (`template`, `meta`).
  final String? no;
  final String field;
  final Object? reference;
  final Object? dart;

  /// Why the Dart parser differs here on purpose. Required in the list.
  final String reason;

  /// Same cell and same two values (the reason is not compared).
  bool sameAs(CellDifference other) =>
      other.fixture == fixture &&
      other.no == no &&
      other.field == field &&
      _jsonEquals(other.reference, reference) &&
      _jsonEquals(other.dart, dart);

  Map<String, Object?> toJson() => {
    'fixture': fixture,
    'no': no,
    'field': field,
    'reference': reference,
    'dart': dart,
    'reason': reason,
  };

  @override
  String toString() =>
      '$fixture #${no ?? '-'} $field: reference=$reference dart=$dart';
}

/// The reference output's entry for a cell-by-cell comparison.
typedef _Cells = Map<String, Object?>;

_Cells _cellsOfReference(Map<String, Object?> e) {
  final example = e['example'] as Map?;
  return {
    'headword': e['headword'],
    'readings': e['readings'],
    'pos': e['pos'],
    'meaning': e['meaning'],
    'important': e['important'],
    'example.ja': example?['ja'],
    'example.ko': example?['ko'],
    'issues': e['issues'],
  };
}

_Cells _cellsOfEntry(CapturedEntry e) => {
  'headword': e.headword,
  'readings': e.readings,
  'pos': e.pos?.badge,
  'meaning': e.meaning,
  'important': e.important,
  'example.ja': e.example?.ja,
  'example.ko': e.example?.ko,
  'issues': [for (final i in e.issues) i.code],
};

Map<String, Object?> _metaJson(PageMeta m) => {
  'day': m.day,
  'title': m.title,
  'page': m.page,
};

/// Every cell of every page in [reference] (`reference_output.json`) where the
/// pipeline's draft differs.
Future<List<CellDifference>> referenceDifferences({
  required Map<String, Object?> reference,
  required Future<OcrScan> Function(String fixture) loadScan,
  required CapturePipeline pipeline,
}) async {
  final out = <CellDifference>[];
  for (final page
      in (reference['pages']! as List).cast<Map<String, Object?>>()) {
    final fixture = page['fixture']! as String;
    final draft = await pipeline.fromScan(await loadScan(fixture));
    void cell(String? no, String field, Object? ref, Object? got) {
      if (!_jsonEquals(ref, got)) {
        out.add(
          CellDifference(
            fixture: fixture,
            no: no,
            field: field,
            reference: ref,
            dart: got,
          ),
        );
      }
    }

    cell(null, 'template', _templateIds[page['template']], draft.templateId);
    cell(null, 'meta', page['meta'], _metaJson(draft.meta));

    final wanted = (page['entries']! as List).cast<Map<String, Object?>>();
    final refByNo = _byNo(wanted, (e) => e['no'] as String?);
    final gotByNo = _byNo(draft.entries, (e) => e.no);
    for (final no in {...refByNo.keys, ...gotByNo.keys}) {
      final ref = refByNo[no];
      final got = gotByNo[no];
      if (ref == null || got == null) {
        cell(no, 'entry', ref != null, got != null);
        continue;
      }
      final refCells = _cellsOfReference(ref);
      final gotCells = _cellsOfEntry(got);
      for (final field in refCells.keys) {
        cell(no, field, refCells[field], gotCells[field]);
      }
    }
  }
  return out;
}

/// Entries by word number; a repeated number gets a `#2` suffix so that both
/// copies are compared.
Map<String?, T> _byNo<T>(Iterable<T> items, String? Function(T) no) {
  final out = <String?, T>{};
  for (final item in items) {
    var key = no(item);
    for (var k = 2; out.containsKey(key); k++) {
      key = '${no(item)}#$k';
    }
    out[key] = item;
  }
  return out;
}

/// Differences that are not in [intended], and listed ones that did not occur.
({List<CellDifference> unexpected, List<CellDifference> stale})
compareWithIntended(
  List<CellDifference> found,
  List<CellDifference> intended,
) => (
  unexpected: [
    for (final d in found)
      if (!intended.any(d.sameAs)) d,
  ],
  stale: [
    for (final d in intended)
      if (!found.any(d.sameAs)) d,
  ],
);

bool _jsonEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _jsonEquals(a[k], b[k]));
  }
  return a == b;
}
