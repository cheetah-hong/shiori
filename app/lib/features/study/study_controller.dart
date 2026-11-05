import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori_core/shiori_core.dart';

/// Holds one study session. The argument limits it to a textbook (null = all).
final class StudyController extends AsyncNotifier<StudySession> {
  StudyController(this.textbookId);

  final String? textbookId;
  bool _answering = false;

  @override
  Future<StudySession> build() =>
      ref.read(studyServiceProvider).startSession(textbookId: textbookId);

  Future<void> answer(Answer answer) async {
    final session = state.value;
    if (_answering || session == null || session.isFinished) return;
    _answering = true;
    try {
      final next = await AsyncValue.guard(
        () => ref.read(studyServiceProvider).answer(session, answer),
      );
      if (!ref.mounted) return;
      state = next;
      ref.read(dataRevisionProvider.notifier).bump();
    } finally {
      _answering = false;
    }
  }

  /// Interval the 알고있음 button shows for [item].
  Duration previewKnown(SessionItem item) =>
      ref.read(studyServiceProvider).previewKnown(item);
}

final studyControllerProvider = AsyncNotifierProvider.autoDispose
    .family<StudyController, StudySession, String?>(StudyController.new);
