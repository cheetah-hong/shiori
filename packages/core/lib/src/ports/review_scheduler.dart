import 'package:shiori_core/src/models/review.dart';

/// Block slot: decides the next level and review time of a card.
///
/// First block: `LeitnerFourStepScheduler` (four fixed intervals). Next: FSRS.
abstract interface class ReviewScheduler {
  /// Highest level; reaching it means 장기 기억.
  int get maxLevel;

  /// Card after 알고있음. [before] is the card at session start (null = new word)
  /// and [retries] how often 다시 학습 was pressed for it in this session.
  ReviewCard known({
    required String wordId,
    required ReviewCard? before,
    required int retries,
    required DateTime now,
  });

  /// Interim card after 다시 학습, so a session left half way keeps the word due.
  ReviewCard retry({
    required String wordId,
    required ReviewCard? current,
    required DateTime now,
  });

  /// Interval shown on the 알고있음 button ("21일 후").
  Duration previewKnown({required ReviewCard? before, required int retries});
}
