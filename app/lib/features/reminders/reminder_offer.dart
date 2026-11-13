import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/reminder_labels.dart';
import 'package:shiori/features/reminders/reminder_sync.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori_core/shiori_core.dart';

/// The offer of reminders under 오늘 학습 끝, once: when it has not been
/// shown and the system has not been asked. 알림 받기 brings the system's
/// window; 나중에 (or leaving) does not ask again — 설정 › 알림 can.
/// The offered time is the time now, rounded down to the half hour and
/// kept between 07:00 and 22:00.
class ReminderOffer extends ConsumerStatefulWidget {
  const ReminderOffer({super.key});

  @override
  ConsumerState<ReminderOffer> createState() => _ReminderOfferState();
}

enum _Step { none, offer, on, off }

class _ReminderOfferState extends ConsumerState<ReminderOffer> {
  _Step _step = _Step.none;
  late final ReminderTime _time = ReminderTime.offeredAt(
    ref.read(clockProvider).now(),
  );
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_decide());
  }

  /// Shows the offer when it was never shown and the system was never
  /// asked, and counts it as shown at once (leaving is 나중에).
  Future<void> _decide() async {
    // Read once: the screen can be gone by the time the answers come.
    final settingsNotifier = ref.read(nudgeSettingsProvider.notifier);
    final notifications = ref.read(reviewNotificationsProvider);
    try {
      final settings = await ref.read(nudgeSettingsProvider.future);
      if (settings.offered) return;
      final permission = await notifications.permission();
      if (permission != NotificationPermission.notDetermined || !mounted) {
        return;
      }
      await settingsNotifier.change((s) => s.copyWith(offered: true));
      if (mounted) setState(() => _step = _Step.offer);
    } on Exception catch (e, stack) {
      // No offer this time; the session's end works as before.
      debugPrint('reminder offer not shown: $e\n$stack');
    }
  }

  Future<void> _accept() async {
    if (_asking) return;
    setState(() => _asking = true);
    // Read once: the screen can be gone by the time the system answers.
    final container = ProviderScope.containerOf(context, listen: false);
    var allowed = false;
    try {
      allowed = await container
          .read(reviewNotificationsProvider)
          .requestPermission();
      await container
          .read(nudgeSettingsProvider.notifier)
          .change((s) => s.copyWith(remindersOn: allowed, reminderTime: _time));
      container.invalidate(notificationPermissionProvider);
      await container.read(reminderSyncProvider).sync();
    } on Exception catch (e, stack) {
      debugPrint('reminders not turned on: $e\n$stack');
      allowed = false;
    }
    if (mounted) setState(() => _step = allowed ? _Step.on : _Step.off);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final step = _step;
    if (step == _Step.none) return const SizedBox.shrink();
    final rule = BorderSide(color: t.line);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: rule, bottom: rule),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Semantics(
            liveRegion: step != _Step.offer,
            container: true,
            child: switch (step) {
              _Step.offer => _Offer(
                time: _time,
                asking: _asking,
                onAccept: _accept,
                onLater: () => setState(() => _step = _Step.none),
              ),
              _Step.on => _Line(ReminderLabels.turnedOn(_time)),
              _Step.off || _Step.none => const _Line(ReminderLabels.turnedOff),
            },
          ),
        ),
      ),
    );
  }
}

class _Offer extends StatelessWidget {
  const _Offer({
    required this.time,
    required this.asking,
    required this.onAccept,
    required this.onLater,
  });

  final ReminderTime time;
  final bool asking;
  final VoidCallback onAccept;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            ReminderLabels.offerTitle,
            style: context.text.titleMedium,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          ReminderLabels.offerBody(time),
          style: context.text.bodyMedium?.copyWith(color: t.text2),
        ),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.surfaceStrong,
                foregroundColor: t.text,
                minimumSize: const Size(120, 48),
              ),
              onPressed: asking ? null : onAccept,
              child: const Text(ReminderLabels.accept),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: t.text2,
                minimumSize: const Size(48, 48),
              ),
              onPressed: asking ? null : onLater,
              child: const Text(ReminderLabels.later),
            ),
          ],
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.bodyMedium?.copyWith(color: context.tokens.text2),
  );
}
