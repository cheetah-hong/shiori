import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/decks/deck_data.dart';
import 'package:shiori/features/decks/deck_parts.dart';
import 'package:shiori/features/decks/deck_screen.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori/shared/ruled.dart';
import 'package:shiori/shared/states.dart';
import 'package:shiori_core/shiori_core.dart';

/// 기본 단어장: the word lists that come with the app, one row per level,
/// and where the lists come from.
class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decks = ref.watch(builtinDecksProvider);
    // The rows only say 추가됨 once the playlists are known.
    final lists = ref.watch(playlistsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('기본 단어장')),
      body: switch (decks) {
        AsyncData(value: null) => const Padding(
          padding: EdgeInsets.all(Space.gutter),
          child: EmptyNote(
            title: '이 빌드에는 기본 단어장이 들어 있지 않아요',
            body: '페이지를 등록해서 단어를 모을 수 있어요.',
          ),
        ),
        AsyncData(:final value?) => ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.section,
          ),
          children: [
            for (final (i, deck) in value.decks.indexed)
              _DeckRow(
                deck: deck,
                added: deckPlaylistOf(deck, lists) != null,
                first: i == 0,
              ),
            DeckSourceNote(sources: value.sources),
          ],
        ),
        AsyncError(:final error) => _failed(ref, error),
        _ => const Loading(),
      },
    );
  }

  Widget _failed(WidgetRef ref, Object error) {
    debugPrint('built-in decks failed to load: $error');
    return LoadFailure(
      message: '기본 단어장을 불러오지 못했어요',
      onRetry: () => ref.invalidate(builtinDecksProvider),
    );
  }
}

/// A deck: its name and word count; 추가됨 once it is a playlist.
class _DeckRow extends StatelessWidget {
  const _DeckRow({
    required this.deck,
    required this.added,
    required this.first,
  });

  final BuiltinDeck deck;
  final bool added;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: RuledRow(
          ruleAbove: first,
          onTap: () => pushScreen<void>(context, DeckScreen(deckId: deck.id)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: TextStyle(
                        color: t.text,
                        fontSize: TypeScale.body,
                        fontWeight: Weights.emphasis,
                      ),
                    ),
                    Text(
                      '단어 ${deck.words.length}개',
                      style: TextStyle(
                        color: t.text2,
                        fontSize: TypeScale.body2,
                      ),
                    ),
                  ],
                ),
              ),
              if (added) ...[
                const SizedBox(width: Space.sm),
                Text(
                  '추가됨',
                  style: TextStyle(
                    color: t.accentText,
                    fontSize: TypeScale.body2,
                  ),
                ),
              ],
              const SizedBox(width: Space.xs),
              Icon(CupertinoIcons.chevron_forward, color: t.text3),
            ],
          ),
        ),
      ),
    );
  }
}
