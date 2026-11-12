// The 홈 week strip: Monday-first days of the study week, which had an
// answer, and the run of study days. Study days start at 04:00.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

const _calendar = StudyCalendar(dayStartHour: 4);

/// Thursday 12 November 2026, 21:00.
final _now = DateTime(2026, 11, 12, 21);

DateTime _at(int day, [int hour = 10]) => DateTime(2026, 11, day, hour);

void main() {
  test('Monday to Sunday of the week holding today', () {
    final week = studyWeekOf(const [], now: _now, calendar: _calendar);
    expect(
      [for (final d in week.days) d.date.day],
      [9, 10, 11, 12, 13, 14, 15],
    );
    expect([for (final d in week.days) d.date.weekday], [1, 2, 3, 4, 5, 6, 7]);
    expect(
      [for (final d in week.days) d.isToday],
      [false, false, false, true, false, false, false],
    );
    expect(
      [for (final d in week.days) d.isFuture],
      [false, false, false, false, true, true, true],
    );
  });

  test('no answers: nothing studied, no streak', () {
    final week = studyWeekOf(const [], now: _now, calendar: _calendar);
    expect(week.studiedThisWeek, 0);
    expect(week.streak, 0);
  });

  test('a streak not yet extended today still counts until the day ends', () {
    final week = studyWeekOf(
      [_at(9), _at(10), _at(11), _at(11, 15)],
      now: _now,
      calendar: _calendar,
    );
    expect(
      [for (final d in week.days) d.studied],
      [true, true, true, false, false, false, false],
    );
    expect(week.studiedThisWeek, 3);
    expect(week.streak, 3);
  });

  test('studying today extends the streak', () {
    final week = studyWeekOf(
      [_at(10), _at(11), _at(12, 8)],
      now: _now,
      calendar: _calendar,
    );
    expect(week.streak, 3);
    expect(week.days[3].studied, isTrue);
  });

  test('a missed day breaks the streak', () {
    final week = studyWeekOf(
      [_at(9), _at(11), _at(12)],
      now: _now,
      calendar: _calendar,
    );
    expect(week.streak, 2);
    expect(week.studiedThisWeek, 3);
  });

  test('an answer before 04:00 belongs to the day before', () {
    // 02:00 on Thursday is Wednesday's study day.
    final week = studyWeekOf([_at(12, 2)], now: _now, calendar: _calendar);
    expect(week.days[2].studied, isTrue, reason: 'Wednesday');
    expect(week.days[3].studied, isFalse, reason: 'Thursday');
    expect(week.streak, 1);
  });

  test('at 01:00 on Friday it is still Thursday', () {
    final week = studyWeekOf(
      [_at(12, 20)],
      now: DateTime(2026, 11, 13, 1),
      calendar: _calendar,
    );
    expect(week.days.singleWhere((d) => d.isToday).date.day, 12);
    expect(week.streak, 1);
  });

  test('the streak runs back across weeks and months', () {
    final answers = [
      for (var d = 0; d < 20; d++) DateTime(2026, 10, 24 + d, 9),
    ];
    final week = studyWeekOf(answers, now: _now, calendar: _calendar);
    // 24 October .. 12 November is 20 days.
    expect(week.streak, 20);
    expect(week.studiedThisWeek, 4);
  });

  test('on Sunday the strip is the week that ends today', () {
    final week = studyWeekOf(
      const [],
      now: DateTime(2026, 11, 15, 12),
      calendar: _calendar,
    );
    expect(week.days.first.date.day, 9);
    expect(week.days.last.isToday, isTrue);
  });
}
