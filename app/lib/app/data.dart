/// Read models shared by screens. They refresh when [dataRevisionProvider] is bumped
/// after a save or an answer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';

final class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataRevisionProvider = NotifierProvider<DataRevision, int>(
  DataRevision.new,
);

final homeSummaryProvider = FutureProvider<StudySummary>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(studyServiceProvider).summary();
});

final class ShelfItem {
  const ShelfItem({
    required this.textbook,
    required this.wordCount,
    required this.days,
  });

  final Textbook textbook;
  final int wordCount;
  final List<int> days;
}

/// Every textbook with its word count and days, in one storage read.
final shelfProvider = FutureProvider<List<ShelfItem>>((ref) async {
  ref.watch(dataRevisionProvider);
  final stats = await ref.watch(libraryRepositoryProvider).textbookStats();
  return [
    for (final s in stats)
      ShelfItem(textbook: s.textbook, wordCount: s.wordCount, days: s.days),
  ];
});

/// Due reviews and new words of one textbook (for its study button).
final textbookSummaryProvider = FutureProvider.family<StudySummary, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(studyServiceProvider).summary(textbookId: id);
});

final textbookOverviewProvider =
    FutureProvider.family<TextbookOverview, String>((ref, id) {
      ref.watch(dataRevisionProvider);
      return ref.watch(libraryServiceProvider).overview(id);
    });

final cardsProvider = FutureProvider<Map<String, ReviewCard>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(reviewRepositoryProvider).cards();
});
