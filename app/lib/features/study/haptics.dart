import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';

/// The study screen's light taps, one per act; none when 햅틱 is off. The
/// system plays none either when its own haptics are off.
final class Haptics {
  const Haptics({required this.enabled});

  final bool enabled;

  Future<void> _play(Future<void> Function() tap) async {
    if (enabled) await tap();
  }

  /// 알고있음 or 다시 학습 (a button, or a swipe crossing its threshold).
  Future<void> answer() => _play(HapticFeedback.selectionClick);

  /// 객관식 and 듣고 맞히기: the right option picked.
  Future<void> right() => _play(HapticFeedback.lightImpact);

  /// 객관식 and 듣고 맞히기: a wrong option picked.
  Future<void> wrong() => _play(HapticFeedback.mediumImpact);

  /// The session's end (오늘 학습 끝).
  Future<void> sessionEnd() => _play(HapticFeedback.successNotification);
}

/// On while the settings load or cannot be read.
final hapticsProvider = Provider<Haptics>(
  (ref) =>
      Haptics(enabled: ref.watch(nudgeSettingsProvider).value?.haptics ?? true),
);
