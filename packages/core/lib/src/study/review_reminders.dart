import 'package:shiori_core/src/study/study_calendar.dart';

/// The time of day a review reminder comes: minutes after midnight, local
/// time (0 to 1439).
final class ReminderTime {
  const ReminderTime(this.minutes) : assert(minutes >= 0 && minutes < 1440);

  /// Validates a value that does not come from a constant (a stored file).
  factory ReminderTime.checked(int minutes) {
    if (minutes < 0 || minutes >= _minutesPerDay) {
      throw ArgumentError.value(minutes, 'minutes', 'must be 0..1439');
    }
    return ReminderTime(minutes);
  }

  /// The time offered after the first session: [now] rounded down to the
  /// half hour, kept between 07:00 and 22:00.
  factory ReminderTime.offeredAt(DateTime now) {
    final halfHours = (now.hour * 60 + now.minute) ~/ 30 * 30;
    return ReminderTime(halfHours.clamp(_earliestOffer, _latestOffer));
  }

  /// 21:00, when reminders are turned on with no time picked before.
  static const ReminderTime evening = ReminderTime(21 * 60);

  final int minutes;

  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.minutes == minutes;

  @override
  int get hashCode => minutes.hashCode;

  @override
  String toString() =>
      'ReminderTime(${'$hour'.padLeft(2, '0')}:${'$minute'.padLeft(2, '0')})';
}

const int _minutesPerDay = 24 * 60;
const int _earliestOffer = 7 * 60;
const int _latestOffer = 22 * 60;

/// A reminder to put on the device: when it comes and how many review
/// cards are due by then.
final class PlannedReminder {
  const PlannedReminder({required this.at, required this.dueCount});

  final DateTime at;
  final int dueCount;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder && other.at == at && other.dueCount == dueCount;

  @override
  int get hashCode => Object.hash(at, dueCount);

  @override
  String toString() => 'PlannedReminder($at, $dueCount)';
}

/// The reminders of the next [days] times of day [time] after [now]: one a
/// day, saying how many of [dueTimes] (each card's next review) have come
/// by then.
///
/// A day whose count is 0 gets none, and neither does the study day of
/// [lastAnsweredAt] (the learner already studied that day; study days
/// follow [calendar]). The times are wall-clock times in [now]'s zone (UTC
/// when [now] is UTC), so a daylight-saving change keeps the hour.
///
/// A card's next review changes only when it is studied, so the counts stay
/// right while the app is closed; the app plans again whenever it could
/// have changed.
List<PlannedReminder> planReminders({
  required Iterable<DateTime> dueTimes,
  required DateTime now,
  required ReminderTime time,
  required StudyCalendar calendar,
  DateTime? lastAnsweredAt,
  int days = 7,
}) {
  if (days < 1) throw ArgumentError.value(days, 'days', 'must be at least 1');
  final due = dueTimes.toList()..sort();
  final studiedDay = lastAnsweredAt == null
      ? null
      : calendar.studyDayOf(lastAnsweredAt);
  final plan = <PlannedReminder>[];
  for (final at in _nextTimes(now, time, days)) {
    if (studiedDay != null && calendar.studyDayOf(at) == studiedDay) continue;
    final count = due.where((d) => !d.isAfter(at)).length;
    if (count > 0) plan.add(PlannedReminder(at: at, dueCount: count));
  }
  return List.unmodifiable(plan);
}

/// The next [days] times of day [time] after [now], in [now]'s zone.
Iterable<DateTime> _nextTimes(DateTime now, ReminderTime time, int days) sync* {
  var found = 0;
  for (var day = 0; found < days; day++) {
    final at = now.isUtc
        ? DateTime.utc(
            now.year,
            now.month,
            now.day + day,
            time.hour,
            time.minute,
          )
        : DateTime(now.year, now.month, now.day + day, time.hour, time.minute);
    if (!at.isAfter(now)) continue;
    found++;
    yield at;
  }
}
