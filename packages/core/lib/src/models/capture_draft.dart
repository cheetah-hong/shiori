import 'package:shiori_core/src/extract/fragment.dart';
import 'package:shiori_core/src/models/capture_route.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/column_scale.dart';
import 'package:shiori_core/src/models/list_equality.dart';

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
    this.route,
    this.unpaired = const [],
    this.skippedKnown = const [],
  });

  /// Id of the `TextbookTemplate` that parsed the page.
  final String templateId;
  final PageMeta meta;
  final List<CapturedEntry> entries;
  final Duration recognitionTime;

  /// How the template scaled the page's columns; null when it did not measure
  /// them. A default scale means the columns may sit off on this page.
  final ColumnScale? columnScale;

  /// Which way the page was read and why; null when no router chose.
  final RouteDecision? route;

  /// Text on the page nothing paired with (general extractor only), for the
  /// learner to place by hand.
  final List<Fragment> unpaired;

  /// Headwords left out because the learner already has them.
  final List<String> skippedKnown;

  /// The general extractor read the page.
  bool get isGeneral => route?.route == CaptureRoute.general;

  int get needsReviewCount => entries.where((e) => e.needsReview).length;
  int get correctedCount => entries.where((e) => e.wasCorrected).length;
  int get includedCount => entries.where((e) => e.included).length;

  CaptureDraft copyWith({
    PageMeta? meta,
    List<CapturedEntry>? entries,
    RouteDecision? route,
    List<Fragment>? unpaired,
  }) => CaptureDraft(
    templateId: templateId,
    meta: meta ?? this.meta,
    entries: List.unmodifiable(entries ?? this.entries),
    recognitionTime: recognitionTime,
    columnScale: columnScale,
    route: route ?? this.route,
    unpaired: List.unmodifiable(unpaired ?? this.unpaired),
    skippedKnown: skippedKnown,
  );

  @override
  bool operator ==(Object other) {
    if (other is! CaptureDraft ||
        other.templateId != templateId ||
        other.meta != meta ||
        other.recognitionTime != recognitionTime ||
        other.columnScale != columnScale ||
        other.route != route ||
        !listEquals(other.unpaired.map((f) => f.id).toList(), [
          for (final f in unpaired) f.id,
        ]) ||
        !listEquals(other.skippedKnown, skippedKnown) ||
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
    route,
    Object.hashAll(skippedKnown),
    Object.hashAll(entries),
  );

  /// Returns a new draft with the entry at [index] replaced.
  CaptureDraft replaceEntry(int index, CapturedEntry entry) => copyWith(
    entries: [...entries.take(index), entry, ...entries.skip(index + 1)],
  );
}
