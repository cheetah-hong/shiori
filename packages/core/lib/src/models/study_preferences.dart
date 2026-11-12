import 'package:shiori_core/src/models/study_mode.dart';
import 'package:shiori_core/src/study/session_size.dart';

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

/// How many cards 홈's 오늘 학습 and 더 학습하기 take (설정 › 하루 목표).
/// A playlist always studies every card it can.
enum DailyGoal {
  ten(10, '10'),
  twenty(20, '20'),
  thirty(30, '30'),
  fifty(50, '50'),

  /// Every card that can be studied.
  all(null, 'all');

  const DailyGoal(this.cards, this.storedAs);

  /// Cards per session; null for every card.
  final int? cards;

  /// The value kept in storage.
  final String storedAs;

  SessionSize get size => switch (cards) {
    final n? => UpTo(n),
    null => const AllCards(),
  };

  /// The goal stored as [value]; null when this build does not know it.
  static DailyGoal? fromStored(String value) {
    for (final g in values) {
      if (g.storedAs == value) return g;
    }
    return null;
  }
}

/// The learner's study options (설정), stored by
/// `StudyPreferencesRepository`. Unlike `StudySettings` (intervals, day
/// start: constants for now) these are the learner's choices.
final class StudyPreferences {
  const StudyPreferences({
    this.recordMode = RecordMode.shared,
    this.scopeMode = StudyScopeMode.allOrPlaylist,
    this.mode = StudyMode.meaning,
    this.dailyGoal = DailyGoal.ten,
    this.shuffle = true,
  });

  final RecordMode recordMode;
  final StudyScopeMode scopeMode;

  /// The way of studying picked last (홈·재생목록 chips).
  final StudyMode mode;

  /// How many cards 홈 studies at a time.
  final DailyGoal dailyGoal;

  /// 카드 순서 섞기: a session's cards (reviews and new words together)
  /// come in a random order.
  final bool shuffle;

  StudyPreferences copyWith({
    RecordMode? recordMode,
    StudyScopeMode? scopeMode,
    StudyMode? mode,
    DailyGoal? dailyGoal,
    bool? shuffle,
  }) => StudyPreferences(
    recordMode: recordMode ?? this.recordMode,
    scopeMode: scopeMode ?? this.scopeMode,
    mode: mode ?? this.mode,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    shuffle: shuffle ?? this.shuffle,
  );

  @override
  bool operator ==(Object other) =>
      other is StudyPreferences &&
      other.recordMode == recordMode &&
      other.scopeMode == scopeMode &&
      other.mode == mode &&
      other.dailyGoal == dailyGoal &&
      other.shuffle == shuffle;

  @override
  int get hashCode =>
      Object.hash(recordMode, scopeMode, mode, dailyGoal, shuffle);

  @override
  String toString() =>
      'StudyPreferences($recordMode, $scopeMode, $mode, $dailyGoal, '
      'shuffle: $shuffle)';
}
