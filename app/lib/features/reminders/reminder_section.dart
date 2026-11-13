import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/reminder_labels.dart';
import 'package:shiori/features/reminders/reminder_sync.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// Stores [change] of the device settings; a failed write says so and the
/// screen keeps what it showed.
Future<bool> _change(
  BuildContext context,
  NudgeSettings Function(NudgeSettings) change,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final settings = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(nudgeSettingsProvider.notifier);
  try {
    await settings.change(change);
    return true;
  } on Exception catch (e, stack) {
    debugPrint('nudge settings not saved: $e\n$stack');
    messenger.showSnackBar(
      const SnackBar(content: Text('저장하지 못했어요. 다시 시도해 주세요')),
    );
    return false;
  }
}

/// 설정 › 알림: 복습 알림 on or off and its time. Turning it on asks the
/// system when it has not been asked; when the system has it off, the
/// switch shows off with a line and a way to the system settings.
class ReminderSection extends ConsumerWidget {
  const ReminderSection({super.key});

  Future<void> _turn(BuildContext context, bool on) async {
    // Read once: the screen can be gone by the time the system answers.
    final container = ProviderScope.containerOf(context, listen: false);
    final notifications = container.read(reviewNotificationsProvider);
    var allowed = true;
    if (on) {
      try {
        allowed =
            await notifications.permission() ==
                NotificationPermission.granted ||
            await notifications.requestPermission();
      } on Exception catch (e, stack) {
        debugPrint('notification permission not asked: $e\n$stack');
        allowed = false;
      }
      container.invalidate(notificationPermissionProvider);
    }
    if (!context.mounted) return;
    final saved = await _change(
      context,
      (s) => s.copyWith(remindersOn: on && allowed, offered: true),
    );
    if (saved) await container.read(reminderSyncProvider).sync();
  }

  Future<void> _pickTime(BuildContext context, ReminderTime time) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final picked = await showCupertinoModalPopup<ReminderTime>(
      context: context,
      builder: (_) => _TimeSheet(time: time),
    );
    if (picked == null || picked == time || !context.mounted) return;
    final saved = await _change(
      context,
      (s) => s.copyWith(reminderTime: picked),
    );
    if (saved) await container.read(reminderSyncProvider).sync();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(nudgeSettingsProvider).value;
    final permission = ref.watch(notificationPermissionProvider).value;
    final notifications = ref.watch(reviewNotificationsProvider);
    final blocked = permission == NotificationPermission.denied;
    final on =
        (settings?.remindersOn ?? false) &&
        permission == NotificationPermission.granted;
    final time = settings?.timeOrDefault ?? ReminderTime.evening;
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel(ReminderLabels.section),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(ReminderLabels.reminder),
          subtitle: const Text(ReminderLabels.reminderHint),
          value: on,
          onChanged: settings == null || blocked
              ? null
              : (value) => _turn(context, value),
        ),
        if (on)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(ReminderLabels.time),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ReminderLabels.timeLabel(time),
                  style: context.text.bodyLarge?.copyWith(
                    color: t.text2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: Space.xs),
                Icon(CupertinoIcons.chevron_right, size: 16, color: t.text3),
              ],
            ),
            onTap: () => _pickTime(context, time),
          ),
        if (blocked) ...[
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              notifications.canOpenSettings
                  ? ReminderLabels.deniedNote
                  : ReminderLabels.deniedNoteOther,
              style: context.text.bodyMedium?.copyWith(color: t.text2),
            ),
          ),
          if (notifications.canOpenSettings)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => notifications.openSettings(),
                child: const Text(ReminderLabels.openSettings),
              ),
            ),
        ],
      ],
    );
  }
}

/// The time wheel (5-minute steps) with 취소 and 완료.
class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.time});

  final ReminderTime time;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late ReminderTime _picked = widget.time;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final initial = DateTime(2000, 1, 1, widget.time.hour, widget.time.minute);
    return Material(
      color: t.bg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: Row(
                children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: t.text2),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(ReminderLabels.cancel),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        ReminderLabels.pickTime,
                        textAlign: TextAlign.center,
                        style: context.text.titleMedium,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_picked),
                    child: const Text(ReminderLabels.done),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: _wheelHeight,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                minuteInterval: _minuteStep,
                initialDateTime: initial.copyWith(
                  minute: initial.minute - initial.minute % _minuteStep,
                ),
                onDateTimeChanged: (d) =>
                    _picked = ReminderTime(d.hour * 60 + d.minute),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const int _minuteStep = 5;
const double _wheelHeight = 216;

/// 설정 › 학습 세션 › 햅틱.
class HapticsSwitch extends ConsumerWidget {
  const HapticsSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(nudgeSettingsProvider).value;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: const Text(ReminderLabels.haptics),
      subtitle: const Text(ReminderLabels.hapticsHint),
      value: settings?.haptics ?? true,
      onChanged: settings == null
          ? null
          : (on) => _change(context, (s) => s.copyWith(haptics: on)),
    );
  }
}
