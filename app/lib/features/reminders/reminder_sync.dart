import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori_core/shiori_core.dart';

/// Puts the reminders of the next days on the device: every one is taken
/// off and the new ones put on, so asking again gives the same result.
///
/// Off, or without the system's permission: none. A run asked for while
/// one is on its way runs once more after it (never two at a time). A
/// failure is written to the log and leaves the app as it is.
final class ReminderSync {
  ReminderSync({
    required this.notifications,
    required this.settings,
    required this.plan,
  });

  final ReviewNotifications notifications;

  /// The settings in use.
  final Future<NudgeSettings> Function() settings;

  /// The reminders at a time of day (StudyService.reminders in the mode in
  /// use).
  final Future<List<PlannedReminder>> Function(ReminderTime time) plan;

  /// Plans and puts the reminders on the device; done when this run and
  /// any asked for meanwhile are done.
  Future<void> sync() {
    final running = _running;
    if (running != null) {
      // One more run after this one covers every request made meanwhile.
      return _again ??= running.then((_) {
        _again = null;
        return sync();
      });
    }
    final run = _run().whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  Future<void>? _running;
  Future<void>? _again;

  Future<void> _run() async {
    try {
      final now = await settings();
      if (!now.remindersOn ||
          await notifications.permission() != NotificationPermission.granted) {
        await notifications.cancelAll();
        return;
      }
      await notifications.replaceAll(await plan(now.timeOrDefault));
    } on Exception catch (e, stack) {
      debugPrint('reminders not planned: $e\n$stack');
    } on Error catch (e, stack) {
      // A bug in a block: report it like any uncaught error; the next run
      // tries again.
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stack, library: 'reminders'),
      );
    }
  }
}

final reminderSyncProvider = Provider<ReminderSync>(
  (ref) => ReminderSync(
    notifications: ref.watch(reviewNotificationsProvider),
    settings: () => ref.read(nudgeSettingsProvider.future),
    plan: (time) async => ref
        .read(studyServiceProvider)
        .reminders(mode: await ref.read(studyModeProvider.future), time: time),
  ),
);

/// How long after a change of the data the reminders are planned again
/// (answers come one after another in a session).
const Duration reminderSyncDelay = Duration(seconds: 2);

/// Keeps the reminders up to date around the app: after the first frame,
/// when the app comes back to the front or goes to the back, and
/// [reminderSyncDelay] after the data changed (answers, edits, a restore).
/// Coming back also reads the permission again (it may have been changed in
/// the system settings).
///
/// A tap on a reminder only opens the app: a cold start shows 홈, and an app
/// that was in the back shows the screen it was on.
class ReminderHost extends ConsumerStatefulWidget {
  const ReminderHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends ConsumerState<ReminderHost>
    with WidgetsBindingObserver {
  Timer? _later;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncNow());
  }

  @override
  void dispose() {
    _later?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ref.invalidate(notificationPermissionProvider);
        _syncNow();
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _syncNow();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _syncNow() {
    _later?.cancel();
    if (!mounted) return;
    unawaited(ref.read(reminderSyncProvider).sync());
  }

  void _syncLater() {
    _later?.cancel();
    _later = Timer(reminderSyncDelay, _syncNow);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dataRevisionProvider, (_, _) => _syncLater());
    // On, off or a new time: plan at once.
    ref.listen(nudgeSettingsProvider, (before, now) {
      // After the change has settled (the listener runs while the new
      // value is being set).
      if (before?.value != null && before?.value != now.value) {
        scheduleMicrotask(_syncNow);
      }
    });
    return widget.child;
  }
}
