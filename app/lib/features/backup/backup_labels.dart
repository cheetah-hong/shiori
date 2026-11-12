import 'package:shiori_core/shiori_core.dart';

/// The words of 설정 › 백업.
abstract final class BackupLabels {
  static const section = '백업';
  static const export = '백업 파일 만들기';
  static const exportHint = '단어·재생목록·학습 기록·설정을 파일 하나로 저장해요';
  static const restore = '백업에서 복원';
  static const restoreHint = '파일 앱에서 백업 파일을 골라 지금 데이터를 바꿔요';
  static const undo = '복원 전으로 되돌리기';
  static const leftOut = '사진·사전·목소리는 백업에 들어가지 않아요(앱에 같이 있어요).';

  static const exported = '백업 파일을 내보냈어요';
  static const exportFailed = '백업 파일을 만들지 못했어요. 다시 시도해 주세요';
  static const exportTooLarge = '백업이 너무 커서(64MB 넘음) 파일을 만들 수 없어요';

  static const checking = '백업 파일을 확인하는 중…';
  static const restoring = '복원하는 중…';
  static const undoing = '되돌리는 중…';

  static const restoreQuestion = '백업에서 복원할까요?';
  static const restoreReplaces = '지금 앱의 단어·재생목록·학습 기록·설정이 모두 이 백업 내용으로 바뀌어요.';
  static const restoreKeeps = '복원 전 데이터는 앱 안에 한 번 보관해 두어 되돌릴 수 있어요.';
  static const restoreConfirm = '복원';
  static const cancel = '취소';

  static const restoreFailed = '복원하지 못했어요';
  static const unchanged = '지금 데이터는 바뀌지 않았어요';
  static const notKept = '지금 데이터를 보관하지 못해 복원하지 않았어요';
  static const restoreBroke = '복원하는 중에 문제가 생겼어요';
  static const pickFailed = '파일을 열지 못했어요';
  static const ok = '확인';

  static const undoQuestion = '복원 전으로 되돌릴까요?';
  static const undoConfirm = '되돌리기';
  static const undone = '복원 전으로 되돌렸어요';
  static const undoFailed = '되돌리지 못했어요';

  /// What a file that cannot be restored says, by [problem].
  static String problem(BackupProblem problem) => switch (problem) {
    BackupProblem.empty || BackupProblem.notJson || BackupProblem.notBackup =>
      '시오리 백업 파일이 아니에요. 「백업 파일 만들기」로 만든 .json 파일을 골라 주세요',
    BackupProblem.tooLarge => '파일이 너무 커요(64MB 넘음). 시오리 백업 파일이 맞는지 확인해 주세요',
    BackupProblem.newerVersion =>
      '더 새 버전의 시오리에서 만든 백업이에요. 앱을 업데이트한 뒤 다시 복원해 주세요',
    BackupProblem.invalid ||
    BackupProblem.duplicate ||
    BackupProblem.danglingReference => '백업 파일이 손상되어 복원할 수 없어요',
  };

  /// `2026년 11월 5일 20:00에 만든 백업 · 시오리 1.0.0`
  static String madeBy(BackupSummary s) =>
      '${_date(s.createdAt, withYear: true)}에 만든 백업 · 시오리 ${s.appVersion}';

  /// `단어 3개 · 재생목록 1개 · 학습 기록 2건`
  static String counts(BackupSummary s) =>
      '단어 ${s.words}개 · 재생목록 ${s.playlists}개 · 학습 기록 ${s.presses}건';

  /// `복원했어요 · 단어 3개 · 재생목록 1개`
  static String restored(BackupSummary s) =>
      '복원했어요 · 단어 ${s.words}개 · 재생목록 ${s.playlists}개';

  /// `11월 5일 21:00 복원 직전 데이터`
  static String kept(DateTime at) => '${_date(at)} 복원 직전 데이터';

  /// `11월 5일 21:00 복원 직전 데이터로 바뀌어요`
  static String undoDetail(DateTime at) => '${kept(at)}로 바뀌어요';

  static String _date(DateTime at, {bool withYear = false}) {
    final t = at.toLocal();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    final day = '${t.month}월 ${t.day}일 $time';
    return withYear ? '${t.year}년 $day' : day;
  }
}
