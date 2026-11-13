import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:timezone/timezone.dart' as tz;

/// Reminders through flutter_local_notifications, and the iOS permission
/// state and settings link through the `shiori/system` channel
/// (`SystemChannel.swift`).
///
/// Nothing goes off the device: no push registration, no attachments. The
/// plugin never asks for permission by itself (only [requestPermission]
/// does), and a reminder that comes while the app is in front stays in the
/// notification list without a banner or sound.
final class LocalReviewNotifications implements ReviewNotifications {
  LocalReviewNotifications({
    FlutterLocalNotificationsPlugin? plugin,
    this.system = systemChannel,
    bool? isIOS,
  }) : plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       isIOS = isIOS ?? defaultTargetPlatform == TargetPlatform.iOS;

  /// iOS: `notificationStatus` (the `UNAuthorizationStatus` name) and
  /// `openNotificationSettings`.
  static const MethodChannel systemChannel = MethodChannel('shiori/system');

  final FlutterLocalNotificationsPlugin plugin;
  final MethodChannel system;
  final bool isIOS;

  Future<void>? _ready;

  /// Sets the plugin up once; a failed set-up is tried again next time.
  Future<void> _setUp() => _ready ??= _initialize().catchError((Object e) {
    _ready = null;
    throw e;
  });

  Future<void> _initialize() async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<NotificationPermission> permission() async {
    if (isIOS) {
      return permissionFromStatus(
        await system.invokeMethod<String>('notificationStatus'),
      );
    }
    await _setUp();
    final enabled = await _android?.areNotificationsEnabled() ?? false;
    // Android cannot tell "not asked" from "refused"; asking again shows the
    // window only while the system still allows it.
    return enabled
        ? NotificationPermission.granted
        : NotificationPermission.notDetermined;
  }

  @override
  Future<bool> requestPermission() async {
    await _setUp();
    if (isIOS) {
      final ios = plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _setUp();
    await plugin.cancelAllPendingNotifications();
    for (final reminder in reminders) {
      // A time that passed while the earlier ones were put on (the plugin
      // refuses a past time).
      if (!reminder.at.isAfter(DateTime.now())) continue;
      await plugin.zonedSchedule(
        id: reminderIdOf(reminder.at),
        // An instant in UTC: the time zone database is not needed, and the
        // app plans again when it comes back after a zone change.
        scheduledDate: tz.TZDateTime.from(reminder.at.toUtc(), tz.UTC),
        body: reminderMessage(reminder.dueCount),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _setUp();
    await plugin.cancelAllPendingNotifications();
  }

  @override
  bool get canOpenSettings => isIOS;

  @override
  Future<void> openSettings() async {
    if (!isIOS) return;
    await system.invokeMethod<void>('openNotificationSettings');
  }
}

const NotificationDetails _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'review',
    '복습 알림',
    channelDescription: '복습할 카드가 있는 날 한 번',
  ),
  iOS: DarwinNotificationDetails(
    threadIdentifier: 'review',
    interruptionLevel: InterruptionLevel.active,
    // In front, the app is already open: the list only.
    presentAlert: false,
    presentBanner: false,
    presentSound: false,
    presentBadge: false,
    presentList: true,
  ),
);

/// The permission the `shiori/system` channel's `notificationStatus` names
/// (`UNAuthorizationStatus`): authorized, provisional and ephemeral allow
/// reminders; anything unknown is taken as denied.
NotificationPermission permissionFromStatus(String? status) => switch (status) {
  'notDetermined' => NotificationPermission.notDetermined,
  'authorized' ||
  'provisional' ||
  'ephemeral' => NotificationPermission.granted,
  _ => NotificationPermission.denied,
};

/// The notification id of the reminder at [at]: its date as yyyymmdd, so a
/// day has one reminder.
int reminderIdOf(DateTime at) => at.year * 10000 + at.month * 100 + at.day;
