import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori_core/shiori_core.dart';

/// How far back the streak can see. Older answers are not read.
const streakHistory = Duration(days: 400);

/// 홈's week strip and run of study days, from the times cards were
/// answered (any mode, any playlist). Display only: nothing is stored.
final studyWeekProvider = FutureProvider<StudyWeek>((ref) async {
  ref.watch(dataRevisionProvider);
  final now = ref.watch(clockProvider).now();
  final logs = await ref
      .watch(reviewRepositoryProvider)
      .logs(since: now.subtract(streakHistory));
  return studyWeekOf(
    [for (final l in logs) l.at],
    now: now,
    calendar: StudyCalendar.checked(
      ref.watch(studySettingsProvider).dayStartHour,
    ),
  );
});
