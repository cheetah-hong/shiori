import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/file_nudge_store.dart';
import 'package:shiori_core/shiori_core.dart';

/// This device's choices about reminders and haptics.
///
/// Kept out of the learning database on purpose: notification permission
/// belongs to the device, so a backup restored on another device must not
/// turn reminders on there (and the backup format stays as it is).
@immutable
final class NudgeSettings {
  const NudgeSettings({
    this.remindersOn = false,
    this.reminderTime,
    this.offered = false,
    this.haptics = true,
    this.swipeHinted = false,
  });

  /// 복습 알림 is on (it still needs the system's permission).
  final bool remindersOn;

  /// When the reminder comes; null until one is picked or offered.
  final ReminderTime? reminderTime;

  /// The reminder offer after a session has been shown (it is shown once).
  final bool offered;

  /// 햅틱: light taps when answering.
  final bool haptics;

  /// The line about swiping a card has been shown and need not come again.
  final bool swipeHinted;

  /// [reminderTime], or 21:00 when none was picked.
  ReminderTime get timeOrDefault => reminderTime ?? ReminderTime.evening;

  NudgeSettings copyWith({
    bool? remindersOn,
    ReminderTime? reminderTime,
    bool? offered,
    bool? haptics,
    bool? swipeHinted,
  }) => NudgeSettings(
    remindersOn: remindersOn ?? this.remindersOn,
    reminderTime: reminderTime ?? this.reminderTime,
    offered: offered ?? this.offered,
    haptics: haptics ?? this.haptics,
    swipeHinted: swipeHinted ?? this.swipeHinted,
  );

  @override
  bool operator ==(Object other) =>
      other is NudgeSettings &&
      other.remindersOn == remindersOn &&
      other.reminderTime == reminderTime &&
      other.offered == offered &&
      other.haptics == haptics &&
      other.swipeHinted == swipeHinted;

  @override
  int get hashCode =>
      Object.hash(remindersOn, reminderTime, offered, haptics, swipeHinted);

  @override
  String toString() =>
      'NudgeSettings(on: $remindersOn, time: $reminderTime, offered: '
      '$offered, haptics: $haptics, swipeHinted: $swipeHinted)';
}

/// Where [NudgeSettings] are kept.
abstract interface class NudgeStore {
  /// The stored settings; the defaults when there are none.
  Future<NudgeSettings> load();

  Future<void> save(NudgeSettings settings);
}

/// Kept in memory only (tests, previews).
final class InMemoryNudgeStore implements NudgeStore {
  InMemoryNudgeStore([this.settings = const NudgeSettings()]);

  NudgeSettings settings;

  @override
  Future<NudgeSettings> load() async => settings;

  @override
  Future<void> save(NudgeSettings settings) async => this.settings = settings;
}

/// Where the settings are kept: a file in the app support folder.
final nudgeStoreProvider = Provider<NudgeStore>(
  (ref) => FileNudgeStore.appSupport(),
);

/// The settings in use. When they cannot be read: a reminder off, haptics
/// on, and neither the offer nor the swipe line shown.
final nudgeSettingsProvider =
    AsyncNotifierProvider<NudgeSettingsNotifier, NudgeSettings>(
      NudgeSettingsNotifier.new,
    );

/// What is used when the file cannot be read: reminders off, and the offer
/// and the swipe line counted as shown (a device that cannot keep the
/// answer is not asked again and again).
const NudgeSettings _unreadable = NudgeSettings(
  offered: true,
  swipeHinted: true,
);

final class NudgeSettingsNotifier extends AsyncNotifier<NudgeSettings> {
  @override
  Future<NudgeSettings> build() async {
    try {
      return await ref.watch(nudgeStoreProvider).load();
    } on Exception catch (e, stack) {
      debugPrint('nudge settings not read, defaults used: $e\n$stack');
      return _unreadable;
    }
  }

  /// Changes made one after another, so none is lost and the file is
  /// written by one at a time.
  Future<void> _queue = Future.value();

  /// Stores [change] of the current settings and shows it. Changes asked
  /// for at the same time apply in turn, each to the one before. A failed
  /// write is thrown, and the settings on screen stay as they were.
  Future<void> change(NudgeSettings Function(NudgeSettings) change) {
    final run = _queue.then((_) async {
      final next = change(await future);
      await ref.read(nudgeStoreProvider).save(next);
      state = AsyncData(next);
    });
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }
}
