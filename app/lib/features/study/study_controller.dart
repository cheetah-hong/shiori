import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori_core/shiori_core.dart';

/// What a study screen studies: [scope] (전체 or one playlist), today's
/// cards or, with [more], cards brought forward (더 학습하기), in [mode].
typedef StudyRequest = ({StudyScope scope, bool more, StudyMode mode});

/// Holds one study session for a [StudyRequest].
final class StudyController extends AsyncNotifier<StudySession> {
  StudyController(this.request);

  final StudyRequest request;

  /// A write is on its way; presses meanwhile are ignored.
  bool _busy = false;

  /// The session holds as many cards as [StudyService.sessionSizeFor] says
  /// for the request's scope and the stored daily goal, shuffled when 카드
  /// 순서 섞기 is on. The order stays for the session's life.
  @override
  Future<StudySession> build() async {
    final service = ref.read(studyServiceProvider);
    final preferences = await _preferences();
    final size = service.sessionSizeFor(request.scope, preferences.dailyGoal);
    return request.more
        ? service.startMoreSession(
            scope: request.scope,
            mode: request.mode,
            size: size,
            shuffle: preferences.shuffle,
          )
        : service.startSession(
            scope: request.scope,
            mode: request.mode,
            size: size,
            shuffle: preferences.shuffle,
          );
  }

  /// The stored options; their defaults when they cannot be read, so
  /// studying never waits on the settings.
  Future<StudyPreferences> _preferences() async {
    try {
      return await ref.read(studyPreferencesProvider.future);
    } on Exception catch (e, stack) {
      debugPrint('study options not read, defaults used: $e\n$stack');
      return const StudyPreferences();
    }
  }

  /// A write (an answer, a hide, an undo) is on its way.
  bool get isBusy => _busy;

  /// Stores [answer] for the current card; true when it was stored (false
  /// when ignored while another write is on its way, or when it failed).
  Future<bool> answer(Answer answer) async {
    final session = state.value;
    if (_busy || session == null || session.isFinished) return false;
    _busy = true;
    try {
      final next = await AsyncValue.guard(
        () => ref.read(studyServiceProvider).answer(session, answer),
      );
      if (!ref.mounted) return false;
      state = next;
      ref.read(dataRevisionProvider.notifier).bump();
      return !next.hasError;
    } finally {
      _busy = false;
    }
  }

  /// 이미 알아요: hides the current card's word and shows the next card.
  /// Returns the hidden card (for 되돌리기), or null when nothing was hidden.
  /// A failed write is thrown and the session stays as it was.
  Future<SessionItem?> hide() async {
    final session = state.value;
    final item = session?.current;
    if (_busy || session == null || item == null) return null;
    return _write(() => ref.read(studyServiceProvider).hide(session), item);
  }

  /// 되돌리기: shows [item]'s word again and puts it back as the current card.
  Future<void> unhide(SessionItem item) async {
    final session = state.value;
    if (_busy || session == null) return;
    await _write(
      () => ref.read(studyServiceProvider).unhide(session, item),
      item,
    );
  }

  Future<SessionItem?> _write(
    Future<StudySession> Function() write,
    SessionItem item,
  ) async {
    _busy = true;
    try {
      final next = await write();
      if (!ref.mounted) return null;
      state = AsyncData(next);
      ref.read(dataRevisionProvider.notifier).bump();
      return item;
    } finally {
      _busy = false;
    }
  }

  /// The multiple-choice question of [session]'s current card (객관식,
  /// 듣고 맞히기); null otherwise.
  MultipleChoice? questionFor(StudySession session) =>
      ref.read(studyServiceProvider).questionFor(session);

  /// Interval the 알고있음 button shows for [item].
  Duration previewKnown(SessionItem item) =>
      ref.read(studyServiceProvider).previewKnown(item);
}

final studyControllerProvider = AsyncNotifierProvider.autoDispose
    .family<StudyController, StudySession, StudyRequest>(StudyController.new);

/// Today's counts for [scope] (what is due, new and can be brought forward).
AsyncValue<StudySummary> watchStudySummary(WidgetRef ref, StudyScope scope) =>
    switch (scope) {
      AllWords() => ref.watch(homeSummaryProvider),
      PlaylistOnly(:final playlistId) => ref.watch(
        playlistSummaryProvider(playlistId),
      ),
    };
