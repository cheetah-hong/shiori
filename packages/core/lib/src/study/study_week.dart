import 'package:shiori_core/src/study/study_calendar.dart';

/// One day of the 홈 week strip.
final class WeekDay {
  const WeekDay({
    required this.date,
    required this.studied,
    required this.isToday,
    required this.isFuture,
  });

  /// Calendar date (00:00) of the study day.
  final DateTime date;

  /// At least one card was answered that day.
  final bool studied;
  final bool isToday;
  final bool isFuture;
}

/// The study week holding today, Monday first, and the run of study days.
final class StudyWeek {
  const StudyWeek({required this.days, required this.streak});

  /// Monday to Sunday.
  final List<WeekDay> days;

  /// Study days in a row ending today, or yesterday while today has none
  /// yet (a streak is not broken before the day is over).
  final int streak;

  /// Days of this week with at least one answer.
  int get studiedThisWeek => days.where((d) => d.studied).length;
}

/// Builds the week strip from the times cards were answered.
///
/// Days are study days of [calendar] (an answer at 02:00 with a 04:00 day
/// start counts for the day before). The streak only sees [answeredAt], so
/// a caller passes enough history for the longest streak it wants to show.
StudyWeek studyWeekOf(
  Iterable<DateTime> answeredAt, {
  required DateTime now,
  required StudyCalendar calendar,
}) {
  final studied = {for (final t in answeredAt) _key(calendar.studyDayOf(t))};
  final today = calendar.studyDayOf(now);
  final monday = _addDays(today, 1 - today.weekday);
  final days = [for (var i = 0; i < 7; i++) _addDays(monday, i)];
  var cursor = studied.contains(_key(today)) ? today : _addDays(today, -1);
  var streak = 0;
  while (studied.contains(_key(cursor))) {
    streak++;
    cursor = _addDays(cursor, -1);
  }
  return StudyWeek(
    days: [
      for (final d in days)
        WeekDay(
          date: d,
          studied: studied.contains(_key(d)),
          isToday: _key(d) == _key(today),
          isFuture: d.isAfter(today),
        ),
    ],
    streak: streak,
  );
}

/// Calendar arithmetic by date parts, so a 23- or 25-hour day never shifts
/// the date.
DateTime _addDays(DateTime d, int days) => d.isUtc
    ? DateTime.utc(d.year, d.month, d.day + days)
    : DateTime(d.year, d.month, d.day + days);

int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
