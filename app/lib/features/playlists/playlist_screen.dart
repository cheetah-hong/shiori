import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/capture_screen.dart';
import 'package:shiori/features/playlists/mode_meters.dart';
import 'package:shiori/features/playlists/playlist_actions.dart';
import 'package:shiori/features/playlists/playlist_picker.dart';
import 'package:shiori/features/study/restudy_labels.dart';
import 'package:shiori/features/study/study_mode_chips.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori/shared/bottom_action_bar.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori/shared/ruled.dart';
import 'package:shiori/shared/sheet.dart';
import 'package:shiori/shared/states.dart';
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

  Widget _failed(WidgetRef ref, Object error) {
    debugPrint('playlist failed to load: $error');
    return LoadFailure(
      message: '재생목록을 불러오지 못했어요',
      onRetry: () => retryStorage(ref),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(playlistViewProvider(playlistId));
    final cardsState = ref.watch(cardsByModeProvider);
    final mode = ref.watch(studyModeProvider).value ?? StudyMode.meaning;
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
          cardsByMode: cardsState.value ?? const {},
          mode: mode,
          cardsFailed: cardsState.hasError,
          maxLevel: ref.watch(reviewSchedulerProvider).maxLevel,
        ),
        AsyncError(:final error) => _failed(ref, error),
        _ => const Loading(),
      },
      bottomNavigationBar: switch (view) {
        AsyncValue(:final value?, hasError: false) => _StudyBar(
          view: value,
          studyCards: summary == null ? 0 : summary.dueCount + summary.newCount,
          aheadCards: summary?.aheadCount ?? 0,
        ),
        _ => null,
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
    required this.cardsByMode,
    required this.mode,
    required this.cardsFailed,
    required this.maxLevel,
  });

  final PlaylistView view;

  /// Every mode's cards (a word's levels in its sheet).
  final Map<StudyMode, Map<String, ReviewCard>> cardsByMode;

  /// The way of studying in use: the counts and the study button follow it.
  final StudyMode mode;

  /// Memory levels could not be loaded; the meters would all read "new".
  final bool cardsFailed;
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
    final cards = widget.cardsByMode[widget.mode] ?? const {};
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
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetFrame(
                  padding: const EdgeInsets.fromLTRB(14, Space.xs, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SheetMemoRow(
                        label: '단어',
                        value: '${view.shownCount}',
                        unit: '개',
                      ),
                      SheetMemoRow(label: '학습함', value: '$learned', unit: '개'),
                      SheetMemoRow(
                        label: '장기 기억',
                        value: '$longTerm',
                        unit: '개',
                        last: true,
                      ),
                    ],
                  ),
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
                const SizedBox(height: Space.lg),
                const StudyModeChips(),
              ],
            ),
          ),
        ),
        if (view.words.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: EmptyNote(
                title: '이 목록에는 아직 단어가 없어요',
                body: '페이지를 등록할 때 이 재생목록을 고르면 단어가 들어와요.',
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
            cardsByMode: widget.cardsByMode,
            mode: widget.mode,
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

/// The bottom bar: 이 목록 학습 (every card it can study, 「· n장」); with
/// nothing to study today, 더 학습하기 (every card that can be brought
/// forward) when some card can, otherwise a plain line. An empty playlist
/// offers 페이지 등록 instead.
class _StudyBar extends StatelessWidget {
  const _StudyBar({
    required this.view,
    required this.studyCards,
    required this.aheadCards,
  });

  final PlaylistView view;

  /// Due reviews plus new words of this playlist.
  final int studyCards;

  /// Cards of this playlist whose review time has not come (더 학습하기).
  final int aheadCards;

  @override
  Widget build(BuildContext context) {
    final scope = PlaylistOnly(view.playlist.id);
    if (view.words.isEmpty) {
      return BottomActionBar(
        secondary: BarAction(
          label: '페이지 등록',
          icon: Icons.photo_camera_outlined,
          onPressed: () => pushScreen<void>(context, const CaptureScreen()),
        ),
      );
    }
    if (studyCards == 0 && aheadCards > 0) {
      return BottomActionBar(
        top: Text(
          RestudyLabels.moreHint(aheadCards),
          style: context.text.bodySmall,
        ),
        primary: BarPrimaryButton(
          label: RestudyLabels.more,
          icon: Icons.replay_rounded,
          onPressed: () =>
              pushScreen<void>(context, StudyScreen(scope: scope, more: true)),
        ),
      );
    }
    if (studyCards == 0) {
      // Nothing to press: said plainly, not as a dimmed button.
      return BottomActionBar(
        primary: Text(
          '지금은 학습할 카드가 없어요',
          style: context.text.titleMedium?.copyWith(color: context.tokens.text),
        ),
      );
    }
    return BottomActionBar(
      primary: BarPrimaryButton(
        label: '이 목록 학습 · $studyCards장',
        icon: Icons.play_arrow_rounded,
        onPressed: () => pushScreen<void>(context, StudyScreen(scope: scope)),
      ),
    );
  }
}

/// The playlist's words: each row shows the word and its level in the way
/// of studying in use; a tap opens its level in all four ways.
class _WordList extends StatelessWidget {
  const _WordList({
    required this.words,
    required this.cardsByMode,
    required this.mode,
    required this.maxLevel,
    required this.onHide,
    required this.onAction,
  });

  final List<Word> words;
  final Map<StudyMode, Map<String, ReviewCard>> cardsByMode;

  /// The way of studying in use: the one level a row shows.
  final StudyMode mode;
  final int maxLevel;
  final ValueChanged<Word> onHide;
  final Future<void> Function(Word, _WordAction) onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: SliverList.builder(
        itemCount: words.length,
        itemBuilder: (context, i) {
          final w = words[i];
          final levels = {
            for (final m in StudyMode.values)
              m: cardsByMode[m]?[w.id]?.level ?? 0,
          };
          return RuledRow(
            key: ValueKey('word-${w.id}'),
            ruleAbove: i == 0,
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Expanded(
                  child: _WordTap(
                    word: w,
                    mode: mode,
                    level: levels[mode] ?? 0,
                    maxLevel: maxLevel,
                    onTap: () => showModeLevels(
                      context,
                      word: w,
                      levels: levels,
                      max: maxLevel,
                      current: mode,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: HideLabels.hideWord(w.headword),
                  color: t.text3,
                  iconSize: 20,
                  onPressed: () => onHide(w),
                  icon: const Icon(Icons.visibility_off_outlined),
                ),
                PopupMenuButton<_WordAction>(
                  tooltip: '${w.headword} 메뉴',
                  iconColor: t.text3,
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
                    // A word new in every mode has nothing to start
                    // again from.
                    if (cardsByMode.values.any((c) => c.containsKey(w.id)))
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
    );
  }
}

/// A row's word (headword, reading, meaning) and its meter in the way in
/// use, pressed as one: read 「語一, 뜻 맞히기 2단계」, then the reading and
/// the meaning.
class _WordTap extends StatelessWidget {
  const _WordTap({
    required this.word,
    required this.mode,
    required this.level,
    required this.maxLevel,
    required this.onTap,
  });

  final Word word;
  final StudyMode mode;
  final int level;
  final int maxLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // From about the AX1 text size the meter goes under the word.
    final large = isLargeText(context);
    final meter = ExcludeSemantics(
      child: MemoryMeter(level: level, max: maxLevel),
    );
    final head = word.headword;
    final said = '$head, ${modeLevelSaid(mode, level)}';
    return Semantics(
      container: true,
      button: true,
      hint: '학습 방식마다 기억 단계 보기',
      attributedLabel: AttributedString(
        said,
        attributes: [
          LocaleStringAttribute(
            range: TextRange(start: 0, end: head.length),
            locale: JpType.locale,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ruledRowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: Space.sm,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          // Read in the row's label, once.
                          ExcludeSemantics(
                            child: JpText(
                              head,
                              style: JpType.print(20, t.text),
                            ),
                          ),
                          JpText(
                            readingsLabel(word.readings),
                            style: JpType.gothic(12.5, t.text3, height: 1.2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        word.meaning,
                        style: context.text.bodySmall?.copyWith(color: t.text2),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (large) ...[const SizedBox(height: Space.xs), meter],
                    ],
                  ),
                ),
                if (!large) ...[const SizedBox(width: Space.sm), meter],
              ],
            ),
          ),
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
      sliver: SliverList.builder(
        itemCount: words.length,
        itemBuilder: (context, i) {
          final w = words[i];
          return RuledRow(
            ruleAbove: i == 0,
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      JpText(
                        w.headword,
                        style: JpType.print(18, t.text2),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        w.meaning,
                        style: context.text.bodySmall?.copyWith(color: t.text3),
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
    );
  }
}
