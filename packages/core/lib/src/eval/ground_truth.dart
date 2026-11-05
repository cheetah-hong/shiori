import 'package:shiori_core/src/models/captured_entry.dart';

/// Hand-transcribed answers for the fixture pages (`ground_truth.json`).
final class GroundTruth {
  const GroundTruth(this.pages);

  factory GroundTruth.fromJson(Map<String, Object?> json) => GroundTruth([
    for (final p in _list(json['pages'])) GroundTruthPage.fromJson(p),
  ]);

  final List<GroundTruthPage> pages;
}

final class GroundTruthPage {
  const GroundTruthPage({
    required this.page,
    required this.fixture,
    required this.day,
    required this.title,
    required this.entries,
  });

  factory GroundTruthPage.fromJson(Map<String, Object?> json) =>
      GroundTruthPage(
        page: json['page']! as int,
        fixture: json['fixture']! as String,
        day: json['day'] as int?,
        title: json['title'] as String?,
        entries: [
          for (final e in _list(json['entries'])) GroundTruthEntry.fromJson(e),
        ],
      );

  final int page;
  final String fixture;
  final int? day;
  final String? title;
  final List<GroundTruthEntry> entries;
}

final class GroundTruthEntry {
  const GroundTruthEntry({
    required this.no,
    required this.headword,
    required this.readings,
    required this.pos,
    required this.meaning,
    this.example,
  });

  factory GroundTruthEntry.fromJson(Map<String, Object?> json) {
    final ex = json['example'];
    return GroundTruthEntry(
      no: json['no']! as String,
      headword: json['headword']! as String,
      readings: [for (final r in json['readings']! as List) r as String],
      pos: json['pos'] as String?,
      meaning: json['meaning']! as String,
      example: ex is Map
          ? Example(ja: ex['ja'] as String, ko: ex['ko'] as String)
          : null,
    );
  }

  final String no;
  final String headword;
  final List<String> readings;

  /// POS badge, for example `명`.
  final String? pos;
  final String meaning;

  /// Only entry-layout (N3) pages have examples.
  final Example? example;
}

List<Map<String, Object?>> _list(Object? v) => [
  for (final item in v! as List) (item as Map).cast<String, Object?>(),
];
