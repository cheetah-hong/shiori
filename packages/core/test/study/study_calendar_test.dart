import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  const calendar = StudyCalendar(dayStartHour: 4);

  test('before the day start hour still counts as the previous study day', () {
    expect(
      calendar.studyDayOf(DateTime(2026, 11, 5, 0, 25)),
      DateTime(2026, 11, 4),
    );
    expect(
      calendar.studyDayOf(DateTime(2026, 11, 5, 3, 59)),
      DateTime(2026, 11, 4),
    );
    expect(
      calendar.studyDayOf(DateTime(2026, 11, 5, 4)),
      DateTime(2026, 11, 5),
    );
  });

  test('start of the study day', () {
    expect(
      calendar.startOfStudyDay(DateTime(2026, 11, 5, 1)),
      DateTime(2026, 11, 4, 4),
    );
    expect(
      calendar.startOfStudyDay(DateTime(2026, 11, 5, 21)),
      DateTime(2026, 11, 5, 4),
    );
  });

  test('midnight boundary when the start hour is 0', () {
    const midnight = StudyCalendar(dayStartHour: 0);
    expect(
      midnight.studyDayOf(DateTime(2026, 11, 5, 0, 1)),
      DateTime(2026, 11, 5),
    );
  });

  test('month, year and UTC boundaries', () {
    expect(
      calendar.studyDayOf(DateTime(2026, 11, 1, 2)),
      DateTime(2026, 10, 31),
    );
    expect(
      calendar.studyDayOf(DateTime(2027, 1, 1, 2)),
      DateTime(2026, 12, 31),
    );
    expect(
      calendar.studyDayOf(DateTime.utc(2026, 3, 1, 3)),
      DateTime.utc(2026, 2, 28),
    );
    expect(
      calendar.startOfStudyDay(DateTime.utc(2026, 3, 1, 3)),
      DateTime.utc(2026, 2, 28, 4),
    );
  });

  test('rejects hours outside 0..23', () {
    expect(() => StudyCalendar.checked(24), throwsArgumentError);
  });
}
