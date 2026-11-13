// N4: a tap on a reminder only opens the app. A cold start shows 홈; an app
// that was in the back shows the screen it was on (a session or a page
// being checked is not lost), and the reminders are planned again.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/features/home/home_screen.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/reminder_sync.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../../support/harness.dart';

void main() {
  late TestBlocks blocks;
  late InMemoryReviewNotifications notifications;

  Future<void> seed() async {
    blocks = TestBlocks();
    await blocks.seedPage('s010');
    notifications = InMemoryReviewNotifications(
      state: NotificationPermission.granted,
    );
  }

  Widget hosted() => ProviderScope(
    overrides: [
      ...blocks.overrides,
      reviewNotificationsProvider.overrideWithValue(notifications),
      nudgeStoreProvider.overrideWithValue(
        InMemoryNudgeStore(
          const NudgeSettings(
            remindersOn: true,
            reminderTime: ReminderTime(8 * 60),
            offered: true,
            swipeHinted: true,
          ),
        ),
      ),
    ],
    child: const ReminderHost(child: ShioriApp()),
  );

  testWidgets('a cold start opens on 홈', (tester) async {
    await seed();
    usePhoneSize(tester);
    await tester.pumpWidget(hosted());
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(StudyScreen), findsNothing);
  });

  testWidgets('back from the background: the same screen, planned again', (
    tester,
  ) async {
    await seed();
    usePhoneSize(tester);
    await tester.pumpWidget(hosted());
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
    expect(find.byType(StudyScreen), findsOneWidget);
    final before = notifications.replaced;

    // The tap brings the app to the front.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(StudyScreen), findsOneWidget);
    expect(find.text('0 / 10'), findsOneWidget, reason: 'the session stays');
    expect(notifications.replaced, greaterThan(before));
  });
}
