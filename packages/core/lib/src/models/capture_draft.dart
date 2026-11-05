import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/column_scale.dart';

/// Where a page sits in the textbook: `DAY 01 자연, 몸`, page 10.
final class PageMeta {
  const PageMeta({this.day, this.title, this.page});

  static const empty = PageMeta();

  final int? day;
  final String? title;
  final int? page;

  PageMeta copyWith({int? day, String? title, int? page}) => PageMeta(
    day: day ?? this.day,
    title: title ?? this.title,
    page: page ?? this.page,
  );

  @override
  bool operator ==(Object other) =>
      other is PageMeta &&
      other.day == day &&
      other.title == title &&
      other.page == page;

  @override
  int get hashCode => Object.hash(day, title, page);

  @override
  String toString() => 'PageMeta(day: $day, title: $title, page: $page)';
}

/// The review draft for one captured page.
final class CaptureDraft {
  const CaptureDraft({
    required this.templateId,
    required this.meta,
    required this.entries,
    this.recognitionTime = Duration.zero,
    this.columnScale,
  });

  /// Id of the `TextbookTemplate` that parsed the page.
  final String templateId;
  final PageMeta meta;
  final List<CapturedEntry> entries;
  final Duration recognitionTime;

  /// How the template scaled the page's columns; null when it did not measure
  /// them. A default scale means the columns may sit off on this page.
  final ColumnScale? columnScale;

  int get needsReviewCount => entries.where((e) => e.needsReview).length;
  int get correctedCount => entries.where((e) => e.wasCorrected).length;
  int get includedCount => entries.where((e) => e.included).length;

  CaptureDraft copyWith({PageMeta? meta, List<CapturedEntry>? entries}) =>
      CaptureDraft(
        templateId: templateId,
        meta: meta ?? this.meta,
        entries: List.unmodifiable(entries ?? this.entries),
        recognitionTime: recognitionTime,
        columnScale: columnScale,
      );

  @override
  bool operator ==(Object other) {
    if (other is! CaptureDraft ||
        other.templateId != templateId ||
        other.meta != meta ||
        other.recognitionTime != recognitionTime ||
        other.columnScale != columnScale ||
        other.entries.length != entries.length) {
      return false;
    }
    for (var i = 0; i < entries.length; i++) {
      if (other.entries[i] != entries[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    templateId,
    meta,
    recognitionTime,
    columnScale,
    Object.hashAll(entries),
  );

  /// Returns a new draft with the entry at [index] replaced.
  CaptureDraft replaceEntry(int index, CapturedEntry entry) => copyWith(
    entries: [...entries.take(index), entry, ...entries.skip(index + 1)],
  );
}
