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

  /// A value this build does not know (a newer app wrote it) reads as the
  /// default and is left in the row.
  @override
  Future<StudyPreferences> load() async {
    final s = _db.settings;
    final rows = await (_db.select(
      s,
    )..where((r) => r.key.isIn([recordModeKey, scopeModeKey]))).get();
    final stored = {for (final r in rows) r.key: r.value};
    const defaults = StudyPreferences();
    return StudyPreferences(
      recordMode:
          RecordMode.fromStored(stored[recordModeKey] ?? '') ??
          defaults.recordMode,
      scopeMode:
          StudyScopeMode.fromStored(stored[scopeModeKey] ?? '') ??
          defaults.scopeMode,
    );
  }

  @override
  Future<void> save(StudyPreferences preferences) => _db.batch(
    (b) => b.insertAllOnConflictUpdate(_db.settings, [
      SettingsCompanion.insert(
        key: recordModeKey,
        value: preferences.recordMode.storedAs,
      ),
      SettingsCompanion.insert(
        key: scopeModeKey,
        value: preferences.scopeMode.storedAs,
      ),
    ]),
  );
}
