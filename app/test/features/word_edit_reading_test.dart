// M3 (ii): 사전에서 다시 찾기 on the word sheet asks the dictionary with the
// reading the word has, so a kanji word read more than one way is looked up
// as the word it is (not as its more common reading). Made-up words.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

/// 試頭 is read しあたま (the common entry) and しとう.
final _lexicon = InMemoryLexicon(const [
  LexiconWord(
    id: 9500001,
    kanji: ['試頭'],
    readings: ['しあたま'],
    pos: ['n'],
    priority: lexiconCommonMask,
  ),
  LexiconWord(id: 9500002, kanji: ['試頭'], readings: ['しとう'], pos: ['adv']),
]);

/// Senses by spelling and reading.
final class _Glossary implements KoreanGlossary {
  const _Glossary();

  static const _senses = {('試頭', 'しあたま'): '머리', ('試頭', 'しとう'): '마리'};

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => [
    for (final r in readings)
      if (_senses[(headword, r)] case final String text)
        KoreanSense(words: [text], source: GlossarySource.krdict),
  ];

  @override
  List<GlossarySourceInfo> get sources => const [];
}

void main() {
  testWidgets('a word read しとう is looked up as しとう', (tester) async {
    final blocks = TestBlocks();
    final service = LibraryService(
      library: blocks.library,
      clock: blocks.clock,
    );
    final added = await service.addDraft(
      const CaptureDraft(
        entries: [
          CapturedEntry(
            headword: '試頭',
            readings: ['しとう'],
            pos: PartOfSpeech.adverb,
            meaning: '',
          ),
        ],
      ),
      to: const NewPlaylist('試語帳'),
    );
    final word = (await blocks.library.wordsByKey([
      wordKey('試頭'),
    ])).values.single;
    usePhoneSize(tester);
    await tester.pumpWidget(
      screen(
        blocks,
        PlaylistScreen(playlistId: added.playlist.id),
        extra: [
          lexiconProvider.overrideWithValue(_lexicon),
          koreanGlossaryProvider.overrideWithValue(const _Glossary()),
          wiktionaryGlossaryProvider.overrideWithValue(null),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('${word.headword} 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('${word.headword} 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고치기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('사전에서 다시 찾기'));
    await tester.pumpAndSettle();

    final meaning = tester
        .widget<TextField>(find.byKey(const ValueKey('word-meaning')))
        .controller!
        .text;
    expect(meaning, '마리');
    expect(find.text('머리'), findsNothing);
  });
}
