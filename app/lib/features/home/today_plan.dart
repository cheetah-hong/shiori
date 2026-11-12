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

  /// 「· 13개 중」 after today's new words when not all of them fit.
  String? get freshOutOf => freshToday < fresh ? ' · $fresh개 중' : null;

  /// The line under the memo rows: how today's cards add up, or what
  /// 더 학습하기 brings forward. Null when there is nothing to study.
  String? line({required bool shuffle}) {
    if (canStudyMore) return RestudyLabels.moreHint(moreCards);
    if (!canStudy) return null;
    final sum = due >= cards
        ? '복습 $cards장 — 오늘 $cards장.'
        : due == 0
        ? '새 단어 $cards장 — 오늘 $cards장.'
        : '복습 $due장을 먼저, 남은 ${cards - due}장은 새 단어로 — 오늘 $cards장.';
    return shuffle ? '$sum 순서는 섞어서 보여요.' : sum;
  }
}
