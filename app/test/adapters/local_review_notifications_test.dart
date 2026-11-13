// N3·N8: the notification block's own parts — the iOS permission read
// through the `shiori/system` channel, the way to the system settings, and
// one notification id a day.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/local_review_notifications.dart';
import 'package:shiori/features/reminders/review_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = LocalReviewNotifications.systemChannel;

  final calls = <MethodCall>[];
  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  void answer(Object? Function(MethodCall call) reply) =>
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return reply(call);
      });

  test('the channel is shiori/system', () {
    expect(channel.name, 'shiori/system');
  });

  test('UNAuthorizationStatus names map to the permission', () {
    expect(
      permissionFromStatus('notDetermined'),
      NotificationPermission.notDetermined,
    );
    expect(permissionFromStatus('denied'), NotificationPermission.denied);
    expect(permissionFromStatus('authorized'), NotificationPermission.granted);
    expect(permissionFromStatus('provisional'), NotificationPermission.granted);
    expect(permissionFromStatus('ephemeral'), NotificationPermission.granted);
    expect(
      permissionFromStatus('something new'),
      NotificationPermission.denied,
    );
    expect(permissionFromStatus(null), NotificationPermission.denied);
  });

  test('iOS reads the permission from the channel', () async {
    answer((_) => 'notDetermined');
    final block = LocalReviewNotifications(isIOS: true);
    expect(await block.permission(), NotificationPermission.notDetermined);
    expect(calls.single.method, 'notificationStatus');
  });

  test('iOS opens the app notification settings through the channel', () async {
    answer((_) => null);
    final block = LocalReviewNotifications(isIOS: true);
    expect(block.canOpenSettings, isTrue);
    await block.openSettings();
    expect(calls.single.method, 'openNotificationSettings');
  });

  test('a channel error comes up to the caller', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'failed'),
    );
    final block = LocalReviewNotifications(isIOS: true);
    await expectLater(block.permission(), throwsA(isA<PlatformException>()));
  });

  test('elsewhere there is no settings link', () async {
    answer((_) => null);
    final block = LocalReviewNotifications(isIOS: false);
    expect(block.canOpenSettings, isFalse);
    await block.openSettings();
    expect(calls, isEmpty);
  });

  test('one id a day: the date as yyyymmdd', () {
    expect(reminderIdOf(DateTime(2026, 11, 14, 8)), 20261114);
    expect(reminderIdOf(DateTime(2027, 1, 2, 23, 59)), 20270102);
    expect(reminderIdOf(DateTime.utc(2026, 12, 31, 21)), 20261231);
  });

  test('a reminder says how many cards are due', () {
    expect(reminderMessage(12), '오늘 복습할 카드가 12장 있어요');
    expect(reminderMessage(1), '오늘 복습할 카드가 1장 있어요');
  });
}
