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

/// 전체: due reviews and new words of every playlist.
final homeSummaryProvider = FutureProvider<StudySummary>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(studyServiceProvider).summary();
});

/// Every playlist with its word counts, in one storage read, in the order
/// the learner gave them.
final playlistsProvider = FutureProvider<List<PlaylistStats>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(libraryRepositoryProvider).playlistStats();
});

/// Due reviews and new words of one playlist (its study button, the study
/// scope sheet).
final playlistSummaryProvider = FutureProvider.family<StudySummary, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(studyServiceProvider).summary(scope: PlaylistOnly(id));
});

final playlistViewProvider = FutureProvider.family<PlaylistView, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(libraryServiceProvider).playlistView(id);
});

final cardsProvider = FutureProvider<Map<String, ReviewCard>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(reviewRepositoryProvider).cards();
});

/// Tries storage again after a load error: a new database connection (an
/// older file that failed to be emptied is tried again), then every read.
void retryStorage(WidgetRef ref) {
  ref.invalidate(appDatabaseProvider);
  ref.read(dataRevisionProvider.notifier).bump();
}
