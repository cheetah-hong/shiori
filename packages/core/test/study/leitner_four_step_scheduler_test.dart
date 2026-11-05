import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 5, 21);
  const scheduler = LeitnerFourStepScheduler();

  ReviewCard card(int level) => ReviewCard(
    wordId: 'w',
    level: level,
    dueAt: now,
    lastReviewedAt: now.subtract(const Duration(days: 3)),
  );

  group('new word', () {
    test('known at first sight goes straight to level 4, 21 days', () {
      final c = scheduler.known(
        wordId: 'w',
        before: null,
        retries: 0,
        now: now,
      );
      expect(c.level, 4);
      expect(c.dueAt, now.add(const Duration(days: 21)));
      expect(c.lastReviewedAt, now);
      expect(c.reviewCount, 1);
    });

    test('known after one retry is level 2, 3 days', () {
      final c = scheduler.known(
        wordId: 'w',
        before: null,
        retries: 1,
        now: now,
      );
      expect((c.level, c.dueAt), (2, now.add(const Duration(days: 3))));
    });

    test('known after two or more retries is level 1, 30 minutes', () {
      for (final retries in [2, 3, 7]) {
        final c = scheduler.known(
          wordId: 'w',
          before: null,
          retries: retries,
          now: now,
        );
        expect(
          (c.level, c.dueAt),
          (1, now.add(const Duration(minutes: 30))),
          reason: '$retries retries',
        );
      }
    });
  });

  group('review card (Shiori rule)', () {
    test('known moves one level up, capped at 4', () {
      expect(
        scheduler
            .known(wordId: 'w', before: card(1), retries: 0, now: now)
            .level,
        2,
      );
      expect(
        scheduler
            .known(wordId: 'w', before: card(2), retries: 0, now: now)
            .level,
        3,
      );
      final top = scheduler.known(
        wordId: 'w',
        before: card(4),
        retries: 0,
        now: now,
      );
      expect((top.level, top.dueAt), (4, now.add(const Duration(days: 21))));
    });

    test('level 3 known waits 7 days', () {
      final c = scheduler.known(
        wordId: 'w',
        before: card(2),
        retries: 0,
        now: now,
      );
      expect(c.dueAt, now.add(const Duration(days: 7)));
    });

    test('one retry keeps at most level 2', () {
      expect(
        scheduler
            .known(wordId: 'w', before: card(4), retries: 1, now: now)
            .level,
        2,
      );
      expect(
        scheduler
            .known(wordId: 'w', before: card(3), retries: 1, now: now)
            .level,
        2,
      );
      expect(
        scheduler
            .known(wordId: 'w', before: card(1), retries: 1, now: now)
            .level,
        1,
      );
    });

    test('two or more retries drop to level 1', () {
      expect(
        scheduler
            .known(wordId: 'w', before: card(4), retries: 2, now: now)
            .level,
        1,
      );
    });

    test('counts reviews and keeps lapses from the card', () {
      final before = card(2).copyWith(reviewCount: 5, lapseCount: 2);
      final c = scheduler.known(
        wordId: 'w',
        before: before,
        retries: 0,
        now: now,
      );
      expect((c.reviewCount, c.lapseCount), (6, 2));
    });
  });

  test('retry makes the card due right away at level 1 and counts a lapse', () {
    final c = scheduler.retry(wordId: 'w', current: card(3), now: now);
    expect((c.level, c.dueAt, c.lapseCount), (1, now, 1));
    final fresh = scheduler.retry(wordId: 'w', current: null, now: now);
    expect(
      (fresh.level, fresh.dueAt, fresh.lapseCount, fresh.reviewCount),
      (1, now, 1, 0),
    );
  });

  test('preview shows the interval known would give', () {
    expect(
      scheduler.previewKnown(before: null, retries: 0),
      const Duration(days: 21),
    );
    expect(
      scheduler.previewKnown(before: null, retries: 1),
      const Duration(days: 3),
    );
    expect(
      scheduler.previewKnown(before: card(2), retries: 0),
      const Duration(days: 7),
    );
    expect(
      scheduler.previewKnown(before: card(2), retries: 2),
      const Duration(minutes: 30),
    );
  });

  test('intervals come from settings', () {
    const fast = LeitnerFourStepScheduler(
      intervals: [
        Duration(minutes: 1),
        Duration(minutes: 2),
        Duration(minutes: 3),
      ],
    );
    expect(fast.maxLevel, 3);
    final c = fast.known(wordId: 'w', before: null, retries: 0, now: now);
    expect((c.level, c.dueAt), (3, now.add(const Duration(minutes: 3))));
  });

  test('settings from a settings screen are validated', () {
    expect(() => StudySettings.checked(dailyGoal: 0), throwsArgumentError);
    expect(() => StudySettings.checked(dayStartHour: 24), throwsArgumentError);
    expect(
      () => StudySettings.checked(intervals: const []),
      throwsArgumentError,
    );
    expect(StudySettings.checked(dailyGoal: 15).dailyGoal, 15);
  });

  test('rejects an empty interval table', () {
    expect(
      () => LeitnerFourStepScheduler.checked(const []),
      throwsArgumentError,
    );
  });
}
