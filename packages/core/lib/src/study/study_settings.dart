/// Study settings kept apart from the logic so they can become user settings.
final class StudySettings {
  const StudySettings({
    this.intervals = defaultIntervals,
    this.dayStartHour = 4,
    this.dailyGoal = 10,
  }) : assert(dayStartHour >= 0 && dayStartHour < 24),
       assert(dailyGoal > 0);

  /// Validates values that do not come from constants (a settings screen).
  factory StudySettings.checked({
    List<Duration> intervals = defaultIntervals,
    int dayStartHour = 4,
    int dailyGoal = 10,
  }) {
    if (intervals.isEmpty || intervals.any((d) => d <= Duration.zero)) {
      throw ArgumentError.value(
        intervals,
        'intervals',
        'needs positive intervals',
      );
    }
    if (dayStartHour < 0 || dayStartHour > 23) {
      throw ArgumentError.value(dayStartHour, 'dayStartHour', 'must be 0..23');
    }
    if (dailyGoal < 1) {
      throw ArgumentError.value(dailyGoal, 'dailyGoal', 'must be at least 1');
    }
    return StudySettings(
      intervals: List.unmodifiable(intervals),
      dayStartHour: dayStartHour,
      dailyGoal: dailyGoal,
    );
  }

  /// Review interval per memory level: 30 minutes, 3 days, 7 days, 21 days.
  static const List<Duration> defaultIntervals = [
    Duration(minutes: 30),
    Duration(days: 3),
    Duration(days: 7),
    Duration(days: 21),
  ];

  final List<Duration> intervals;

  /// Hour (local time) when a new study day starts. Presses before it count
  /// toward the previous day (a session at 00:20 belongs to yesterday).
  final int dayStartHour;

  /// Cards per session: due reviews first, the rest new words.
  final int dailyGoal;
}
