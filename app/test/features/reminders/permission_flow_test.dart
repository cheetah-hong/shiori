// N3: reminders are offered once, under the first 오늘 학습 끝, before the
// system is asked; never at the first launch. 설정 › 알림 turns them on and
// off, picks the time, and leads to the iOS settings when they are off
// there.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori/features/settings/settings_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../../support/harness.dart';

void main() {
  late TestBlocks blocks;
  late InMemoryReviewNotifications notifications;
  late InMemoryNudgeStore store;

  List<Override> extra([NudgeStore? using]) => [
    reviewNotificationsProvider.overrideWithValue(notifications),
    nudgeStoreProvider.overrideWithValue(using ?? store),
    studySettingsProvider.overrideWithValue(const StudySettings(dailyGoal: 1)),
  ];

  Future<void> seed() async {
    blocks = TestBlocks(); // 21:00
    await blocks.seedPage('s010');
    notifications = InMemoryReviewNotifications();
    store = InMemoryNudgeStore();
    // A review due tomorrow morning: something to remind about.
    final word = (await blocks.library.words()).last;
    await blocks.reviews.saveCard(
      ReviewCard(
        wordId: word.id,
        level: 2,
        dueAt: testNow.add(const Duration(hours: 10)),
        lastReviewedAt: testNow.subtract(const Duration(days: 3)),
      ),
    );
  }

  /// Opens the app and studies one card to 오늘 학습 끝.
  Future<void> finishASession(WidgetTester tester) async {
    await tester.pumpWidget(app(blocks, extra: extra()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('오늘 학습 시작 · 1장'));
    await tester.tap(find.text('오늘 학습 시작 · 1장'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('알고있음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 학습 끝'), findsOneWidget);
  }

  group('the offer after a session', () {
    testWidgets('not on 홈 at the first launch', (tester) async {
      await seed();
      usePhoneSize(tester);
      await tester.pumpWidget(app(blocks, extra: extra()));
      await tester.pumpAndSettle();
      expect(find.text('복습 알림을 받을까요?'), findsNothing);
      expect(notifications.requests, 0);
    });

    testWidgets('under the first 오늘 학습 끝, with the time now', (tester) async {
      await seed();
      usePhoneSize(tester);
      await finishASession(tester);
      expect(find.text('복습 알림을 받을까요?'), findsOneWidget);
      expect(find.text('복습할 카드가 있는 날만 오후 9:00에 한 번 알려요.'), findsOneWidget);
      expect(find.text('알림 받기'), findsOneWidget);
      expect(find.text('나중에'), findsOneWidget);
      expect(find.text('확인'), findsOneWidget, reason: '확인 stays');
      expect(notifications.requests, 0, reason: 'the system is not asked yet');
      expect(store.settings.offered, isTrue, reason: 'shown once');
    });

    testWidgets('알림 받기, allowed: on at that time, a line says so', (
      tester,
    ) async {
      await seed();
      usePhoneSize(tester);
      await finishASession(tester);
      await tester.tap(find.text('알림 받기'));
      await tester.pumpAndSettle();
      expect(notifications.requests, 1);
      expect(find.text('오후 9:00에 알릴게요 · 설정에서 바꿀 수 있어요'), findsOneWidget);
      expect(find.text('복습 알림을 받을까요?'), findsNothing);
      expect(store.settings.remindersOn, isTrue);
      expect(store.settings.reminderTime, const ReminderTime(21 * 60));
    });

    testWidgets('알림 받기, refused: off, a line leads to 설정', (tester) async {
      await seed();
      usePhoneSize(tester);
      notifications.allowOnRequest = false;
      await finishASession(tester);
      await tester.tap(find.text('알림 받기'));
      await tester.pumpAndSettle();
      expect(notifications.requests, 1);
      expect(find.text('알림이 꺼져 있어요 · 설정 › 알림에서 다시 켤 수 있어요'), findsOneWidget);
      expect(store.settings.remindersOn, isFalse);
      expect(notifications.scheduled, isEmpty);
    });

    testWidgets('나중에: gone and not asked again', (tester) async {
      await seed();
      usePhoneSize(tester);
      await finishASession(tester);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(find.text('복습 알림을 받을까요?'), findsNothing);
      expect(notifications.requests, 0);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      // Another session: no offer.
      await tester.tap(find.textContaining('오늘 학습 시작'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('알고있음'));
      await tester.pumpAndSettle();
      expect(find.text('오늘 학습 끝'), findsOneWidget);
      expect(find.text('복습 알림을 받을까요?'), findsNothing);
    });

    testWidgets('leaving with 확인 is the same as 나중에', (tester) async {
      await seed();
      usePhoneSize(tester);
      await finishASession(tester);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(store.settings.offered, isTrue);
      expect(store.settings.remindersOn, isFalse);
      expect(notifications.requests, 0);
    });

    testWidgets('no offer once the system has been asked', (tester) async {
      await seed();
      usePhoneSize(tester);
      notifications.state = NotificationPermission.denied;
      await finishASession(tester);
      expect(find.text('복습 알림을 받을까요?'), findsNothing);
    });

    testWidgets('no offer when the settings cannot be read', (tester) async {
      await seed();
      usePhoneSize(tester);
      await tester.pumpWidget(app(blocks, extra: extra(_BrokenStore())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('오늘 학습 시작 · 1장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('알고있음'));
      await tester.pumpAndSettle();
      expect(find.text('오늘 학습 끝'), findsOneWidget);
      expect(find.text('복습 알림을 받을까요?'), findsNothing);
    });

    testWidgets('large text: the offer and 확인 can be reached', (tester) async {
      await seed();
      usePhoneSize(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 3.1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await finishASession(tester);
      await tester.scrollUntilVisible(
        find.text('알림 받기'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('알림 받기'));
      await tester.pumpAndSettle();
      expect(store.settings.remindersOn, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('설정 › 알림', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.pumpWidget(
        screen(blocks, const SettingsScreen(), extra: extra()),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('복습 알림'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Finder reminderSwitch() => find.descendant(
      of: find.ancestor(
        of: find.text('복습 알림'),
        matching: find.byType(ListTile),
      ),
      matching: find.byWidgetPredicate(
        (w) => w is Switch || w is CupertinoSwitch,
      ),
    );

    bool isOn(WidgetTester tester) {
      final w = tester.widget(reminderSwitch().first);
      return switch (w) {
        Switch(:final value) => value,
        CupertinoSwitch(:final value) => value,
        _ => throw StateError('no switch'),
      };
    }

    testWidgets('off by default, no time row', (tester) async {
      await seed();
      usePhoneSize(tester);
      await openSettings(tester);
      expect(find.text('알림'), findsOneWidget);
      expect(find.text('복습할 카드가 있는 날만 한 번 알려요'), findsOneWidget);
      expect(isOn(tester), isFalse);
      expect(find.text('시각'), findsNothing);
    });

    testWidgets('turning on asks the system when not asked yet', (
      tester,
    ) async {
      await seed();
      usePhoneSize(tester);
      await openSettings(tester);
      await tester.tap(find.text('복습 알림'));
      await tester.pumpAndSettle();
      expect(notifications.requests, 1);
      expect(isOn(tester), isTrue);
      expect(store.settings.remindersOn, isTrue);
      expect(store.settings.offered, isTrue, reason: 'no offer after this');
      expect(find.text('시각'), findsOneWidget);
      expect(find.text('오후 9:00'), findsOneWidget, reason: 'the default');
      expect(notifications.scheduled, isNotEmpty);
    });

    testWidgets('refused in the window: off with the way to iOS settings', (
      tester,
    ) async {
      await seed();
      usePhoneSize(tester);
      notifications.allowOnRequest = false;
      await openSettings(tester);
      await tester.tap(find.text('복습 알림'));
      await tester.pumpAndSettle();
      expect(isOn(tester), isFalse);
      expect(store.settings.remindersOn, isFalse);
      expect(find.text('iOS 설정에서 시오리 알림이 꺼져 있어요'), findsOneWidget);
      expect(find.text('iOS 설정 열기'), findsOneWidget);
    });

    testWidgets('off in iOS: the line and the button open iOS settings', (
      tester,
    ) async {
      await seed();
      usePhoneSize(tester);
      notifications.state = NotificationPermission.denied;
      store.settings = const NudgeSettings(remindersOn: true, offered: true);
      await openSettings(tester);
      expect(isOn(tester), isFalse, reason: 'the system has it off');
      expect(find.text('시각'), findsNothing);
      await tester.ensureVisible(find.text('iOS 설정 열기'));
      await tester.tap(find.text('iOS 설정 열기'));
      await tester.pumpAndSettle();
      expect(notifications.settingsOpened, 1);
      expect(notifications.requests, 0);
    });

    testWidgets('where the settings cannot be opened, the line only', (
      tester,
    ) async {
      await seed();
      usePhoneSize(tester);
      notifications = InMemoryReviewNotifications(
        state: NotificationPermission.denied,
        canOpenSettings: false,
      );
      await openSettings(tester);
      expect(find.text('기기 설정에서 시오리 알림이 꺼져 있어요'), findsOneWidget);
      expect(find.text('iOS 설정 열기'), findsNothing);
    });

    testWidgets('turning off takes every reminder off', (tester) async {
      await seed();
      usePhoneSize(tester);
      notifications.state = NotificationPermission.granted;
      store.settings = const NudgeSettings(
        remindersOn: true,
        reminderTime: ReminderTime(8 * 60),
        offered: true,
      );
      notifications.scheduled = [
        PlannedReminder(at: DateTime(2026, 11, 6, 8), dueCount: 2),
      ];
      await openSettings(tester);
      expect(isOn(tester), isTrue);
      expect(find.text('오전 8:00'), findsOneWidget);
      await tester.tap(find.text('복습 알림'));
      await tester.pumpAndSettle();
      expect(store.settings.remindersOn, isFalse);
      expect(notifications.scheduled, isEmpty);
      expect(find.text('시각'), findsNothing);
    });

    testWidgets('the time is picked in a sheet and kept', (tester) async {
      await seed();
      usePhoneSize(tester);
      notifications.state = NotificationPermission.granted;
      store.settings = const NudgeSettings(
        remindersOn: true,
        reminderTime: ReminderTime(8 * 60),
        offered: true,
      );
      await openSettings(tester);
      await tester.tap(find.text('시각'));
      await tester.pumpAndSettle();
      expect(find.text('알림 시각'), findsOneWidget);
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.mode, CupertinoDatePickerMode.time);
      expect(picker.minuteInterval, 5);
      picker.onDateTimeChanged(DateTime(2026, 11, 5, 7, 35));
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();
      expect(store.settings.reminderTime, const ReminderTime(7 * 60 + 35));
      expect(find.text('오전 7:35'), findsOneWidget);
      expect(notifications.scheduled.first.at.minute, 35);
    });

    testWidgets('취소 keeps the time', (tester) async {
      await seed();
      usePhoneSize(tester);
      notifications.state = NotificationPermission.granted;
      store.settings = const NudgeSettings(
        remindersOn: true,
        reminderTime: ReminderTime(8 * 60),
        offered: true,
      );
      await openSettings(tester);
      await tester.tap(find.text('시각'));
      await tester.pumpAndSettle();
      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2026, 11, 5, 23));
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(store.settings.reminderTime, const ReminderTime(8 * 60));
    });

    testWidgets('햅틱 under 학습 세션, on by default, kept when turned off', (
      tester,
    ) async {
      await seed();
      usePhoneSize(tester);
      await tester.pumpWidget(
        screen(blocks, const SettingsScreen(), extra: extra()),
      );
      await tester.pumpAndSettle();
      expect(find.text('햅틱'), findsOneWidget);
      expect(find.text('답할 때 가볍게 진동해요'), findsOneWidget);
      await tester.tap(find.text('햅틱'));
      await tester.pumpAndSettle();
      expect(store.settings.haptics, isFalse);
    });

    testWidgets('a failed save says so and keeps the switch', (tester) async {
      await seed();
      usePhoneSize(tester);
      final broken = _BrokenStore(loads: true);
      await tester.pumpWidget(
        screen(blocks, const SettingsScreen(), extra: extra(broken)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('햅틱'));
      await tester.pumpAndSettle();
      expect(find.text('저장하지 못했어요. 다시 시도해 주세요'), findsOneWidget);
    });
  });
}

/// A store that cannot be read (or, with [loads], read but not written).
final class _BrokenStore implements NudgeStore {
  _BrokenStore({this.loads = false});

  final bool loads;

  @override
  Future<NudgeSettings> load() async {
    if (loads) return const NudgeSettings(offered: true);
    throw const FormatException('damaged');
  }

  @override
  Future<void> save(NudgeSettings settings) async =>
      throw const FileSystemExceptionStandIn();
}

final class FileSystemExceptionStandIn implements Exception {
  const FileSystemExceptionStandIn();
}
