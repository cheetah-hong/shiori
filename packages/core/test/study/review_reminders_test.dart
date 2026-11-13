// Review reminders (N1): one a day at the learner's time, saying how many
// review cards are due by then; none on a day with nothing due or on the
// study day already studied. Study days start at 04:00.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

const _calendar = StudyCalendar(dayStartHour: 4);

/// 08:00.
const _eight = ReminderTime(8 * 60);

/// Friday 13 November 2026, 10:00 (after today's 08:00).
final _now = DateTime(2026, 11, 13, 10);

List<PlannedReminder> _plan(
  Iterable<DateTime> due, {
  DateTime? now,
  ReminderTime time = _eight,
  DateTime? lastAnsweredAt,
  int days = 7,
}) => planReminders(
  dueTimes: due,
  now: now ?? _now,
  time: time,
  calendar: _calendar,
  lastAnsweredAt: lastAnsweredAt,
  days: days,
);

void main() {
  group('ReminderTime', () {
    test('hour and minute', () {
      const t = ReminderTime(21 * 60 + 30);
      expect((t.hour, t.minute), (21, 30));
      expect(ReminderTime.evening, const ReminderTime(1260));
    });

    test('a stored value outside the day is refused', () {
      expect(() => ReminderTime.checked(-1), throwsArgumentError);
      expect(() => ReminderTime.checked(1440), throwsArgumentError);
      expect(ReminderTime.checked(0).minutes, 0);
      expect(ReminderTime.checked(1439).minutes, 1439);
    });

    test('offered time: rounded down to the half hour', () {
      expect(
        ReminderTime.offeredAt(DateTime(2026, 11, 13, 8, 12)),
        const ReminderTime(8 * 60),
      );
      expect(
        ReminderTime.offeredAt(DateTime(2026, 11, 13, 19, 59)),
        const ReminderTime(19 * 60 + 30),
      );
      expect(
        ReminderTime.offeredAt(DateTime(2026, 11, 13, 13, 30)),
        const ReminderTime(13 * 60 + 30),
      );
    });

    test('offered time: kept between 07:00 and 22:00', () {
      expect(
        ReminderTime.offeredAt(DateTime(2026, 11, 13, 5, 40)),
        const ReminderTime(7 * 60),
      );
      expect(
        ReminderTime.offeredAt(DateTime(2026, 11, 13, 0, 20)),
        const ReminderTime(7 * 60),
      );
      expect(
        ReminderTime.offeredAt(DateTime(2026, 11, 13, 23, 50)),
        const ReminderTime(22 * 60),
      );
      expect(
        ReminderTime.offeredAt(DateTime(2026, 11, 13, 22, 10)),
        const ReminderTime(22 * 60),
      );
    });
  });

  group('planReminders', () {
    test(
      'the next seven days at the time, from tomorrow once today passed',
      () {
        final due = [DateTime(2026, 11, 1)];
        final plan = _plan(due);
        expect(
          [for (final r in plan) r.at],
          [for (var d = 14; d <= 20; d++) DateTime(2026, 11, d, 8)],
        );
        expect(plan.every((r) => r.dueCount == 1), isTrue);
      },
    );

    test('today too when its time has not come', () {
      final plan = _plan([
        DateTime(2026, 11, 1),
      ], now: DateTime(2026, 11, 13, 7, 59));
      expect(plan.first.at, DateTime(2026, 11, 13, 8));
      expect(plan.last.at, DateTime(2026, 11, 19, 8));
      expect(plan, hasLength(7));
    });

    test('a time exactly now has passed', () {
      final plan = _plan([
        DateTime(2026, 11, 1),
      ], now: DateTime(2026, 11, 13, 8));
      expect(plan.first.at, DateTime(2026, 11, 14, 8));
    });

    test('counts the cards due by each time, growing day by day', () {
      final plan = _plan([
        DateTime(2026, 11, 12, 9), // due already
        DateTime(2026, 11, 14, 8), // due exactly at the 14th's reminder
        DateTime(2026, 11, 14, 8, 0, 1), // a second late: the 15th
        DateTime(2026, 11, 17, 3),
        DateTime(2026, 12, 30), // after the week
      ]);
      expect([for (final r in plan) r.dueCount], [2, 3, 3, 4, 4, 4, 4]);
    });

    test('a day with nothing due gets no reminder', () {
      final plan = _plan([DateTime(2026, 11, 16, 12)]);
      expect([for (final r in plan) r.at.day], [17, 18, 19, 20]);
      expect([for (final r in plan) r.dueCount], [1, 1, 1, 1]);
    });

    test('no cards: no reminders', () {
      expect(_plan(const []), isEmpty);
    });

    test('the study day already studied gets none', () {
      final plan = _plan(
        [DateTime(2026, 11, 1)],
        now: DateTime(2026, 11, 13, 6),
        lastAnsweredAt: DateTime(2026, 11, 13, 5),
      );
      expect(plan.first.at, DateTime(2026, 11, 14, 8));
      expect(plan, hasLength(6));
    });

    test('a press before 04:00 belongs to the day before', () {
      // 00:30 on the 13th is the 12th's study day: the 13th's 08:00 stays.
      final plan = _plan(
        [DateTime(2026, 11, 1)],
        now: DateTime(2026, 11, 13, 1),
        lastAnsweredAt: DateTime(2026, 11, 13, 0, 30),
      );
      expect(plan.first.at, DateTime(2026, 11, 13, 8));
    });

    test('a reminder time before 04:00 is in the study day before', () {
      // 02:00 on the 14th belongs to the 13th's study day, studied at 10:00.
      final plan = _plan(
        [DateTime(2026, 11, 1)],
        now: DateTime(2026, 11, 13, 11),
        time: const ReminderTime(2 * 60),
        lastAnsweredAt: DateTime(2026, 11, 13, 10),
      );
      expect(plan.first.at, DateTime(2026, 11, 15, 2));
    });

    test('a press on an earlier day does not drop today', () {
      final plan = _plan(
        [DateTime(2026, 11, 1)],
        now: DateTime(2026, 11, 13, 6),
        lastAnsweredAt: DateTime(2026, 11, 12, 20),
      );
      expect(plan.first.at, DateTime(2026, 11, 13, 8));
    });

    test('the month and the year turn over', () {
      final plan = _plan(
        [DateTime(2026, 12, 1)],
        now: DateTime(2026, 12, 29, 9),
        days: 4,
      );
      expect(
        [for (final r in plan) r.at],
        [
          DateTime(2026, 12, 30, 8),
          DateTime(2026, 12, 31, 8),
          DateTime(2027, 1, 1, 8),
          DateTime(2027, 1, 2, 8),
        ],
      );
    });

    test('a UTC clock plans in UTC', () {
      final plan = _plan(
        [DateTime.utc(2026, 11, 1)],
        now: DateTime.utc(2026, 11, 13, 10),
        time: const ReminderTime(21 * 60 + 15),
        days: 2,
      );
      expect(
        [for (final r in plan) r.at],
        [
          DateTime.utc(2026, 11, 13, 21, 15),
          DateTime.utc(2026, 11, 14, 21, 15),
        ],
      );
      expect(plan.every((r) => r.at.isUtc), isTrue);
    });

    test('local and UTC due times compare as instants', () {
      final local = DateTime(2026, 11, 14, 8);
      final plan = _plan([local.toUtc()], days: 2);
      expect([for (final r in plan) r.dueCount], [1, 1]);
    });

    test('days must be at least one', () {
      expect(() => _plan(const [], days: 0), throwsArgumentError);
    });
  });
}
