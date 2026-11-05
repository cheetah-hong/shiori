/// Words for hiding a word the learner already knows, kept in one place so
/// the button can be renamed without touching the screens.
///
/// Not to be confused with 알고있음, the answer button that schedules the
/// next review: hiding takes the word out of study and the lists until it
/// is shown again, and keeps its review state.
abstract final class HideLabels {
  /// The study card's hide button.
  static const String button = '이미 알아요';

  /// What the hide button does, for screen readers.
  static const String buttonSemantics = '$button: 이 단어를 숨기고 다음 카드로';

  /// Undo right after hiding.
  static const String undo = '되돌리기';

  /// Shown once a word is hidden.
  static String hidden(String headword) => '「$headword」 숨겼어요';

  /// Hiding one word in the textbook list (tooltip and screen readers).
  static String hideWord(String headword) => '$headword 숨기기 ($button)';

  /// Showing a hidden word again.
  static const String restore = '되살리기';

  static String restoreWord(String headword) => '$headword 되살리기';

  static String restored(String headword) => '「$headword」 다시 보여요';

  /// The textbook list's toggle for hidden words.
  static String showHidden(int count) => '숨긴 단어 $count개 보기';

  static const String collapseHidden = '숨긴 단어 접기';

  /// Next to word counts: `숨김 3개`.
  static String hiddenCount(int count) => '숨김 $count개';

  static const String hideFailed = '숨기지 못했어요. 다시 시도해 주세요';

  static const String restoreFailed = '되살리지 못했어요. 다시 시도해 주세요';
}
