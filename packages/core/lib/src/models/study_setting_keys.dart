import 'package:shiori_core/src/models/study_mode.dart';
import 'package:shiori_core/src/models/study_preferences.dart';

/// How the study options (`StudyPreferences`) are stored: one key → value
/// row per option. Shared by the settings storage and the backup file, so
/// both name the same keys and know the same values.
///
/// A new option means a new key here; a backup file carries only the keys
/// and values listed here, so a new key, or a new value of a key, also
/// means a new backup format version (`backupVersion`).
abstract final class StudySettingKeys {
  static const String recordMode = 'study.record_mode';
  static const String scopeMode = 'study.scope_mode';

  /// The study mode picked last; kept only when it is not 뜻 맞히기.
  static const String mode = 'study.mode';

  /// 하루 목표; kept only when it is not 10.
  static const String dailyGoal = 'study.daily_goal';

  /// 카드 순서 섞기; kept only when off ([shuffleOff]).
  static const String shuffle = 'study.shuffle';

  /// The stored value of [shuffle] when it is off.
  static const String shuffleOff = 'off';

  static const List<String> all = [
    recordMode,
    scopeMode,
    mode,
    dailyGoal,
    shuffle,
  ];

  /// Whether [key] is one of [all] and [value] one this build stores for it.
  static bool isKnown(String key, String value) => switch (key) {
    recordMode => RecordMode.fromStored(value) != null,
    scopeMode => StudyScopeMode.fromStored(value) != null,
    mode => StudyMode.values.asNameMap().containsKey(value),
    dailyGoal => DailyGoal.fromStored(value) != null,
    shuffle => value == shuffleOff,
    _ => false,
  };
}
