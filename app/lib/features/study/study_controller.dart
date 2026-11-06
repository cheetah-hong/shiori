import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori_core/shiori_core.dart';

/// Holds one study session over [scope] (전체 or one playlist).
final class StudyController extends AsyncNotifier<StudySession> {
  StudyController(this.scope);

  final StudyScope scope;

  /// A write is on its way; presses meanwhile are ignored.
  bool _busy = false;

  @override
  Future<StudySession> build() =>
      ref.read(studyServiceProvider).startSession(scope: scope);

  Future<void> answer(Answer answer) async {
    final session = state.value;
    if (_busy || session == null || session.isFinished) return;
    _busy = true;
    try {
      final next = await AsyncValue.guard(
        () => ref.read(studyServiceProvider).answer(session, answer),
      );
      if (!ref.mounted) return;
      state = next;
      ref.read(dataRevisionProvider.notifier).bump();
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

  /// Interval the 알고있음 button shows for [item].
  Duration previewKnown(SessionItem item) =>
      ref.read(studyServiceProvider).previewKnown(item);
}

final studyControllerProvider = AsyncNotifierProvider.autoDispose
    .family<StudyController, StudySession, StudyScope>(StudyController.new);
