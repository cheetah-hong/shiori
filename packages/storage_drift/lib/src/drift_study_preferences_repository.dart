import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/src/database.dart';

/// The learner's study options in the `settings` table, one row per option
/// (key → stored name of the value).
final class DriftStudyPreferencesRepository
    implements StudyPreferencesRepository {
  DriftStudyPreferencesRepository(this._db);

  final ShioriDatabase _db;

  static const String recordModeKey = StudySettingKeys.recordMode;
  static const String scopeModeKey = StudySettingKeys.scopeMode;

  /// The study mode picked last. Kept only when it is not 뜻 맞히기 (the
  /// default), so a file that never left it holds the same two rows as one
  /// from before modes.
  static const String modeKey = StudySettingKeys.mode;

  /// 하루 목표, kept only when it is not 10 (the default).
  static const String dailyGoalKey = StudySettingKeys.dailyGoal;

  /// 카드 순서 섞기, kept only when off (`off`); on is the default.
  static const String shuffleKey = StudySettingKeys.shuffle;
  static const String _shuffleOff = StudySettingKeys.shuffleOff;

  static const _keys = StudySettingKeys.all;

  /// A value this build does not know (a newer app wrote it) reads as the
  /// default and is left in the row.
  @override
  Future<StudyPreferences> load() async {
    final s = _db.settings;
    final rows = await (_db.select(s)..where((r) => r.key.isIn(_keys))).get();
    final stored = {for (final r in rows) r.key: r.value};
    const defaults = StudyPreferences();
    return StudyPreferences(
      recordMode:
          RecordMode.fromStored(stored[recordModeKey] ?? '') ??
          defaults.recordMode,
      scopeMode:
          StudyScopeMode.fromStored(stored[scopeModeKey] ?? '') ??
          defaults.scopeMode,
      mode: StudyMode.values.asNameMap()[stored[modeKey]] ?? defaults.mode,
      dailyGoal:
          DailyGoal.fromStored(stored[dailyGoalKey] ?? '') ??
          defaults.dailyGoal,
      shuffle: switch (stored[shuffleKey]) {
        _shuffleOff => false,
        _ => defaults.shuffle,
      },
    );
  }

  @override
  Future<void> save(StudyPreferences preferences) => _db.batch((b) {
    const defaults = StudyPreferences();
    // Options left at their default keep no row (a file from before they
    // existed holds the same rows).
    final optional = {
      modeKey: preferences.mode == defaults.mode ? null : preferences.mode.name,
      dailyGoalKey: preferences.dailyGoal == defaults.dailyGoal
          ? null
          : preferences.dailyGoal.storedAs,
      shuffleKey: preferences.shuffle == defaults.shuffle ? null : _shuffleOff,
    };
    b.insertAllOnConflictUpdate(_db.settings, [
      SettingsCompanion.insert(
        key: recordModeKey,
        value: preferences.recordMode.storedAs,
      ),
      SettingsCompanion.insert(
        key: scopeModeKey,
        value: preferences.scopeMode.storedAs,
      ),
      for (final MapEntry(:key, :value) in optional.entries)
        if (value != null) SettingsCompanion.insert(key: key, value: value),
    ]);
    final unset = [
      for (final MapEntry(:key, :value) in optional.entries)
        if (value == null) key,
    ];
    if (unset.isNotEmpty) {
      b.deleteWhere(_db.settings, (r) => r.key.isIn(unset));
    }
  });
}
