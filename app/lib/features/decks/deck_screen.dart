import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/decks/deck_data.dart';
import 'package:shiori/features/decks/deck_parts.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/shared/adaptive_dialog.dart';
import 'package:shiori/shared/bottom_action_bar.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori/shared/ruled.dart';
import 'package:shiori/shared/states.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// Words shown before adding.
const int _previewWords = 30;

/// Where adding a deck is.
sealed class _Phase {
  const _Phase();
}

final class _Idle extends _Phase {
  const _Idle();
}

final class _Adding extends _Phase {
  const _Adding(this.done, this.total);

  final int done;
  final int total;
}

final class _Added extends _Phase {
  const _Added(this.result, this.withoutMeaning);

  final AddResult result;
  final int withoutMeaning;
}

/// One built-in deck: its word count, the first words, and adding it as a
/// playlist of its name (again: only the words that playlist is missing).
class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key, required this.deckId});

  final String deckId;

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  _Phase _phase = const _Idle();

  @override
  Widget build(BuildContext context) {
    final decks = ref.watch(builtinDecksProvider);
    final lists = ref.watch(playlistsProvider).value ?? const [];
    final set = decks.value;
    final deck = set?.decks.where((d) => d.id == widget.deckId).firstOrNull;
    if (set == null || deck == null) {
      return Scaffold(
        appBar: AppBar(),
        body: switch (decks) {
          AsyncError() => LoadFailure(
            message: '기본 단어장을 불러오지 못했어요',
            onRetry: () => ref.invalidate(builtinDecksProvider),
          ),
          AsyncData() => const Padding(
            padding: EdgeInsets.all(Space.gutter),
            child: EmptyNote(title: '이 빌드에는 이 단어장이 들어 있지 않아요'),
          ),
          _ => const Loading(),
        },
      );
    }
    final playlist = deckPlaylistOf(deck, lists)?.playlist;
    return Scaffold(
      appBar: AppBar(title: Text(deck.name)),
      body: _Body(deck: deck, sources: set.sources, phase: _phase),
      bottomNavigationBar: BottomActionBar(
        secondary: playlist == null
            ? null
            : BarAction(
                label: '재생목록 열기',
                onPressed: () => pushScreen<void>(
                  context,
                  PlaylistScreen(playlistId: playlist.id),
                ),
              ),
        primary: BarPrimaryButton(
          label: playlist == null ? '재생목록에 추가' : '빠진 단어 채우기',
          onPressed: _phase is _Adding ? null : () => _add(deck),
        ),
      ),
    );
  }

  Future<void> _add(BuiltinDeck deck) async {
    final messenger = ScaffoldMessenger.of(context);
    // Whether the deck is in already, from the playlists as they are now.
    final bool again;
    try {
      again =
          deckPlaylistOf(deck, await ref.read(playlistsProvider.future)) !=
          null;
    } on Exception catch (e, stack) {
      debugPrint('playlists for a deck: $e\n$stack');
      return _fail(messenger, '재생목록을 불러오지 못했어요. 다시 시도해 주세요');
    }
    if (!mounted || !await _confirm(deck, again: again)) return;
    // Busy from here: a second press cannot start another add.
    _show(_Adding(0, deck.words.length));
    final DeckDictionaries? dictionaries;
    try {
      dictionaries = await ref.read(deckDictionariesProvider.future);
    } on Exception catch (e, stack) {
      debugPrint('dictionaries for a deck: $e\n$stack');
      return _fail(messenger, '사전을 열지 못해 단어장을 넣지 못했어요');
    }
    if (dictionaries == null) {
      return _fail(messenger, '사전을 열지 못해 단어장을 넣지 못했어요');
    }
    final library = ref.read(libraryServiceProvider);
    final revision = ref.read(dataRevisionProvider.notifier);
    try {
      final draft = await deckDraft(
        deck,
        lexicon: dictionaries.lexicon,
        glossary: dictionaries.glossary,
        fallback: dictionaries.fallback,
        onProgress: (done, total) => _show(_Adding(done, total)),
      );
      final result = await library.addDeck(draft);
      revision.bump();
      _show(_Added(result, draft.withoutMeaning.length));
    } on Exception catch (e, stack) {
      debugPrint('adding deck ${deck.id} failed: $e\n$stack');
      _fail(messenger, '단어장을 넣지 못했어요. 다시 시도해 주세요');
    }
  }

  void _show(_Phase phase) {
    if (mounted) setState(() => _phase = phase);
  }

  void _fail(ScaffoldMessengerState messenger, String message) {
    _show(const _Idle());
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(BuiltinDeck deck, {required bool again}) async {
    final sure = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog.adaptive(
        title: Text(again ? '빠진 단어를 채울까요?' : '「${deck.name}」에 넣을까요?'),
        content: Text(
          again
              ? '「${deck.name}」에 없는 단어만 넣어요. 이미 있는 단어는 그대로예요.'
              : '단어 ${deck.words.length}개를 재생목록 「${deck.name}」에 넣어요. '
                    '이미 있는 단어는 저장된 뜻과 학습 기록이 그대로이고, 숨긴 단어는 숨긴 채로 들어가요. '
                    '사전에서 뜻을 찾지 못한 단어는 넣지 않아요.',
        ),
        actions: [
          adaptiveDialogAction(
            dialog,
            label: '취소',
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          adaptiveDialogAction(
            dialog,
            label: again ? '채우기' : '넣기',
            isDefault: true,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    return sure == true;
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.deck, required this.sources, required this.phase});

  final BuiltinDeck deck;
  final List<DeckSource> sources;
  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final preview = deck.words.take(_previewWords).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.section,
      ),
      children: [
        Text(
          '단어 ${deck.words.length}개',
          style: TextStyle(
            color: t.text,
            fontSize: TypeScale.title,
            fontWeight: Weights.emphasis,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          '홈의 「오늘 학습」에서 하루 목표만큼씩 나와요.',
          style: TextStyle(color: t.text2, fontSize: TypeScale.body2),
        ),
        switch (phase) {
          _Idle() => const SizedBox(height: Space.sm),
          _Adding(:final done, :final total) => _AddingNote(
            done: done,
            total: total,
          ),
          _Added(:final result, :final withoutMeaning) => _AddedNote(
            result: result,
            withoutMeaning: withoutMeaning,
          ),
        },
        SectionLabel('처음 단어 ${preview.length}개'),
        for (final (i, w) in preview.indexed) _WordRow(word: w, first: i == 0),
        DeckSourceNote(sources: sources),
      ],
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.first});

  final DeckWord word;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RuledRow(
      ruleAbove: first,
      child: Row(
        children: [
          Expanded(
            child: JpText(
              word.headword,
              style: JpType.headword(
                TypeScale.body,
                t.text,
                weight: Weights.emphasis,
              ),
            ),
          ),
          if (word.readings.isNotEmpty)
            JpText(word.reading, style: JpType.body(TypeScale.body2, t.text2)),
        ],
      ),
    );
  }
}

/// While the words go in: how many, and how far.
class _AddingNote extends StatelessWidget {
  const _AddingNote({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => _Note(
    title: '단어 $total개를 넣고 있어요',
    child: Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: LinearProgressIndicator(
        value: total == 0 ? null : done / total,
        semanticsLabel: '넣는 중',
      ),
    ),
  );
}

/// What adding did.
class _AddedNote extends StatelessWidget {
  const _AddedNote({required this.result, required this.withoutMeaning});

  final AddResult result;
  final int withoutMeaning;

  @override
  Widget build(BuildContext context) {
    final went = result.added + result.linked;
    final lines = [
      if (result.alreadyIn > 0) '이미 들어 있던 ${result.alreadyIn}개는 그대로예요.',
      if (withoutMeaning > 0) '뜻을 찾지 못한 $withoutMeaning개는 넣지 않았어요.',
    ];
    return _Note(
      title: went > 0 ? '단어 $went개를 넣었어요' : '새로 넣은 단어가 없어요',
      body: lines.isEmpty ? null : lines.join(' '),
    );
  }
}

/// A ruled note under the count: a sentence, then a quieter line or a part.
class _Note extends StatelessWidget {
  const _Note({required this.title, this.body, this.child});

  final String title;
  final String? body;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.lg),
    child: EmptyNote(title: title, body: body, action: child),
  );
}
