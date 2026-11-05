import 'dart:math' as math;

import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/ports/review_scheduler.dart';
import 'package:shiori_core/src/study/study_settings.dart';

/// Four memory levels with fixed intervals (30 min, 3 d, 7 d, 21 d by default).
///
/// New words: known at once → top level; after one 다시 학습 → level 2;
/// after two or more → level 1.
/// Review cards: known → one level up; after one 다시 학습 → at most level 2;
/// after two or more → level 1.
final class LeitnerFourStepScheduler implements ReviewScheduler {
  /// Use [LeitnerFourStepScheduler.checked] for intervals that are not constants.
  const LeitnerFourStepScheduler({
    this.intervals = StudySettings.defaultIntervals,
  });

  factory LeitnerFourStepScheduler.checked(List<Duration> intervals) {
    if (intervals.isEmpty) {
      throw ArgumentError.value(
        intervals,
        'intervals',
        'needs at least one level',
      );
    }
    return LeitnerFourStepScheduler(intervals: List.unmodifiable(intervals));
  }

  /// Interval for level `i + 1`.
  final List<Duration> intervals;

  /// Highest level reachable after a single 다시 학습.
  static const int _capAfterOneRetry = 2;

  @override
  int get maxLevel => intervals.length;

  int _levelAfterKnown(ReviewCard? before, int retries) {
    if (retries >= 2) return 1;
    if (before == null) {
      return retries == 0 ? maxLevel : math.min(_capAfterOneRetry, maxLevel);
    }
    final level = retries == 0
        ? before.level + 1
        : math.min(before.level, _capAfterOneRetry);
    return level.clamp(1, maxLevel);
  }

  @override
  ReviewCard known({
    required String wordId,
    required ReviewCard? before,
    required int retries,
    required DateTime now,
  }) {
    final level = _levelAfterKnown(before, retries);
    return ReviewCard(
      wordId: wordId,
      level: level,
      dueAt: now.add(intervals[level - 1]),
      lastReviewedAt: now,
      reviewCount: (before?.reviewCount ?? 0) + 1,
      lapseCount: (before?.lapseCount ?? 0) + retries,
    );
  }

  @override
  ReviewCard retry({
    required String wordId,
    required ReviewCard? current,
    required DateTime now,
  }) => ReviewCard(
    wordId: wordId,
    level: 1,
    dueAt: now,
    lastReviewedAt: now,
    reviewCount: current?.reviewCount ?? 0,
    lapseCount: (current?.lapseCount ?? 0) + 1,
  );

  @override
  Duration previewKnown({required ReviewCard? before, required int retries}) =>
      intervals[_levelAfterKnown(before, retries) - 1];
}
