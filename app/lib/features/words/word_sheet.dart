import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/playlists/mode_meters.dart';
import 'package:shiori/features/playlists/playlist_actions.dart';
import 'package:shiori/features/words/word_data.dart';
import 'package:shiori/features/words/word_editor_sheet.dart';
import 'package:shiori/features/words/word_labels.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/states.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// A saved word in a bottom sheet: its content, the playlists that hold it,
/// whether it is hidden, its level in every way of studying, and 고치기.
Future<void> showWordSheet(BuildContext context, {required String wordId}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => WordSheet(wordId: wordId, screen: context),
    );

class WordSheet extends ConsumerWidget {
  const WordSheet({super.key, required this.wordId, required this.screen});

  final String wordId;

  /// The screen under the sheet: the editor and its messages open there.
  final BuildContext screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final word = ref.watch(wordProvider(wordId));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        // Clear of the home indicator.
        Space.xl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: switch (word) {
        AsyncData(value: final w?) => _Body(word: w, screen: screen),
        AsyncData() => const SizedBox.shrink(),
        AsyncError(:final error) => LoadFailure(
          message: '단어를 불러오지 못했어요',
          onRetry: () {
            debugPrint('word sheet failed: $error');
            ref.invalidate(wordProvider(wordId));
          },
        ),
        _ => const Loading(),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.word, required this.screen});

  final Word word;
  final BuildContext screen;

  void _edit(BuildContext context) {
    Navigator.of(context).pop();
    if (screen.mounted) showWordEditor(screen, word);
  }

  void _show(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(screen);
    Navigator.of(context).pop();
    setWordHidden(
      messenger: messenger,
      library: ref.read(libraryServiceProvider),
      revision: ref.read(dataRevisionProvider.notifier),
      word: word,
      hidden: false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final cards = ref.watch(cardsByModeProvider).value ?? const {};
    final mode = ref.watch(studyModeProvider).value ?? StudyMode.meaning;
    final max = ref.watch(reviewSchedulerProvider).maxLevel;
    final lists = ref.watch(wordPlaylistNamesProvider(word.id)).value;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: JpText(
                  word.headword,
                  style: JpType.headword(TypeScale.display, t.text),
                ),
              ),
              CappedText(
                max: TextCaps.chrome,
                child: TextButton(
                  onPressed: () => _edit(context),
                  child: const Text(WordLabels.edit),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              JpText(
                readingsLabel(word.readings),
                style: JpType.body(TypeScale.body2, t.text2),
              ),
              if (word.pos case final pos?)
                Text(
                  pos.label,
                  style: context.text.bodySmall?.copyWith(color: t.text3),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(word.meaning, style: context.text.bodyLarge),
          if (lists != null && lists.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(
              lists.join(' · '),
              style: context.text.bodySmall?.copyWith(color: t.text3),
            ),
          ],
          if (word.isHidden)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      WordLabels.hiddenNote,
                      style: context.text.bodyMedium?.copyWith(color: t.text2),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _show(context, ref),
                    child: Semantics(
                      label: HideLabels.restoreWord(word.headword),
                      child: const ExcludeSemantics(
                        child: Text(HideLabels.restore),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.md),
          for (final (i, m) in StudyMode.values.indexed)
            ModeLevelRow(
              mode: m,
              level: cards[m]?[word.id]?.level ?? 0,
              max: max,
              isCurrent: m == mode,
              first: i == 0,
            ),
        ],
      ),
    );
  }
}
