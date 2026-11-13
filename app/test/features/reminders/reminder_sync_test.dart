// N2: the reminders are planned again after the first frame, when the app
// comes back or goes to the back, after the data changed and when the
// settings change; turned off, every reminder is taken off.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/reminder_sync.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori_core/shiori_core.dart';

import '../../support/harness.dart';

const _eight = ReminderTime(8 * 60);

final _onSettings = NudgeSettings(
  remindersOn: true,
  reminderTime: _eight,
  offered: true,
);

List<PlannedReminder> _two(ReminderTime time) => [
  PlannedReminder(
    at: DateTime(2026, 11, 6, time.hour, time.minute),
    dueCount: 3,
  ),
  PlannedReminder(
    at: DateTime(2026, 11, 7, time.hour, time.minute),
    dueCount: 4,
  ),
];

void main() {
  group('ReminderSync', () {
    late InMemoryReviewNotifications notifications;
    late NudgeSettings settings;
    late List<ReminderTime> asked;

    ReminderSync sync({
      Future<List<PlannedReminder>> Function(ReminderTime)? plan,
    }) => ReminderSync(
      notifications: notifications,
      settings: () async => settings,
      plan:
          plan ??
          (time) async {
            asked.add(time);
            return _two(time);
          },
    );

    setUp(() {
      notifications = InMemoryReviewNotifications(
        state: NotificationPermission.granted,
      );
      settings = _onSettings;
      asked = [];
    });

    test('on and allowed: the plan at the picked time replaces all', () async {
      notifications.scheduled = [
        PlannedReminder(at: DateTime(2026, 11, 1, 8), dueCount: 9),
      ];
      await sync().sync();
      expect(asked, [_eight]);
      expect(notifications.scheduled, _two(_eight));
      expect(notifications.replaced, 1);
    });

    test('the same twice gives the same reminders', () async {
      final s = sync();
      await s.sync();
      await s.sync();
      expect(notifications.scheduled, _two(_eight));
    });

    test('no time picked: 21:00', () async {
      settings = const NudgeSettings(remindersOn: true, offered: true);
      await sync().sync();
      expect(asked, [ReminderTime.evening]);
    });

    test('off: every reminder taken off, nothing planned', () async {
      notifications.scheduled = _two(_eight);
      settings = _onSettings.copyWith(remindersOn: false);
      await sync().sync();
      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelled, 1);
      expect(asked, isEmpty);
    });

    test('without permission: taken off, nothing planned', () async {
      for (final p in [
        NotificationPermission.denied,
        NotificationPermission.notDetermined,
      ]) {
        notifications
          ..state = p
          ..scheduled = _two(_eight);
        await sync().sync();
        expect(notifications.scheduled, isEmpty, reason: '$p');
        expect(asked, isEmpty, reason: '$p');
        expect(notifications.requests, 0, reason: 'never asks by itself');
      }
    });

    test('a run asked for meanwhile runs once more after it', () async {
      final gate = Completer<void>();
      var runs = 0;
      final s = sync(
        plan: (time) async {
          runs++;
          if (runs == 1) await gate.future;
          return _two(time);
        },
      );
      final first = s.sync();
      final second = s.sync();
      final third = s.sync();
      gate.complete();
      await Future.wait([first, second, third]);
      expect(runs, 2, reason: 'the two asked meanwhile are one more run');
    });

    test('a failure is not thrown and the next run works', () async {
      notifications.failure = StateError('platform');
      final s = sync();
      await s.sync();
      notifications.failure = null;
      await s.sync();
      expect(notifications.scheduled, _two(_eight));
    });

    test('a plan that fails leaves the reminders as they were', () async {
      notifications.scheduled = _two(_eight);
      await sync(plan: (_) async => throw Exception('disk')).sync();
      expect(notifications.scheduled, _two(_eight));
    });
  });

  group('ReminderHost', () {
    late TestBlocks blocks;
    late InMemoryReviewNotifications notifications;
    late InMemoryNudgeStore store;

    Future<void> pumpHost(WidgetTester tester) async {
      // The host goes around the app as in main.dart.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...blocks.overrides,
            reviewNotificationsProvider.overrideWithValue(notifications),
            nudgeStoreProvider.overrideWithValue(store),
          ],
          child: const ReminderHost(
            child: MaterialApp(home: Scaffold(body: Text('홈'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> seed() async {
      blocks = TestBlocks();
      await blocks.seedPage('s010');
      notifications = InMemoryReviewNotifications(
        state: NotificationPermission.granted,
      );
      store = InMemoryNudgeStore(_onSettings);
      // One card due: something to remind about.
      final word = (await blocks.library.words()).first;
      await blocks.reviews.saveCard(
        ReviewCard(
          wordId: word.id,
          level: 2,
          dueAt: testNow.subtract(const Duration(hours: 1)),
          lastReviewedAt: testNow.subtract(const Duration(days: 3)),
        ),
      );
    }

    testWidgets('after the first frame the week is planned', (tester) async {
      await seed();
      await pumpHost(tester);
      expect(notifications.scheduled, hasLength(7));
      expect(notifications.scheduled.first.at, DateTime(2026, 11, 6, 8));
      expect(notifications.scheduled.first.dueCount, 1);
    });

    testWidgets('coming back and going to the back plan again', (tester) async {
      await seed();
      await pumpHost(tester);
      final before = notifications.replaced;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(notifications.replaced, greaterThan(before));

      final away = notifications.replaced;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(notifications.replaced, greaterThan(away));
    });

    testWidgets('coming back reads the permission again', (tester) async {
      await seed();
      await pumpHost(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.text('홈')),
      );
      expect(
        await container.read(notificationPermissionProvider.future),
        NotificationPermission.granted,
      );
      notifications.state = NotificationPermission.denied;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        await container.read(notificationPermissionProvider.future),
        NotificationPermission.denied,
      );
      expect(notifications.scheduled, isEmpty, reason: 'turned off in iOS');
    });

    testWidgets('a data change plans again after the delay', (tester) async {
      await seed();
      await pumpHost(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.text('홈')),
      );
      // The card is answered: nothing is due any more.
      final word = (await blocks.library.words()).first;
      await blocks.reviews.saveCard(
        ReviewCard(
          wordId: word.id,
          level: 3,
          dueAt: testNow.add(const Duration(days: 30)),
          lastReviewedAt: testNow,
        ),
      );
      container.read(dataRevisionProvider.notifier).bump();
      container.read(dataRevisionProvider.notifier).bump();
      await tester.pump(reminderSyncDelay ~/ 2);
      expect(notifications.scheduled, hasLength(7), reason: 'not yet');
      await tester.pump(reminderSyncDelay);
      await tester.pumpAndSettle();
      expect(notifications.scheduled, isEmpty);
    });

    testWidgets('no timer is left when the host goes away', (tester) async {
      await seed();
      await pumpHost(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.text('홈')),
      );
      container.read(dataRevisionProvider.notifier).bump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(reminderSyncDelay * 2);
    });

    testWidgets('turned off in the settings: every reminder taken off', (
      tester,
    ) async {
      await seed();
      await pumpHost(tester);
      expect(notifications.scheduled, isNotEmpty);
      final container = ProviderScope.containerOf(
        tester.element(find.text('홈')),
      );
      await container
          .read(nudgeSettingsProvider.notifier)
          .change((s) => s.copyWith(remindersOn: false));
      await tester.pumpAndSettle();
      expect(notifications.scheduled, isEmpty);
    });

    testWidgets('a new time plans the week at it', (tester) async {
      await seed();
      await pumpHost(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.text('홈')),
      );
      await container
          .read(nudgeSettingsProvider.notifier)
          .change((s) => s.copyWith(reminderTime: const ReminderTime(1290)));
      await tester.pumpAndSettle();
      expect(notifications.scheduled.first.at, DateTime(2026, 11, 5, 21, 30));
    });
  });
}
