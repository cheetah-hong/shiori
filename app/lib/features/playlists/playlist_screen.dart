import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/playlists/playlist_actions.dart';
import 'package:shiori/features/playlists/playlist_picker.dart';
import 'package:shiori/features/study/restudy_labels.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// One playlist: its words in order with their memory level, studying only
/// them (or, with nothing to study today, 더 학습하기), taking a word out,
/// adding it to another playlist, studying a word from the start again,
/// renaming and deleting the playlist. Words hidden with 이미 알아요 are listed under
/// 「숨긴 단어 n개 보기」, where they can be shown again.
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(playlistViewProvider(playlistId));
    final cardsState = ref.watch(cardsProvider);
    final summary = ref.watch(playlistSummaryProvider(playlistId)).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(view.value?.playlist.name ?? '재생목록'),
        actions: [if (view.value case final v?) _PlaylistMenu(view: v)],
      ),
      body: switch (view) {
        // While a change (hiding or taking out a word) reloads the view, the
        // last value stays on screen: the list keeps its scroll position and
        // the hidden words stay open.
        AsyncValue(:final value?, hasError: false) => _Body(
          view: value,
          cards: cardsState.value ?? const <String, ReviewCard>{},
          cardsFailed: cardsState.hasError,
          studyCards: summary == null ? 0 : summary.dueCount + summary.newCount,
          aheadCards: summary?.aheadCount ?? 0,
          maxLevel: ref.watch(reviewSchedulerProvider).maxLevel,
        ),
        AsyncError(:final error) => Center(
          child: Text('재생목록을 불러오지 못했어요: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _PlaylistMenu extends ConsumerWidget {
  const _PlaylistMenu({required this.view});

  final PlaylistView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: '재생목록 메뉴',
    onSelected: (action) async {
      switch (action) {
        case 'rename':
          await renamePlaylist(context, ref, view.playlist);
        case 'delete':
          final deleted = await deletePlaylist(
            context,
            ref,
            view.playlist,
            wordCount: view.words.length,
          );
          if (deleted && context.mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'rename', child: Text('이름 바꾸기')),
      PopupMenuItem(value: 'delete', child: Text('삭제')),
    ],
  );
}

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.view,
    required this.cards,
    required this.cardsFailed,
    required this.studyCards,
    required this.aheadCards,
    required this.maxLevel,
  });

  final PlaylistView view;
  final Map<String, ReviewCard> cards;

  /// Memory levels could not be loaded; the meters would all read "new".
  final bool cardsFailed;

  /// Due reviews plus new words of this playlist.
  final int studyCards;

  /// Cards of this playlist whose review time has not come (더 학습하기).
  final int aheadCards;
  final int maxLevel;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _showHidden = false;

  void _setHidden(Word word, {required bool hidden}) => setWordHidden(
    messenger: ScaffoldMessenger.of(context),
    library: ref.read(libraryServiceProvider),
    revision: ref.read(dataRevisionProvider.notifier),
    word: word,
    hidden: hidden,
  );

  Future<void> _wordAction(Word word, _WordAction action) => switch (action) {
    _WordAction.remove => removeFromPlaylist(
      messenger: ScaffoldMessenger.of(context),
      library: ref.read(libraryServiceProvider),
      revision: ref.read(dataRevisionProvider.notifier),
      playlistId: widget.view.playlist.id,
      word: word,
    ),
    _WordAction.addElsewhere => _addElsewhere(word),
    _WordAction.reset => resetWord(
      messenger: ScaffoldMessenger.of(context),
      study: ref.read(studyServiceProvider),
      revision: ref.read(dataRevisionProvider.notifier),
      playlistId: widget.view.playlist.id,
      word: word,
    ),
  };

  Future<void> _addElsewhere(Word word) async {
    final messenger = ScaffoldMessenger.of(context);
    // The picker shows whether each playlist holds the word; without the
    // preview (a read that failed) it still works, only without that.
    AddPreview? preview;
    try {
      preview = await ref.read(libraryServiceProvider).previewAdd([
        word.headword,
      ]);
    } on Exception catch (e, stack) {
      debugPrint('preview for adding elsewhere: $e\n$stack');
    }
    if (!mounted) return;
    final target = await showPlaylistPicker(
      context,
      exceptPlaylistId: widget.view.playlist.id,
      preview: preview,
    );
    if (target == null || !mounted) return;
    await addWordsTo(
      messenger: messenger,
      library: ref.read(libraryServiceProvider),
      revision: ref.read(dataRevisionProvider.notifier),
      wordIds: [word.id],
      target: target,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final view = widget.view;
    final cards = widget.cards;
    final maxLevel = widget.maxLevel;
    final words = view.shownWords;
    final hiddenWords = view.hiddenWords;
    final longTerm = words
        .where((w) => (cards[w.id]?.level ?? 0) >= maxLevel)
        .length;
    final learned = words.where((w) => cards.containsKey(w.id)).length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(Space.lg),
              decoration: BoxDecoration(
                color: t.sheet,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Stat(value: view.shownCount, label: '단어'),
                      _Stat(value: learned, label: '학습함'),
                      _Stat(value: longTerm, label: '장기 기억', color: t.ok),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  _StudyButton(
                    scope: PlaylistOnly(view.playlist.id),
                    studyCards: widget.studyCards,
                    aheadCards: widget.aheadCards,
                  ),
                  if (widget.cardsFailed) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      '기억 단계를 불러오지 못해 막대가 비어 보일 수 있어요',
                      style: TextStyle(
                        color: t.risk,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (view.words.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(Space.gutter),
            sliver: SliverToBoxAdapter(
              child: Text(
                '이 목록에는 아직 단어가 없어요',
                style: context.text.bodyMedium?.copyWith(color: t.ink2),
              ),
            ),
          ),
        if (words.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverToBoxAdapter(
              child: SectionLabel(
                '단어',
                trailing: Text(
                  '${words.length}개',
                  style: context.text.bodySmall,
                ),
              ),
            ),
          ),
          _WordList(
            words: words,
            cards: cards,
            maxLevel: maxLevel,
            onHide: (w) => _setHidden(w, hidden: true),
            onAction: _wordAction,
          ),
        ],
        if (hiddenWords.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showHidden = !_showHidden),
                  icon: Icon(
                    _showHidden ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  label: Text(
                    _showHidden
                        ? HideLabels.collapseHidden
                        : HideLabels.showHidden(hiddenWords.length),
                  ),
                ),
              ),
            ),
          ),
          if (_showHidden)
            _HiddenList(
              words: hiddenWords,
              onRestore: (w) => _setHidden(w, hidden: false),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: Space.section * 2)),
      ],
    );
  }
}

enum _WordAction { remove, addElsewhere, reset }

/// 이 목록 학습; with nothing to study today, 더 학습하기 when some card can
/// be brought forward, otherwise off.
class _StudyButton extends StatelessWidget {
  const _StudyButton({
    required this.scope,
    required this.studyCards,
    required this.aheadCards,
  });

  final PlaylistOnly scope;
  final int studyCards;
  final int aheadCards;

  @override
  Widget build(BuildContext context) {
    if (studyCards == 0 && aheadCards > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => pushScreen<void>(
              context,
              StudyScreen(scope: scope, more: true),
            ),
            icon: const Icon(Icons.replay_rounded),
            label: const Text(RestudyLabels.more),
          ),
          const SizedBox(height: Space.xs),
          Text(RestudyLabels.moreHint, style: context.text.bodySmall),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: studyCards == 0
            ? null
            : () => pushScreen<void>(context, StudyScreen(scope: scope)),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(studyCards == 0 ? '지금은 학습할 카드가 없어요' : '이 목록 학습'),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});

  final int value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: context.text.headlineSmall?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

class _WordList extends StatelessWidget {
  const _WordList({
    required this.words,
    required this.cards,
    required this.maxLevel,
    required this.onHide,
    required this.onAction,
  });

  final List<Word> words;
  final Map<String, ReviewCard> cards;
  final int maxLevel;
  final ValueChanged<Word> onHide;
  final Future<void> Function(Word, _WordAction) onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: t.sheet,
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        sliver: SliverList.separated(
          itemCount: words.length,
          separatorBuilder: (_, _) =>
              const Divider(indent: Space.lg, endIndent: Space.lg),
          itemBuilder: (context, i) {
            final w = words[i];
            return Padding(
              key: ValueKey('word-${w.id}'),
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.xs,
                Space.xs,
                Space.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                w.headword,
                                style: JpType.print(20, t.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: Space.sm),
                            Text(
                              readingsLabel(w.readings),
                              style: JpType.gothic(12.5, t.ink3, height: 1.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          w.meaning,
                          style: context.text.bodySmall?.copyWith(
                            color: t.ink2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  MemoryMeter(level: cards[w.id]?.level ?? 0, max: maxLevel),
                  IconButton(
                    tooltip: HideLabels.hideWord(w.headword),
                    color: t.ink3,
                    iconSize: 20,
                    onPressed: () => onHide(w),
                    icon: const Icon(Icons.visibility_off_outlined),
                  ),
                  PopupMenuButton<_WordAction>(
                    tooltip: '${w.headword} 메뉴',
                    iconColor: t.ink3,
                    onSelected: (action) => onAction(w, action),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _WordAction.remove,
                        child: Text('이 목록에서 빼기'),
                      ),
                      const PopupMenuItem(
                        value: _WordAction.addElsewhere,
                        child: Text('다른 목록에 추가'),
                      ),
                      // A new word has nothing to start again from.
                      if (cards.containsKey(w.id))
                        const PopupMenuItem(
                          value: _WordAction.reset,
                          child: Text(RestudyLabels.resetWord),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Words hidden with 이미 알아요, each with 되살리기.
class _HiddenList extends StatelessWidget {
  const _HiddenList({required this.words, required this.onRestore});

  final List<Word> words;
  final ValueChanged<Word> onRestore;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: t.paper2,
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        sliver: SliverList.separated(
          itemCount: words.length,
          separatorBuilder: (_, _) =>
              const Divider(indent: Space.lg, endIndent: Space.lg),
          itemBuilder: (context, i) {
            final w = words[i];
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.xs,
                Space.xs,
                Space.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.headword,
                          style: JpType.print(18, t.ink2),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          w.meaning,
                          style: context.text.bodySmall?.copyWith(
                            color: t.ink3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => onRestore(w),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Semantics(
                      label: HideLabels.restoreWord(w.headword),
                      child: const ExcludeSemantics(
                        child: Text(HideLabels.restore),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
