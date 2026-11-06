import 'package:shiori_core/src/models/study_preferences.dart';

/// Block slot: the learner's study options (설정).
///
/// Blocks: `InMemoryStudyPreferencesRepository` (tests),
/// `DriftStudyPreferencesRepository` (app).
abstract interface class StudyPreferencesRepository {
  /// The stored options. A missing or unknown value reads as its default
  /// (stored values a newer app wrote are not an error).
  Future<StudyPreferences> load();

  Future<void> save(StudyPreferences preferences);
}
