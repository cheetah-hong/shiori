import 'package:shiori_core/src/models/study_preferences.dart';
import 'package:shiori_core/src/ports/study_preferences_repository.dart';

/// Keeps the study options in memory. Used by tests; the app stores them in
/// SQLite (`packages/storage_drift`).
final class InMemoryStudyPreferencesRepository
    implements StudyPreferencesRepository {
  StudyPreferences _stored = const StudyPreferences();

  @override
  Future<StudyPreferences> load() async => _stored;

  @override
  Future<void> save(StudyPreferences preferences) async =>
      _stored = preferences;
}
