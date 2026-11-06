import 'package:shiori_core/src/extract/fragment.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/list_equality.dart';

/// The review draft for one captured page.
final class CaptureDraft {
  const CaptureDraft({
    required this.entries,
    this.recognitionTime = Duration.zero,
    this.unpaired = const [],
    this.skippedKnown = const [],
  });

  /// The page's words, in the order the photo shows them.
  final List<CapturedEntry> entries;
  final Duration recognitionTime;

  /// Text on the page nothing paired with, for the learner to place by
  /// hand.
  final List<Fragment> unpaired;

  /// Headwords left out because the learner already has them.
  final List<String> skippedKnown;

  int get needsReviewCount => entries.where((e) => e.needsReview).length;
  int get correctedCount => entries.where((e) => e.wasCorrected).length;
  int get includedCount => entries.where((e) => e.included).length;

  CaptureDraft copyWith({
    List<CapturedEntry>? entries,
    List<Fragment>? unpaired,
  }) => CaptureDraft(
    entries: List.unmodifiable(entries ?? this.entries),
    recognitionTime: recognitionTime,
    unpaired: List.unmodifiable(unpaired ?? this.unpaired),
    skippedKnown: skippedKnown,
  );

  @override
  bool operator ==(Object other) {
    if (other is! CaptureDraft ||
        other.recognitionTime != recognitionTime ||
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
    recognitionTime,
    Object.hashAll(skippedKnown),
    Object.hashAll(entries),
  );

  /// Returns a new draft with the entry at [index] replaced.
  CaptureDraft replaceEntry(int index, CapturedEntry entry) => copyWith(
    entries: [...entries.take(index), entry, ...entries.skip(index + 1)],
  );
}
