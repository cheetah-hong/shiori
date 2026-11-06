// Made-up words (ids out of JMdict's range) whose stems are also nouns, and
// the grammar expressions that swallow a conjugation's ending, for the tests
// of conjugated stems, sentence usage and page bands.
import 'package:shiori_core/shiori_core.dart';

import 'extract_fixtures.dart';

/// A common entry (spec1): the same cost band as the grammar expressions.
const int _common = 16;

const List<LexiconWord> stemWords = [
  // 一段 verb and its stem as a noun.
  LexiconWord(
    id: 9200001,
    kanji: ['霧ける'],
    readings: ['きりける'],
    pos: ['v1', 'vt'],
    priority: _common,
  ),
  LexiconWord(
    id: 9200002,
    kanji: ['霧け'],
    readings: ['きりけ'],
    pos: ['n'],
    priority: _common,
  ),
  // 五段 verb and its masu stem as a noun.
  LexiconWord(
    id: 9200003,
    kanji: ['霧く'],
    readings: ['きりく'],
    pos: ['v5k', 'vi'],
    priority: _common,
  ),
  LexiconWord(
    id: 9200004,
    kanji: ['霧き'],
    readings: ['きりき'],
    pos: ['n'],
    priority: _common,
  ),
  // A する noun.
  LexiconWord(
    id: 9200005,
    kanji: ['霧話'],
    readings: ['むわ'],
    pos: ['n', 'vs'],
    priority: _common,
  ),
  // い-adjective and its adverbial stem as a noun.
  LexiconWord(
    id: 9200006,
    kanji: ['遠霧い'],
    readings: ['とおぎりい'],
    pos: ['adj-i'],
    priority: _common,
  ),
  LexiconWord(
    id: 9200007,
    kanji: ['遠霧く'],
    readings: ['とおぎりく'],
    pos: ['n'],
    priority: _common,
  ),
  // Adverb, な-adjective and noun at once.
  LexiconWord(
    id: 9200008,
    kanji: ['霧変'],
    readings: ['むへん'],
    pos: ['adv', 'adj-na', 'n'],
    priority: _common,
  ),
  LexiconWord(
    id: 9200009,
    kanji: ['第'],
    readings: ['だい'],
    pos: ['pref'],
    priority: _common,
  ),
  LexiconWord(
    id: 9200010,
    kanji: ['課'],
    readings: ['か'],
    pos: ['n', 'n-suf', 'ctr'],
    priority: _common,
  ),
  // Grammar: expressions and auxiliaries after a stem.
  LexiconWord(
    id: 9200101,
    readings: ['なければなりません'],
    pos: ['exp'],
    priority: _common,
  ),
  LexiconWord(
    id: 9200102,
    readings: ['なければならない'],
    pos: ['exp'],
    priority: _common,
  ),
  LexiconWord(id: 9200113, readings: ['ならない'], pos: ['exp'], priority: _common),
  LexiconWord(id: 9200103, readings: ['なくてもいい'], pos: ['exp']),
  LexiconWord(id: 9200104, readings: ['なくてはいけない'], pos: ['exp']),
  LexiconWord(
    id: 9200105,
    readings: ['なさい'],
    pos: ['aux-v'],
    priority: _common,
  ),
  LexiconWord(id: 9200106, readings: ['なので'], pos: ['exp']),
  LexiconWord(id: 9200107, readings: ['ので'], pos: ['prt'], priority: _common),
  LexiconWord(id: 9200108, readings: ['なら'], pos: ['prt'], priority: _common),
  LexiconWord(id: 9200109, readings: ['た'], pos: ['aux-v'], priority: _common),
  LexiconWord(id: 9200110, readings: ['だけど'], pos: ['conj'], priority: _common),
  LexiconWord(id: 9200111, readings: ['も'], pos: ['prt'], priority: _common),
  LexiconWord(id: 9200112, readings: ['の'], pos: ['prt'], priority: _common),
];

InMemoryLexicon stemLexicon() => InMemoryLexicon([...stemWords, ...testWords]);

/// One Japanese sentence per line, nothing on the Korean pass.
OcrScan sentencePage(List<String> sentences) => scan(
  ja: [for (final (i, s) in sentences.indexed) line(s, 0.1, 0.1 + 0.1 * i)],
);
