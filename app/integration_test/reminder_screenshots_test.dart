// Review reminders and card swiping on a simulator: the offer under the
// first 오늘 학습 끝 and its answer, 설정 › 알림 (on, the time sheet, off in
// iOS), and a card swiped right, left (dark) and with large text.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/reminder_screenshots_test.dart
//
// Screenshots land in docs/screenshots/ (200, 202–205, 207–209). In-memory
// database, made-up words, and an in-memory notification block (the system
// window and a reminder that arrives are taken by reminder_device_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori/features/study/swipe_answer.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

/// Made-up words (headword, reading, meaning).
const _words = [
  ('試語甲', 'しごこう', '시험 낱말 갑'),
  ('試語乙', 'しごおつ', '시험 낱말 을'),
  ('試語丙', 'しごへい', '시험 낱말 병'),
];

/// Saturday 14 November 2026, 08:12: the offer says 오전 8:00.
final _now = DateTime(2026, 11, 14, 8, 12);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Future<ShioriDatabase> seeded() async {
    final database = ShioriDatabase.memory();
    await LibraryService(
      library: DriftLibraryRepository(database),
      clock: FixedClock(_now),
    ).addDraft(
      CaptureDraft(
        entries: [
          for (final (head, kana, meaning) in _words)
            CapturedEntry(
              headword: head,
              readings: [kana],
              pos: PartOfSpeech.noun,
              meaning: meaning,
            ),
        ],
      ),
      to: const NewPlaylist('시험 목록'),
    );
    return database;
  }

  Future<ShioriDatabase> pumpApp(
    WidgetTester tester, {
    required NudgeStore store,
    required ReviewNotifications notifications,
    int goal = 1,
  }) async {
    final database = await seeded();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(FixedClock(_now)),
          studySettingsProvider.overrideWithValue(
            StudySettings(dailyGoal: goal),
          ),
          nudgeStoreProvider.overrideWithValue(store),
          reviewNotificationsProvider.overrideWithValue(notifications),
        ],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.textContaining('오늘 학습 시작'));
    return database;
  }

  /// 설정 with 카드 순서 섞기 at the top: 햅틱 and 알림 under it (the
  /// settings list is the last scrollable; 홈 is still under it).
  Future<void> openSettings(WidgetTester tester) async {
    await tap(tester, find.byTooltip('설정'));
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position;
    position.jumpTo(0);
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.text('카드 순서 섞기')).dy;
    position.jumpTo((top - 110).clamp(0, position.maxScrollExtent).toDouble());
    await tester.pumpAndSettle();
  }

  testWidgets('the offer after the first session, and 설정 › 알림', (tester) async {
    final store = InMemoryNudgeStore();
    final notifications = InMemoryReviewNotifications();
    final database = await pumpApp(
      tester,
      store: store,
      notifications: notifications,
    );
    addTearDown(database.close);

    await tap(tester, find.textContaining('오늘 학습 시작'));
    await tap(tester, find.text('알고있음'));
    await waitFor(tester, find.text('복습 알림을 받을까요?'));
    await shot(tester, '200_reminder_offer');

    await tap(tester, find.text('알림 받기'));
    await waitFor(tester, find.textContaining('알릴게요'));
    await shot(tester, '202_reminder_offer_allowed');

    await tap(tester, find.text('확인'));
    await openSettings(tester);
    await shot(tester, '203_settings_reminders_on');

    await tap(tester, find.text('시각'));
    await waitFor(tester, find.text('알림 시각'));
    await shot(tester, '204_settings_reminder_time');
    await tap(tester, find.text('취소'));
  });

  testWidgets('설정 › 알림 when iOS has them off', (tester) async {
    final database = await pumpApp(
      tester,
      store: InMemoryNudgeStore(
        const NudgeSettings(remindersOn: true, offered: true),
      ),
      notifications: InMemoryReviewNotifications(
        state: NotificationPermission.denied,
      ),
    );
    addTearDown(database.close);
    await openSettings(tester);
    await waitFor(tester, find.text('iOS 설정 열기'));
    await shot(tester, '205_settings_reminders_denied');
  });

  /// Opens a session of 뜻 맞히기 and holds the card dragged by [dx]; the
  /// returned function lifts the finger. The events come as from the
  /// device, so the test's own pointer marks stay off the picture.
  Future<Future<void> Function()> holdSwipe(
    WidgetTester tester,
    double dx,
  ) async {
    await tap(tester, find.textContaining('오늘 학습 시작'));
    await waitFor(tester, find.byType(SwipeToAnswer));
    binding.shouldPropagateDevicePointerEvents = true;
    const pointer = 7;
    var at = tester.getCenter(find.byType(SwipeToAnswer));
    void send(PointerEvent e) => binding.handlePointerEventForSource(
      e,
      source: TestBindingEventSource.device,
    );
    send(PointerDownEvent(pointer: pointer, position: at));
    for (var i = 1; i <= 10; i++) {
      final step = Offset(dx / 10, 0);
      at += step;
      send(PointerMoveEvent(pointer: pointer, position: at, delta: step));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 100));
    return () async {
      send(PointerUpEvent(pointer: pointer, position: at));
      binding.shouldPropagateDevicePointerEvents = false;
      await tester.pumpAndSettle();
    };
  }

  Future<void> swipeShot(
    WidgetTester tester,
    String name,
    double dx, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final database = await pumpApp(
      tester,
      store: InMemoryNudgeStore(
        const NudgeSettings(offered: true, swipeHinted: true),
      ),
      notifications: InMemoryReviewNotifications(
        state: NotificationPermission.denied,
      ),
      goal: 3,
    );
    addTearDown(database.close);
    final lift = await holdSwipe(tester, dx);
    await binding.takeScreenshot(name);
    await lift();
  }

  testWidgets('a card swiped right', (tester) async {
    await swipeShot(tester, '207_swipe_known', 130);
  });

  testWidgets('a card swiped left, dark', (tester) async {
    await swipeShot(
      tester,
      '208_swipe_retry_dark',
      -130,
      brightness: Brightness.dark,
    );
  });

  testWidgets('a card swiped with large text', (tester) async {
    await swipeShot(tester, '209_swipe_large_text', 130, textScale: 2);
  });
}
