/// Maps instants to study days, which start at [dayStartHour] instead of midnight.
final class StudyCalendar {
  const StudyCalendar({required this.dayStartHour})
    : assert(dayStartHour >= 0 && dayStartHour < 24);

  factory StudyCalendar.checked(int dayStartHour) {
    if (dayStartHour < 0 || dayStartHour > 23) {
      throw ArgumentError.value(dayStartHour, 'dayStartHour', 'must be 0..23');
    }
    return StudyCalendar(dayStartHour: dayStartHour);
  }

  final int dayStartHour;

  /// Calendar date (at 00:00) of the study day [t] belongs to.
  DateTime studyDayOf(DateTime t) {
    final day = t.hour < dayStartHour ? t.day - 1 : t.day;
    return t.isUtc
        ? DateTime.utc(t.year, t.month, day)
        : DateTime(t.year, t.month, day);
  }

  /// The instant the study day containing [t] began.
  DateTime startOfStudyDay(DateTime t) {
    final d = studyDayOf(t);
    return t.isUtc
        ? DateTime.utc(d.year, d.month, d.day, dayStartHour)
        : DateTime(d.year, d.month, d.day, dayStartHour);
  }
}
