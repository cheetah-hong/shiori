/// Words for studying learned words again, kept in one place so the screens
/// say the same thing.
///
/// 더 학습하기 studies cards whose review time has not come; 처음부터 다시 학습
/// makes a word new again (its memory level goes, its press log stays).
abstract final class RestudyLabels {
  /// The button that starts a session of cards brought forward, and that
  /// session's header.
  static const String more = '더 학습하기';

  /// Under the 더 학습하기 button where today's study button would be off.
  static const String moreHint = '복습할 때가 된 단어는 없어요. 기억 단계가 낮은 단어부터 미리 학습해요';

  /// A word's menu item.
  static const String resetWord = '처음부터 다시 학습';

  static String wordReset(String headword) => '「$headword」 새 단어로 돌렸어요';

  static const String resetFailed = '돌리지 못했어요. 다시 시도해 주세요';

  static const String undoFailed = '되돌리지 못했어요. 다시 시도해 주세요';

  /// 설정's row that makes every word new again.
  static const String resetAll = '모든 단어 처음부터 다시 학습';

  static const String resetAllHint = '기억 단계를 모두 지워요. 지난 학습 기록은 남아요';

  static const String nothingLearned = '아직 학습한 단어가 없어요';

  static const String resetAllQuestion = '모든 단어를 처음부터 다시 학습할까요?';

  static String resetAllDetail(int count) =>
      '학습한 단어 $count개가 모두 새 단어가 돼요. '
      '숨긴 단어와 재생목록, 지난 학습 기록은 그대로예요. 되돌릴 수 없어요.';

  static const String resetAllConfirm = '처음부터';

  static String allReset(int count) => '단어 $count개를 새 단어로 돌렸어요';

  static const String resetAllFailed = '초기화하지 못했어요. 다시 시도해 주세요';
}
