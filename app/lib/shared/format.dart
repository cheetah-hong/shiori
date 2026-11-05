import 'package:shiori_core/shiori_core.dart';

const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// `11월 5일 수요일`
String dateHeading(DateTime d) =>
    '${d.month}월 ${d.day}일 ${_weekdays[d.weekday - 1]}요일';

/// Label for the 알고있음 button: `30분 후`, `3일 후`.
String intervalLabel(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes}분 후';
  if (d.inHours < 24) return '${d.inHours}시간 후';
  return '${d.inDays}일 후';
}

/// `2분 17초`
/// Negative durations (the clock moved back) read as `0초`.
String elapsedLabel(Duration d) {
  final safe = d.isNegative ? Duration.zero : d;
  final m = safe.inMinutes;
  final s = safe.inSeconds % 60;
  return m == 0 ? '$s초' : '$m분 $s초';
}

/// `DAY 01`
String dayNumber(int day) => 'DAY ${day.toString().padLeft(2, '0')}';

/// `DAY 01 자연, 몸 · 10쪽`, leaving out what is unknown.
String pageMetaLabel(PageMeta meta) {
  final day = meta.day;
  final title = meta.title;
  final page = meta.page;
  final parts = [
    if (day != null)
      [dayNumber(day), if (title != null && title.isNotEmpty) title].join(' '),
    if (page != null) '$page쪽',
  ];
  return parts.isEmpty ? '쪽 정보 없음' : parts.join(' · ');
}

/// `DAY 01 · 12쪽` for a saved word.
String wordSourceLabel(Word w) {
  final day = w.day;
  final page = w.page;
  final parts = [if (day != null) dayNumber(day), if (page != null) '$page쪽'];
  return parts.join(' · ');
}

String readingsLabel(List<String> readings) =>
    readings.isEmpty ? '–' : readings.join(' / ');
