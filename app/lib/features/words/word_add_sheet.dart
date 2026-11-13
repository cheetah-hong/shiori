import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/playlists/playlist_actions.dart';
import 'package:shiori/features/playlists/playlist_picker.dart';
import 'package:shiori/features/words/word_data.dart';
import 'package:shiori/features/words/word_editor_sheet.dart';
import 'package:shiori/features/words/word_form.dart';
import 'package:shiori/features/words/word_labels.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/ruled.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// How long typing pauses before the headword is looked up.
const Duration lookupPause = Duration(milliseconds: 300);

/// 단어 추가: one word typed by hand into playlist [playlistId] (or, with
/// none, the one words were last added to), its empty fields filled from the
/// dictionary. [headword] starts the form (단어 찾기's 직접 추가).
Future<void> showWordAdder(
  BuildContext context, {
  String? playlistId,
  String headword = '',
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => WordAddSheet(
      playlistId: playlistId,
      headword: headword,
      messenger: messenger,
      screen: context,
    ),
  );
}

/// What the typed headword is.
sealed class _Lookup {
  const _Lookup();
}

/// Nothing to say yet (no headword, or one that cannot be a word).
final class _Nothing extends _Lookup {
  const _Nothing();
}

/// The library has the word: it is linked, not made again.
final class _Stored extends _Lookup {
  const _Stored(this.word, this.playlistIds, this.names);

  final Word word;
  final Set<String> playlistIds;
  final List<String> names;
}

/// A new word, with what the dictionary says about it.
final class _New extends _Lookup {
  const _New(this.fill);

  final WordFill fill;
}

class WordAddSheet extends ConsumerStatefulWidget {
  const WordAddSheet({
    super.key,
    required this.playlistId,
    required this.headword,
    required this.messenger,
    required this.screen,
  });

  final String? playlistId;
  final String headword;
  final ScaffoldMessengerState messenger;

  /// The screen under the sheet (where 저장된 단어 고치기 opens).
  final BuildContext screen;

  @override
  ConsumerState<WordAddSheet> createState() => _WordAddSheetState();
}

class _WordAddSheetState extends ConsumerState<WordAddSheet> {
  late final _form = WordFormController(
    WordEdit(headword: widget.headword, meaning: ''),
  );
  late String _asked = widget.headword;
  _Lookup _lookup = const _Nothing();
  AddTarget? _target;
  Timer? _pause;
  int _seq = 0;
  bool _busy = false;

  /// A lookup of the headword as it is now is still to come: what the form
  /// says may belong to the headword before, so nothing can be added yet.
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    _form.headword.addListener(_headwordChanged);
    if (widget.playlistId case final id?) _target = ExistingPlaylist(id);
    if (widget.headword.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_look(widget.headword));
      });
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    _form.dispose();
    super.dispose();
  }

  /// A new headword: whatever was found for the one before (a stored word,
  /// the dictionary's values, a lookup still running) goes at once, and the
  /// new one is looked up when typing pauses.
  void _headwordChanged() {
    final text = _form.headword.text;
    if (text == _asked) return;
    _asked = text;
    _seq++;
    _pause?.cancel();
    _form.clearFill();
    setState(() {
      _lookup = const _Nothing();
      _looking = headwordProblem(text) == null;
    });
    _pause = Timer(lookupPause, () => unawaited(_look(text)));
  }

  /// Looks [text] up now: the library first, then (unless [keepFill]: the
  /// form holds a kanji spelling the learner picked) the dictionary.
  Future<void> _look(String text, {bool keepFill = false}) async {
    final seq = ++_seq;
    if (!keepFill) _form.clearFill();
    if (headwordProblem(text) != null) {
      setState(() {
        _lookup = const _Nothing();
        _looking = false;
      });
      return;
    }
    setState(() => _looking = true);
    final library = ref.read(libraryRepositoryProvider);
    final key = wordKey(text.trim());
    try {
      final stored = (await library.wordsByKey([key]))[key];
      if (stored != null) {
        final ids = (await library.playlistsOf([stored.id]))[stored.id] ?? {};
        final names = await ref.read(
          wordPlaylistNamesProvider(stored.id).future,
        );
        if (!mounted || seq != _seq) return;
        setState(() {
          _lookup = _Stored(stored, ids, names);
          _looking = false;
        });
        return;
      }
      // A picked spelling keeps the reading and meaning it came with: asked
      // again by its kanji alone, the dictionary would give its most common
      // word (角 read かど, not the つの picked).
      final fill = keepFill
          ? const WordFill(found: true)
          : await ref.read(wordFillerProvider)(text);
      if (!mounted || seq != _seq) return;
      if (!keepFill) _form.applyFill(fill);
      setState(() {
        _lookup = _New(fill);
        _looking = false;
      });
    } on Exception catch (e, stack) {
      // The form still works by hand.
      debugPrint('word lookup failed: $e\n$stack');
      if (mounted && seq == _seq) {
        setState(() {
          _lookup = const _Nothing();
          _looking = false;
        });
      }
    }
  }

  void _choose(KanjiChoice choice) {
    _pause?.cancel();
    _asked = choice.headword;
    _form.useChoice(choice);
    unawaited(_look(choice.headword, keepFill: true));
  }

  /// The playlist the word goes to: the one picked, else the one the sheet
  /// opened from, else the one words were last added to, else a new one.
  AddTarget _targetOf(List<PlaylistStats> lists) {
    if (_target case final t?) return t;
    final used = [
      for (final s in lists)
        if (s.lastAddedAt != null) s,
    ]..sort((a, b) => b.lastAddedAt!.compareTo(a.lastAddedAt!));
    final pick = used.firstOrNull ?? lists.firstOrNull;
    return pick == null
        ? const NewPlaylist(defaultPlaylistName)
        : ExistingPlaylist(pick.playlist.id);
  }

  String _targetName(AddTarget target, List<PlaylistStats> lists) =>
      switch (target) {
        NewPlaylist(:final name) => WordLabels.newTarget(name),
        ExistingPlaylist(:final playlistId) =>
          lists
                  .where((s) => s.playlist.id == playlistId)
                  .firstOrNull
                  ?.playlist
                  .name ??
              '',
      };

  Future<void> _pickTarget() async {
    AddPreview? preview;
    final head = _form.headword.text;
    if (headwordProblem(head) == null) {
      try {
        preview = await ref.read(libraryServiceProvider).previewAdd([head]);
      } on Exception catch (e, stack) {
        debugPrint('preview for the word target: $e\n$stack');
      }
    }
    if (!mounted) return;
    final picked = await showPlaylistPicker(context, preview: preview);
    if (picked != null && mounted) setState(() => _target = picked);
  }

  Future<void> _add(AddTarget target) async {
    final library = ref.read(libraryServiceProvider);
    final revision = ref.read(dataRevisionProvider.notifier);
    final messenger = widget.messenger;
    final lookup = _lookup;
    setState(() => _busy = true);
    AddResult? result;
    final done = await guarded(
      messenger,
      WordLabels.addFailed,
      () async => result = switch (lookup) {
        _Stored(:final word) => await library.addWords([word.id], to: target),
        _ => await library.addWord(_form.value, to: target),
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!done) return;
    revision.bump();
    Navigator.of(context).pop();
    if (result case final r?) say(messenger, addedMessage(r));
  }

  void _editStored(Word word) {
    Navigator.of(context).pop();
    if (widget.screen.mounted) showWordEditor(widget.screen, word);
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(playlistsProvider).value ?? const [];
    final target = _targetOf(lists);
    final lookup = _lookup;
    final inTarget = switch ((lookup, target)) {
      (_Stored(:final playlistIds), ExistingPlaylist(:final playlistId)) =>
        playlistIds.contains(playlistId),
      _ => false,
    };
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
                title: WordLabels.addTitle,
                primary: switch (lookup) {
                  _Stored() when inTarget => null,
                  _Stored() => _Primary(
                    label: WordLabels.link,
                    onPressed: _busy || _looking ? null : () => _add(target),
                  ),
                  _ => _Primary(
                    label: WordLabels.add,
                    onPressed: _form.canSave && !_busy && !_looking
                        ? () => _add(target)
                        : null,
                  ),
                },
              ),
              const SizedBox(height: Space.lg),
              WordFormFields(
                form: _form,
                showDetails: lookup is! _Stored,
                headwordHelp: switch (lookup) {
                  _New(:final fill) when !fill.found && fill.meanings.isEmpty =>
                    WordLabels.notInDictionary,
                  _ => WordLabels.headwordHelp,
                },
                belowHeadword: switch (lookup) {
                  _Stored(:final word, :final names) => _StoredNote(
                    word: word,
                    names: names,
                    inTarget: inTarget,
                    onEdit: () => _editStored(word),
                  ),
                  _New(:final fill)
                      when fill.kanjiChoices.isNotEmpty &&
                          !_form.headword.text.runes.any(_isKanji) =>
                    _KanjiChoices(choices: fill.kanjiChoices, onPick: _choose),
                  _ => null,
                },
              ),
              const SizedBox(height: Space.lg),
              RuledRow(
                ruleAbove: true,
                onTap: _busy ? null : _pickTarget,
                child: Row(
                  children: [
                    Text(
                      WordLabels.target,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.tokens.text3,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(
                        _targetName(target, lists),
                        textAlign: TextAlign.end,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.tokens.accentText,
                          fontWeight: Weights.emphasis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isKanji(int c) =>
    (c >= 0x3400 && c <= 0x4DBF) || (c >= 0x4E00 && c <= 0x9FFF);

class _Primary extends StatelessWidget {
  const _Primary({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
    onPressed: onPressed,
    child: Text(label),
  );
}

/// The typed word is stored already: what it holds, and where.
class _StoredNote extends StatelessWidget {
  const _StoredNote({
    required this.word,
    required this.names,
    required this.inTarget,
    required this.onEdit,
  });

  final Word word;
  final List<String> names;
  final bool inTarget;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inTarget ? WordLabels.alreadyHere : WordLabels.stored,
            style: context.text.bodyLarge?.copyWith(
              fontWeight: Weights.emphasis,
            ),
          ),
          const SizedBox(height: Space.xs),
          JpText(
            readingsLabel(word.readings),
            style: JpType.body(TypeScale.body2, t.text2),
          ),
          Text(word.meaning, style: context.text.bodyLarge),
          const SizedBox(height: Space.xs),
          Text(
            names.isEmpty
                ? WordLabels.storedNowhere
                : WordLabels.storedIn(names.join(' · ')),
            style: context.text.bodySmall?.copyWith(color: t.text3),
          ),
          TextButton(
            onPressed: onEdit,
            child: const Text(WordLabels.editStored),
          ),
        ],
      ),
    );
  }
}

/// Kanji spellings of a headword typed in kana, each with its meaning.
class _KanjiChoices extends StatelessWidget {
  const _KanjiChoices({required this.choices, required this.onPick});

  final List<KanjiChoice> choices;
  final ValueChanged<KanjiChoice> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            WordLabels.kanjiChoices,
            style: context.text.labelLarge?.copyWith(color: t.text3),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final c in choices)
                ActionChip(
                  onPressed: () => onPick(c),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      JpText(
                        c.headword,
                        style: JpType.headword(TypeScale.body, t.text),
                      ),
                      if (c.meaning case final m?) ...[
                        const SizedBox(width: Space.xs),
                        Text(
                          m,
                          style: context.text.bodySmall?.copyWith(
                            color: t.text3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            WordLabels.keepKana,
            style: context.text.bodySmall?.copyWith(color: t.text3),
          ),
        ],
      ),
    );
  }
}
