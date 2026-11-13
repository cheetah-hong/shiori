import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/playlists/playlist_actions.dart';
import 'package:shiori/features/words/word_data.dart';
import 'package:shiori/features/words/word_form.dart';
import 'package:shiori/features/words/word_labels.dart';
import 'package:shiori/shared/adaptive_dialog.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori/shared/keep_words.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// 단어 고치기 for [word], in a bottom sheet. What happened is said on the
/// screen under it ([context]'s), with 되돌리기.
Future<void> showWordEditor(BuildContext context, Word word) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => WordEditorSheet(word: word, messenger: messenger),
  );
}

class WordEditorSheet extends ConsumerStatefulWidget {
  const WordEditorSheet({
    super.key,
    required this.word,
    required this.messenger,
  });

  final Word word;

  /// Where the result is said once the sheet is gone.
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<WordEditorSheet> createState() => _WordEditorSheetState();
}

class _WordEditorSheetState extends ConsumerState<WordEditorSheet> {
  late final _form = WordFormController(WordEdit.of(widget.word));
  bool _reset = false;
  bool _busy = false;

  /// The dictionary has nothing for the headword (after 사전에서 다시 찾기).
  bool _notFound = false;

  Word get _word => widget.word;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  bool get _keyChanged {
    final head = _form.headword.text;
    return headwordProblem(head) == null && wordKey(head.trim()) != _word.key;
  }

  bool _studied(Map<StudyMode, Map<String, ReviewCard>>? cards) =>
      cards?.values.any((c) => c.containsKey(_word.id)) ?? false;

  Future<void> _refill() async {
    final WordFill fill;
    try {
      fill = await ref.read(wordFillerProvider)(_form.headword.text);
    } on Exception catch (e, stack) {
      debugPrint('dictionary lookup for an edit: $e\n$stack');
      say(widget.messenger, WordLabels.refillFailed);
      return;
    }
    if (!mounted) return;
    _form.applyFill(fill);
    setState(() => _notFound = !fill.found && fill.meanings.isEmpty);
  }

  Future<void> _save() async {
    final library = ref.read(libraryServiceProvider);
    final study = ref.read(studyServiceProvider);
    final revision = ref.read(dataRevisionProvider.notifier);
    final messenger = widget.messenger;
    final reset =
        _reset && _keyChanged && _studied(ref.read(cardsByModeProvider).value);
    setState(() => _busy = true);
    try {
      final edited = await library.editWord(_word.id, _form.value);
      var removed = const <ReviewCard>[];
      var resetFailed = false;
      if (reset) {
        try {
          removed = await study.resetWords([_word.id]);
        } on Exception catch (e, stack) {
          debugPrint('reset after an edit: $e\n$stack');
          resetFailed = true;
        }
      }
      revision.bump();
      if (mounted) Navigator.of(context).pop();
      _saidEdited(
        messenger,
        library,
        study,
        revision,
        edited,
        removed,
        resetFailed: resetFailed,
      );
    } on WordKeyTakenException catch (e) {
      if (mounted) await _askReplace(e.existing);
    } on LibraryException catch (e) {
      say(messenger, e.message);
    } on Exception catch (e, stack) {
      debugPrint('word edit failed: $e\n$stack');
      say(messenger, WordLabels.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _saidEdited(
    ScaffoldMessengerState messenger,
    LibraryService library,
    StudyService study,
    DataRevision revision,
    WordEdited edited,
    List<ReviewCard> removed, {
    required bool resetFailed,
  }) => say(
    messenger,
    resetFailed
        ? WordLabels.editedResetFailed(edited.before.headword)
        : WordLabels.edited(edited.before.headword),
    action: SnackBarAction(
      label: HideLabels.undo,
      onPressed: () async {
        // The cards first: they go with the word's id whatever it says, so
        // if putting the word back then fails, only that is left undone.
        final done = await guarded(messenger, WordLabels.undoFailed, () async {
          if (removed.isNotEmpty) await study.restoreCards(removed);
          await library.undoEdit(edited);
        });
        if (done) revision.bump();
      },
    ),
  );

  /// The headword names [existing]: 저장된 단어로 바꾸기, or back to the form.
  Future<void> _askReplace(Word existing) async {
    final library = ref.read(libraryServiceProvider);
    final revision = ref.read(dataRevisionProvider.notifier);
    final messenger = widget.messenger;
    final lists = await ref.read(wordPlaylistNamesProvider(_word.id).future);
    if (!mounted) return;
    final replace = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialog) =>
          _TakenDialog(existing: existing, lists: lists.length),
    );
    if (replace != true) return;
    Replacement? done;
    if (!await guarded(
      messenger,
      WordLabels.saveFailed,
      () async =>
          done = await library.replaceWithExisting(_word.id, existing.id),
    )) {
      return;
    }
    revision.bump();
    if (mounted) Navigator.of(context).pop();
    final replacement = done;
    if (replacement == null) return;
    say(
      messenger,
      WordLabels.replaced,
      action: SnackBarAction(
        label: HideLabels.undo,
        onPressed: () async {
          if (await guarded(
            messenger,
            WordLabels.undoFailed,
            () => library.undoReplace(replacement),
          )) {
            revision.bump();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final studied = _studied(ref.watch(cardsByModeProvider).value);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.xl + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: ListenableBuilder(
          listenable: _form,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WordSheetHead(
                title: WordLabels.editTitle,
                primary: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 44),
                  ),
                  onPressed: _form.canSave && !_busy ? _save : null,
                  child: const Text(WordLabels.save),
                ),
              ),
              const SizedBox(height: Space.lg),
              WordFormFields(
                form: _form,
                headwordHelp: _notFound ? WordLabels.notInDictionary : null,
                belowHeadword: _keyChanged && studied
                    ? _KeyNote(
                        reset: _reset,
                        onChanged: (on) => setState(() => _reset = on),
                      )
                    : null,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _busy ? null : _refill,
                  child: const Text(WordLabels.refill),
                ),
              ),
              if (_word.isHidden)
                Text(
                  WordLabels.hiddenNote,
                  style: context.text.bodySmall?.copyWith(color: t.text3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The headword now names another word: its record stays, unless the
/// learner starts it again.
class _KeyNote extends StatelessWidget {
  const _KeyNote({required this.reset, required this.onChanged});

  final bool reset;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          WordLabels.keyChanges,
          style: context.text.bodyMedium?.copyWith(color: context.tokens.text2),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(WordLabels.resetRecord),
          value: reset,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

/// 이미 저장한 단어예요: the stored word, and what replacing does.
class _TakenDialog extends StatelessWidget {
  const _TakenDialog({required this.existing, required this.lists});

  final Word existing;

  /// Playlists that hold the word being changed.
  final int lists;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog.adaptive(
      title: const CappedText(
        max: TextCaps.chrome,
        child: KeepWordsText(WordLabels.taken),
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: Space.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            JpText(
              '${existing.headword}  ${readingsLabel(existing.readings)}',
              textAlign: TextAlign.center,
              style: JpType.body(TypeScale.body, t.text),
            ),
            Text(existing.meaning, textAlign: TextAlign.center),
            const SizedBox(height: Space.sm),
            Text(WordLabels.takenBody(lists), textAlign: TextAlign.center),
          ],
        ),
      ),
      actions: [
        adaptiveDialogAction(
          context,
          label: WordLabels.cancel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        adaptiveDialogAction(
          context,
          label: WordLabels.replace,
          isDefault: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
