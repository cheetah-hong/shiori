/// Read models shared by screens. They refresh when [dataRevisionProvider] is bumped
/// after a save or an answer.
library;

import 'package:flutter/foundation.dart';
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

/// The ways of studying that can be picked now (more words or speech can
/// open 객관식 and 듣고 맞히기).
final availableModesProvider = FutureProvider<Set<StudyMode>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref
      .watch(studyServiceProvider)
      .availableModes(speechAvailable: ref.watch(speechProvider).isAvailable);
});

/// The way of studying in use: the one picked last, or 뜻 맞히기 while that
/// one cannot be studied (the stored choice is kept for later). 뜻 맞히기
/// too when the options cannot be read.
final studyModeProvider = FutureProvider<StudyMode>((ref) {
  ref.watch(dataRevisionProvider);
  return _modeInUse(ref);
});

/// Reads what [studyModeProvider] says straight from the blocks, so the
/// summaries below do not wait on another provider that a save also
/// refreshes. Every watch comes before the first await.
Future<StudyMode> _modeInUse(Ref ref) async {
  final stored = ref.watch(studyPreferencesProvider.future);
  final service = ref.watch(studyServiceProvider);
  final speech = ref.watch(speechProvider).isAvailable;
  try {
    final mode = (await stored).mode;
    final available = await service.availableModes(speechAvailable: speech);
    return available.contains(mode) ? mode : StudyMode.meaning;
  } on Exception catch (e, stack) {
    debugPrint('study mode: $e\n$stack');
    return StudyMode.meaning;
  }
}

/// Remembers [mode] as the way of studying (홈·재생목록 chips).
Future<void> saveStudyMode(WidgetRef ref, StudyMode mode) async {
  final repository = ref.read(studyPreferencesRepositoryProvider);
  final stored = await repository.load();
  await repository.save(stored.copyWith(mode: mode));
  ref.invalidate(studyPreferencesProvider);
}

/// 전체: due reviews and new words of every playlist, in the mode in use.
final homeSummaryProvider = FutureProvider<StudySummary>((ref) async {
  ref.watch(dataRevisionProvider);
  final service = ref.watch(studyServiceProvider);
  return service.summary(mode: await _modeInUse(ref));
});

/// Every playlist with its word counts, in one storage read, in the order
/// the learner gave them.
final playlistsProvider = FutureProvider<List<PlaylistStats>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(libraryRepositoryProvider).playlistStats();
});

/// Due reviews and new words of one playlist in the mode in use (its study
/// button, the study scope sheet).
final playlistSummaryProvider = FutureProvider.family<StudySummary, String>((
  ref,
  id,
) async {
  ref.watch(dataRevisionProvider);
  final service = ref.watch(studyServiceProvider);
  return service.summary(scope: PlaylistOnly(id), mode: await _modeInUse(ref));
});

final playlistViewProvider = FutureProvider.family<PlaylistView, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(libraryServiceProvider).playlistView(id);
});

/// Every mode's cards, by mode (memory meters, 처음부터 다시 학습).
final cardsByModeProvider =
    FutureProvider<Map<StudyMode, Map<String, ReviewCard>>>((ref) {
      ref.watch(dataRevisionProvider);
      return ref.watch(studyServiceProvider).cardsByMode();
    });

/// Tries storage again after a load error: a new database connection (an
/// older file that failed to be emptied is tried again), then every read.
void retryStorage(WidgetRef ref) {
  ref.invalidate(appDatabaseProvider);
  ref.read(dataRevisionProvider.notifier).bump();
}
