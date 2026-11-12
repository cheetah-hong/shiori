import 'package:shiori_core/shiori_core.dart';

/// Words for the four ways of studying, kept in one place so the screens
/// say the same thing.
abstract final class StudyModeLabels {
  /// The chip and header name of [mode].
  static String name(StudyMode mode) => switch (mode) {
    StudyMode.meaning => '뜻 맞히기',
    StudyMode.recall => '일본어 떠올리기',
    StudyMode.listening => '듣고 맞히기',
    StudyMode.choice => '객관식',
  };

  /// Why [mode] cannot be picked now: no speech, or too few words.
  static String unavailable(StudyMode mode, {required bool speechAvailable}) =>
      mode == StudyMode.listening && !speechAvailable ? noSpeech : tooFewWords;

  static const String noSpeech = '발음을 들을 수 없어 고를 수 없어요';

  static const String tooFewWords = '뜻이 서로 다른 단어가 4개 이상 있어야 해요';

  /// The study screen's header: 「오늘 학습 · 객관식」.
  static String header(String what, StudyMode mode) => '$what · ${name(mode)}';

  static const String replay = '다시 듣기';
  static const String right = '맞았어요';
  static const String wrong = '틀렸어요';
  static const String answerMark = '정답';

  /// A wrong pick, said in words and not only in red.
  static const String pickMark = '내 선택';
  static const String next = '다음';
}
