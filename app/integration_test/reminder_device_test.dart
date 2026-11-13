// Review reminders with the real notification block on a simulator: 알림
// 받기 brings the iOS permission window, and once allowed a reminder put on
// the device arrives.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/reminder_device_test.dart
//
// The permission window is answered by hand (or a GUI tool) within two
// minutes; the window and the reminder that arrives are taken with
// `xcrun simctl io <simulator> screenshot` (201, 206): neither is drawn by
// Flutter. The reminder is put 45 seconds ahead with a made-up count, to
// see it arrive (send the app to the back meanwhile, then open it again);
// the counts themselves are checked by the unit tests.
// In-memory database, made-up words.
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/local_review_notifications.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

/// How long the test waits for the permission window to be answered.
const _answerWithin = Duration(minutes: 2);

/// How far ahead the reminder that is to arrive is put.
const _soon = Duration(seconds: 45);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the permission window, then a reminder arrives', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await LibraryService(
      library: DriftLibraryRepository(database),
      clock: const SystemClock(),
    ).addDraft(
      const CaptureDraft(
        entries: [
          CapturedEntry(
            headword: '試語甲',
            readings: ['しごこう'],
            pos: PartOfSpeech.noun,
            meaning: '시험 낱말 갑',
          ),
        ],
      ),
      to: const NewPlaylist('시험 목록'),
    );
    final plugin = FlutterLocalNotificationsPlugin();
    final notifications = LocalReviewNotifications(plugin: plugin);
    final fresh =
        await notifications.permission() ==
        NotificationPermission.notDetermined;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          studySettingsProvider.overrideWithValue(
            const StudySettings(dailyGoal: 1),
          ),
          nudgeStoreProvider.overrideWithValue(InMemoryNudgeStore()),
          reviewNotificationsProvider.overrideWithValue(notifications),
        ],
        child: const ShioriApp(),
      ),
    );
    Future<void> waitFor(Finder finder, Duration within) async {
      final end = DateTime.now().add(within);
      while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(finder, findsWidgets);
    }

    await waitFor(find.textContaining('오늘 학습 시작'), const Duration(seconds: 10));
    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    // A fresh install offers reminders; the system window is answered
    // outside the app. Run again later, permission is already given.
    if (fresh) {
      await waitFor(find.text('알림 받기'), const Duration(seconds: 10));
      await tester.tap(find.text('알림 받기'));
      debugPrint('PERMISSION_WINDOW_UP');
      await waitFor(find.textContaining('알릴게요'), _answerWithin);
    }
    expect(await notifications.permission(), NotificationPermission.granted);

    final at = DateTime.now().add(_soon);
    await notifications.replaceAll([PlannedReminder(at: at, dueCount: 12)]);
    final pending = await plugin.pendingNotificationRequests();
    expect(pending.map((p) => (p.id, p.body)), [
      (reminderIdOf(at), '오늘 복습할 카드가 12장 있어요'),
    ]);
    debugPrint('REMINDER_AT ${at.toIso8601String()}');
    // The app is sent to the back meanwhile (the reminder shows as a
    // banner) and brought back; `flutter drive` removes the app at the end,
    // and its reminders with it.
    final until = at.add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(until)) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  });
}
