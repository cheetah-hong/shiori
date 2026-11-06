/// How learning records relate to playlists.
enum RecordMode {
  /// One record per word, shared by every playlist that holds it (default).
  shared('shared'),

  /// A record per word in each playlist. Not built yet: the setting can be
  /// stored, but study works as [shared] (docs/architecture.md).
  perPlaylist('per_playlist');

  const RecordMode(this.storedAs);

  /// The value kept in storage.
  final String storedAs;

  /// The mode stored as [value]; null when this build does not know it.
  static RecordMode? fromStored(String value) {
    for (final m in values) {
      if (m.storedAs == value) return m;
    }
    return null;
  }
}

/// What the learner picks when starting to study.
enum StudyScopeMode {
  /// Review everything, or pick one playlist to study (default).
  allOrPlaylist('all_or_playlist'),

  /// Always one playlist at a time. Not built yet: stored only.
  playlistOnly('playlist_only');

  const StudyScopeMode(this.storedAs);

  final String storedAs;

  static StudyScopeMode? fromStored(String value) {
    for (final m in values) {
      if (m.storedAs == value) return m;
    }
    return null;
  }
}

/// The learner's study options (설정), stored by
/// `StudyPreferencesRepository`. Unlike `StudySettings` (intervals, day
/// start, session size: constants for now) these are the learner's choices.
final class StudyPreferences {
  const StudyPreferences({
    this.recordMode = RecordMode.shared,
    this.scopeMode = StudyScopeMode.allOrPlaylist,
  });

  final RecordMode recordMode;
  final StudyScopeMode scopeMode;

  StudyPreferences copyWith({
    RecordMode? recordMode,
    StudyScopeMode? scopeMode,
  }) => StudyPreferences(
    recordMode: recordMode ?? this.recordMode,
    scopeMode: scopeMode ?? this.scopeMode,
  );

  @override
  bool operator ==(Object other) =>
      other is StudyPreferences &&
      other.recordMode == recordMode &&
      other.scopeMode == scopeMode;

  @override
  int get hashCode => Object.hash(recordMode, scopeMode);

  @override
  String toString() => 'StudyPreferences($recordMode, $scopeMode)';
}
