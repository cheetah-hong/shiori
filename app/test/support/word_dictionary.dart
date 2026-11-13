import 'package:flutter_riverpod/misc.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';

import 'harness.dart';

/// Made-up dictionary entries for the word screens (단어 고치기·추가).
final wordLexicon = InMemoryLexicon(const [
  LexiconWord(id: 9200001, kanji: ['試語甲'], readings: ['しごこう'], pos: ['n']),
  LexiconWord(id: 9200002, kanji: ['試語乙'], readings: ['しごおつ'], pos: ['n']),
  LexiconWord(id: 9200003, kanji: ['試語丁'], readings: ['しごてい'], pos: ['n']),
  LexiconWord(
    id: 9200010,
    kanji: ['試語花'],
    readings: ['しごか'],
    pos: ['n'],
    priority: lexiconCommonMask,
  ),
  LexiconWord(id: 9200011, kanji: ['支語華'], readings: ['しごか'], pos: ['n']),
]);

/// Senses by headword, made up.
final class WordGlossary implements KoreanGlossary {
  const WordGlossary(this.byHeadword);

  final Map<String, List<String>> byHeadword;

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => [
    for (final (i, text) in (byHeadword[headword] ?? const []).indexed)
      KoreanSense(words: [text], source: GlossarySource.krdict, senseNo: i + 1),
  ].take(limit).toList();

  @override
  List<GlossarySourceInfo> get sources => const [];
}

const wordGlossary = WordGlossary({
  '試語甲': ['시험 낱말', '시험어'],
  '試語乙': ['시험 낱말 둘'],
  '試語丁': ['시험 낱말 넷', '시험어 넷째'],
  '試語花': ['시험 꽃'],
  '支語華': ['지어 화'],
});

/// The made-up dictionary plugged in where the word screens read it.
List<Override> get wordDictionaryOverrides => [
  lexiconProvider.overrideWithValue(wordLexicon),
  koreanGlossaryProvider.overrideWithValue(wordGlossary),
  wiktionaryGlossaryProvider.overrideWithValue(null),
];

/// 試語帳 (試語甲·試語乙·試語丙) and 試語帳 2 (試語甲·試語丁), made-up words.
/// Returns the two playlists.
Future<(Playlist, Playlist)> seedWordLists(TestBlocks blocks) async {
  final service = LibraryService(library: blocks.library, clock: blocks.clock);
  CapturedEntry e(String head, String reading, String meaning) => CapturedEntry(
    headword: head,
    readings: [reading],
    pos: PartOfSpeech.noun,
    meaning: meaning,
  );
  final a = await service.addDraft(
    CaptureDraft(
      entries: [
        e('試語甲', 'しごこう', '시험 낱말 하나'),
        e('試語乙', 'しごおつ', '시험 낱말 둘'),
        e('試語丙', 'しごへい', '시험 낱말 셋'),
      ],
    ),
    to: const NewPlaylist('試語帳'),
  );
  final b = await service.addDraft(
    CaptureDraft(entries: [e('試語甲', 'しごこう', '-'), e('試語丁', 'しごてい', '시험 낱말 넷')]),
    to: const NewPlaylist('試語帳 2'),
  );
  return (a.playlist, b.playlist);
}

/// The stored word with [headword].
Future<Word> storedWord(TestBlocks blocks, String headword) async =>
    (await blocks.library.wordsByKey([wordKey(headword)])).values.single;
