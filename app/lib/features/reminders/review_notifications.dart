import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/local_review_notifications.dart';
import 'package:shiori_core/shiori_core.dart';

/// Whether the system lets the app show notifications.
enum NotificationPermission {
  granted,
  denied,

  /// Not asked yet (the system window can still come).
  notDetermined,
}

/// Block slot: reminders put on the device. Local only — no server, no push.
abstract interface class ReviewNotifications {
  Future<NotificationPermission> permission();

  /// Shows the system's permission window when it can still come; true
  /// when notifications are allowed afterwards.
  Future<bool> requestPermission();

  /// Takes every reminder off the device and puts [reminders] on it.
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Takes every reminder off the device.
  Future<void> cancelAll();

  /// The system can open this app's notification settings (iOS).
  bool get canOpenSettings;

  /// Opens this app's notification settings in the system settings.
  Future<void> openSettings();
}

/// What a reminder says.
String reminderMessage(int dueCount) => '오늘 복습할 카드가 $dueCount장 있어요';

/// Kept in memory (tests, previews): records what the app asked for.
final class InMemoryReviewNotifications implements ReviewNotifications {
  InMemoryReviewNotifications({
    this.state = NotificationPermission.notDetermined,
    this.allowOnRequest = true,
    this.canOpenSettings = true,
  });

  /// The permission now.
  NotificationPermission state;

  /// What the learner answers in the system window.
  bool allowOnRequest;

  @override
  final bool canOpenSettings;

  /// The reminders on the device now.
  List<PlannedReminder> scheduled = const [];

  /// How many times the system window was asked for, [replaceAll] and
  /// [cancelAll] were called and the settings were opened.
  int requests = 0;
  int replaced = 0;
  int cancelled = 0;
  int settingsOpened = 0;

  /// Thrown by [replaceAll] when set (a platform failure).
  Object? failure;

  @override
  Future<NotificationPermission> permission() async => state;

  @override
  Future<bool> requestPermission() async {
    requests++;
    if (state == NotificationPermission.notDetermined) {
      state = allowOnRequest
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    }
    return state == NotificationPermission.granted;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    final failed = failure;
    if (failed != null) throw failed;
    replaced++;
    scheduled = List.unmodifiable(reminders);
  }

  @override
  Future<void> cancelAll() async {
    cancelled++;
    scheduled = const [];
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// The reminders block of this platform.
final reviewNotificationsProvider = Provider<ReviewNotifications>(
  (ref) => LocalReviewNotifications(),
);

/// The permission now; refreshed when the app comes back to the front (it
/// may have been changed in the system settings).
final notificationPermissionProvider = FutureProvider<NotificationPermission>(
  (ref) => ref.watch(reviewNotificationsProvider).permission(),
);
