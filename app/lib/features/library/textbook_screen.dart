import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// 교재: textbook › DAY › words, with each word's memory level. Words hidden
/// with 이미 알아요 are left out of the days and listed under 「숨긴 단어 n개
/// 보기」, where they can be shown again.
class TextbookScreen extends ConsumerWidget {
  const TextbookScreen({super.key, required this.textbookId});

  final String textbookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(textbookOverviewProvider(textbookId));
    final cardsState = ref.watch(cardsProvider);
    final cards = cardsState.value ?? const <String, ReviewCard>{};
    final maxLevel = ref.watch(reviewSchedulerProvider).maxLevel;
    final summary = ref.watch(textbookSummaryProvider(textbookId)).value;

    return Scaffold(
      appBar: AppBar(title: Text(overview.value?.textbook.title ?? '교재')),
      body: switch (overview) {
        // While a save (hiding a word, say) reloads the overview, the last
        // value stays on screen: the list keeps its scroll position and the
        // hidden words stay open.
        AsyncValue(:final value?, hasError: false) => _Body(
          overview: value,
          cards: cards,
          cardsFailed: cardsState.hasError,
          studyCards: summary == null ? 0 : summary.dueCount + summary.newCount,
          maxLevel: maxLevel,
        ),
        AsyncError(:final error) => Center(
          child: Text('교재를 불러오지 못했어요: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.overview,
    required this.cards,
    required this.cardsFailed,
    required this.studyCards,
    required this.maxLevel,
  });

  final TextbookOverview overview;
  final Map<String, ReviewCard> cards;

  /// Memory levels could not be loaded; the meters would all read "new".
  final bool cardsFailed;

  /// Due reviews plus new words of this textbook.
  final int studyCards;
  final int maxLevel;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _showHidden = false;

  void _setHidden(Word word, {required bool hidden}) => _setWordHidden(
    messenger: ScaffoldMessenger.of(context),
    library: ref.read(libraryServiceProvider),
    revision: ref.read(dataRevisionProvider.notifier),
    word: word,
    hidden: hidden,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final overview = widget.overview;
    final cards = widget.cards;
    final maxLevel = widget.maxLevel;
    final studyCards = widget.studyCards;
    final words = [
      for (final d in overview.days) ...d.shownWords,
      ...overview.undated.where((w) => !w.isHidden),
    ];
    final hiddenWords = overview.hiddenWords;
    final undated = [
      for (final w in overview.undated)
        if (!w.isHidden) w,
    ];
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
                      _Stat(value: overview.shownCount, label: '단어'),
                      _Stat(value: learned, label: '학습함'),
                      _Stat(value: longTerm, label: '장기 기억', color: t.ok),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: studyCards == 0
                          ? null
                          : () => pushScreen<void>(
                              context,
                              StudyScreen(textbookId: overview.textbook.id),
                            ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        studyCards == 0 ? '지금은 학습할 카드가 없어요' : '이 교재로 학습',
                      ),
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
                ],
              ),
            ),
          ),
        ),
        for (final day in overview.days)
          if (day.shownWords.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverToBoxAdapter(
                child: SectionLabel(
                  [
                    dayNumber(day.day.number),
                    day.day.title,
                  ].where((s) => s.isNotEmpty).join('  '),
                  trailing: Text(
                    '${day.shownWords.length}개',
                    style: context.text.bodySmall,
                  ),
                ),
              ),
            ),
            _WordList(
              words: day.shownWords,
              cards: cards,
              maxLevel: maxLevel,
              onHide: (w) => _setHidden(w, hidden: true),
            ),
          ],
        if (undated.isNotEmpty) ...[
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverToBoxAdapter(child: SectionLabel('DAY 모름')),
          ),
          _WordList(
            words: undated,
            cards: cards,
            maxLevel: maxLevel,
            onHide: (w) => _setHidden(w, hidden: true),
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

/// Hides or shows [word] and says so, with 되돌리기 after hiding. Uses no
/// [BuildContext], so 되돌리기 still works once the screen is gone.
Future<void> _setWordHidden({
  required ScaffoldMessengerState messenger,
  required LibraryService library,
  required DataRevision revision,
  required Word word,
  required bool hidden,
}) async {
  void say(String message, {SnackBarAction? action}) => messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), action: action, persist: false),
    );

  final failure = hidden ? HideLabels.hideFailed : HideLabels.restoreFailed;
  try {
    if (hidden) {
      await library.hideWords([word.id]);
    } else {
      await library.unhideWords([word.id]);
    }
  } on Exception catch (e, stack) {
    // A storage block failed (a disk error, say).
    debugPrint('textbook hide failed: $e\n$stack');
    say(failure);
    return;
  } on Error catch (e, stack) {
    // A bug in a block: report it like any uncaught error.
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: stack, library: 'textbook'),
    );
    say(failure);
    return;
  }
  revision.bump();
  if (!hidden) {
    say(HideLabels.restored(word.headword));
    return;
  }
  say(
    HideLabels.hidden(word.headword),
    action: SnackBarAction(
      label: HideLabels.undo,
      onPressed: () => _setWordHidden(
        messenger: messenger,
        library: library,
        revision: revision,
        word: word,
        hidden: false,
      ),
    ),
  );
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
  });

  final List<Word> words;
  final Map<String, ReviewCard> cards;
  final int maxLevel;
  final ValueChanged<Word> onHide;

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
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.xs,
                Space.xs,
                Space.xs,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      w.no ?? '',
                      style: context.text.labelSmall?.copyWith(
                        color: t.ink3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
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
            final day = w.day;
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
                          [
                            if (day != null) dayNumber(day),
                            w.meaning,
                          ].where((s) => s.isNotEmpty).join(' · '),
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
