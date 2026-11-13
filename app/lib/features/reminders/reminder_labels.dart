import 'package:shiori_core/shiori_core.dart';

/// The words of reminders, the offer after a session and 설정 › 알림.
abstract final class ReminderLabels {
  static const offerTitle = '복습 알림을 받을까요?';
  static String offerBody(ReminderTime time) =>
      '복습할 카드가 있는 날만 ${timeLabel(time)}에 한 번 알려요.';
  static const accept = '알림 받기';
  static const later = '나중에';
  static String turnedOn(ReminderTime time) =>
      '${timeLabel(time)}에 알릴게요 · 설정에서 바꿀 수 있어요';
  static const turnedOff = '알림이 꺼져 있어요 · 설정 › 알림에서 다시 켤 수 있어요';

  static const section = '알림';
  static const reminder = '복습 알림';
  static const reminderHint = '복습할 카드가 있는 날만 한 번 알려요';
  static const time = '시각';
  static const pickTime = '알림 시각';
  static const done = '완료';
  static const cancel = '취소';
  static const deniedNote = 'iOS 설정에서 시오리 알림이 꺼져 있어요';
  static const deniedNoteOther = '기기 설정에서 시오리 알림이 꺼져 있어요';
  static const openSettings = 'iOS 설정 열기';

  static const haptics = '햅틱';
  static const hapticsHint = '답할 때 가볍게 진동해요';

  static const swipeHint = '카드를 밀어서도 답할 수 있어요';

  /// 「오전 8:00」, 「오후 9:30」, noon 「오후 12:00」, midnight 「오전 12:00」.
  static String timeLabel(ReminderTime time) {
    final half = time.hour < 12 ? '오전' : '오후';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$half $hour:${'${time.minute}'.padLeft(2, '0')}';
  }
}
