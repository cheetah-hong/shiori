import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/words/word_add_sheet.dart';
import 'package:shiori/features/words/word_data.dart';
import 'package:shiori/features/words/word_labels.dart';
import 'package:shiori/features/words/word_sheet.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori/shared/ruled.dart';
import 'package:shiori/shared/states.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// The magnifier that opens 단어 찾기 (narrowed to [playlistId] first, when
/// given). Read by VoiceOver as 「단어 찾기」.
class WordSearchButton extends StatelessWidget {
  const WordSearchButton({super.key, this.playlistId});

  final String? playlistId;

  void _open(BuildContext context) =>
      pushScreen<void>(context, WordSearchScreen(playlistId: playlistId));

  // The tooltip shows on a long press; VoiceOver reads the label once (a
  // tooltip alone is no label).
  @override
  Widget build(BuildContext context) => Semantics(
    label: WordLabels.search,
    button: true,
    excludeSemantics: true,
    onTap: () => _open(context),
    child: IconButton(
      tooltip: WordLabels.search,
      icon: const Icon(CupertinoIcons.search),
      onPressed: () => _open(context),
    ),
  );
}

enum _Scope { thisList, all }

/// 단어 찾기: the learner's words by headword, reading or meaning. Opened
/// from a playlist, it looks in that playlist first (이 목록 | 모든 단어).
class WordSearchScreen extends ConsumerStatefulWidget {
  const WordSearchScreen({super.key, this.playlistId});

  final String? playlistId;

  @override
  ConsumerState<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends ConsumerState<WordSearchScreen> {
  final _query = TextEditingController();
  late _Scope _scope = widget.playlistId == null ? _Scope.all : _Scope.thisList;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.playlistId;
    return Scaffold(
      appBar: AppBar(title: const Text(WordLabels.search)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: CupertinoSearchTextField(
              controller: _query,
              autofocus: true,
              placeholder: WordLabels.searchHint,
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (id != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.md,
                Space.gutter,
                0,
              ),
              child: CupertinoSlidingSegmentedControl<_Scope>(
                groupValue: _scope,
                children: const {
                  _Scope.thisList: _Segment(WordLabels.thisList),
                  _Scope.all: _Segment(WordLabels.allWords),
                },
                onValueChanged: (s) {
                  if (s != null) setState(() => _scope = s);
                },
              ),
            ),
          Expanded(child: _results(context, id)),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, String? playlistId) {
    final query = _query.text;
    if (query.trim().isEmpty) return const SizedBox.shrink();
    final index = ref.watch(wordSearchIndexProvider);
    final AsyncValue<Set<String>?> within =
        _scope == _Scope.thisList && playlistId != null
        ? ref.watch(playlistWordIdsProvider(playlistId))
        : const AsyncData(null);
    // While a change reloads them, the last values stay on screen (the
    // list keeps its scroll position), as on the playlist screen.
    return switch ((index, within)) {
      (
        AsyncValue(value: final i?, hasError: false),
        AsyncValue<Set<String>?>(:final value, hasValue: true, hasError: false),
      ) =>
        _Results(
          found: i.find(query, within: value),
          query: query,
          playlistId: playlistId,
        ),
      (AsyncError(:final error), _) ||
      (_, AsyncError(:final error)) => LoadFailure(
        message: '단어를 불러오지 못했어요',
        onRetry: () {
          debugPrint('word search failed: $error');
          retryStorage(ref);
        },
      ),
      _ => const Loading(),
    };
  }
}

class _Segment extends StatelessWidget {
  const _Segment(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: Space.sm,
      vertical: Space.xs,
    ),
    child: Text(label),
  );
}

class _Results extends StatelessWidget {
  const _Results({
    required this.found,
    required this.query,
    required this.playlistId,
  });

  final List<Word> found;
  final String query;
  final String? playlistId;

  @override
  Widget build(BuildContext context) {
    if (found.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmptyNote(
              title: WordLabels.noMatch,
              action: TextButton(
                onPressed: () => showWordAdder(
                  context,
                  playlistId: playlistId,
                  headword: query.trim(),
                ),
                child: const Text(WordLabels.addDirectly),
              ),
            ),
          ],
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            Space.xs,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              WordLabels.count(found.length),
              style: context.text.bodySmall,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.section,
          ),
          sliver: SliverList.builder(
            itemCount: found.length,
            itemBuilder: (context, i) =>
                _FoundRow(word: found[i], first: i == 0),
          ),
        ),
      ],
    );
  }
}

/// One word found: headword, reading and meaning, 숨김 for a hidden word.
class _FoundRow extends StatelessWidget {
  const _FoundRow({required this.word, required this.first});

  final Word word;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final head = word.headword;
    return RuledRow(
      key: ValueKey('found-$head'),
      ruleAbove: first,
      onTap: () => showWordSheet(context, wordId: word.id),
      child: Semantics(
        container: true,
        button: true,
        attributedLabel: AttributedString(
          head,
          attributes: [
            LocaleStringAttribute(
              range: TextRange(start: 0, end: head.length),
              locale: JpType.locale,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Space.sm,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      ExcludeSemantics(
                        child: JpText(
                          head,
                          style: JpType.headword(TypeScale.title, t.text),
                        ),
                      ),
                      if (word.readings.isNotEmpty)
                        JpText(
                          readingsLabel(word.readings),
                          style: JpType.body(TypeScale.small, t.text3),
                        ),
                    ],
                  ),
                  Text(
                    word.meaning,
                    style: context.text.bodySmall?.copyWith(color: t.text2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (word.isHidden) ...[
              const SizedBox(width: Space.sm),
              Text(
                WordLabels.hidden,
                style: context.text.bodySmall?.copyWith(color: t.text3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
