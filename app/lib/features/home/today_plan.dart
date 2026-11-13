import 'package:shiori/features/study/restudy_labels.dart';
import 'package:shiori_core/shiori_core.dart';

/// What 홈 says about today's session: how the daily goal is filled,
/// reviews first and then new words. Display only; the session itself is
/// built by the study service with the same [SessionSize].
final class TodayPlan {
  const TodayPlan._({
    required this.due,
    required this.fresh,
    required this.cards,
    required this.moreCards,
    required this.wordCount,
  });

  factory TodayPlan.of(StudySummary summary, SessionSize size) {
    final due = summary.dueCount;
    final fresh = summary.newCount;
    return TodayPlan._(
      due: due,
      fresh: fresh,
      cards: size.of(due + fresh),
      moreCards: size.of(summary.aheadCount),
      wordCount: summary.wordCount,
    );
  }

  /// Reviews due now.
  final int due;

  /// Every new word that could be studied.
  final int fresh;

  /// Cards in today's session (오늘 학습 시작 · n장).
  final int cards;

  /// Cards brought forward by 더 학습하기.
  final int moreCards;

  /// Words in the library (0 before the first page).
  final int wordCount;

  bool get canStudy => cards > 0;

  /// Nothing for today, but cards whose review time has not come.
  bool get canStudyMore => !canStudy && moreCards > 0;

  /// New words that make it into today's session, after the reviews.
  int get freshToday {
    final left = cards - due;
    if (left <= 0) return 0;
    return left < fresh ? left : fresh;
  }

  /// 「13개 중」 before today's new words when not all of them fit.
  String? get freshOutOf => freshToday < fresh ? '$fresh개 중 ' : null;

  /// The line under the memo rows: what 더 학습하기 brings forward. Null
  /// otherwise (the rows say what today holds).
  String? line() => canStudyMore ? RestudyLabels.moreHint(moreCards) : null;
}
