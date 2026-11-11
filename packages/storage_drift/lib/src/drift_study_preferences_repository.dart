import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/src/database.dart';

/// The learner's study options in the `settings` table, one row per option
/// (key → stored name of the value).
final class DriftStudyPreferencesRepository
    implements StudyPreferencesRepository {
  DriftStudyPreferencesRepository(this._db);

  final ShioriDatabase _db;

  static const String recordModeKey = 'study.record_mode';
  static const String scopeModeKey = 'study.scope_mode';

  /// The study mode picked last. Kept only when it is not 뜻 맞히기 (the
  /// default), so a file that never left it holds the same two rows as one
  /// from before modes.
  static const String modeKey = 'study.mode';

  /// A value this build does not know (a newer app wrote it) reads as the
  /// default and is left in the row.
  @override
  Future<StudyPreferences> load() async {
    final s = _db.settings;
    final rows = await (_db.select(
      s,
    )..where((r) => r.key.isIn([recordModeKey, scopeModeKey, modeKey]))).get();
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
    );
  }

  @override
  Future<void> save(StudyPreferences preferences) => _db.batch((b) {
    final mode = preferences.mode;
    b.insertAllOnConflictUpdate(_db.settings, [
      SettingsCompanion.insert(
        key: recordModeKey,
        value: preferences.recordMode.storedAs,
      ),
      SettingsCompanion.insert(
        key: scopeModeKey,
        value: preferences.scopeMode.storedAs,
      ),
      if (mode != StudyMode.meaning)
        SettingsCompanion.insert(key: modeKey, value: mode.name),
    ]);
    if (mode == StudyMode.meaning) {
      b.deleteWhere(_db.settings, (r) => r.key.equals(modeKey));
    }
  });
}
