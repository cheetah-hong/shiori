// Made-up words (ids out of JMdict's range) for the tests of an adverb
// before a negative, an expression entry read as its verb, and the sentence
// words left out (one kana, a kanji after a number, a related-word note).
import 'package:shiori_core/shiori_core.dart';

import 'extract_fixtures.dart';

/// A common entry (spec1): the cost band of everyday words.
const int _common = 16;

const List<LexiconWord> smallQualityWords = [
  // An adverb with a sense for a negative after it and one without.
  LexiconWord(
    id: 9300001,
    kanji: ['霧別に'],
    readings: ['むべつに'],
    pos: ['adv'],
    priority: _common,
  ),
  // A 五段 verb and expression entries of its forms.
  LexiconWord(
    id: 9300002,
    kanji: ['霧る'],
    readings: ['むる'],
    pos: ['v5r', 'vi'],
    priority: _common,
  ),
  LexiconWord(
    id: 9300003,
    kanji: ['霧った'],
    readings: ['むった'],
    pos: ['exp', 'adj-f'],
    priority: _common,
  ),
  LexiconWord(
    id: 9300004,
    kanji: ['霧ります'],
    readings: ['むります'],
    pos: ['exp'],
    priority: _common,
  ),
  LexiconWord(
    id: 9300005,
    kanji: ['霧らない'],
    readings: ['むらない'],
    pos: ['exp'],
    priority: _common,
  ),
  // A verb whose past form is registered as a prenominal (adj-f) only.
  LexiconWord(
    id: 9300006,
    kanji: ['雲る'],
    readings: ['くもる'],
    pos: ['v5r', 'vi'],
    priority: _common,
  ),
  LexiconWord(
    id: 9300007,
    kanji: ['雲った'],
    readings: ['くもった'],
    pos: ['adj-f'],
    priority: _common,
  ),
  // An expression that is no form of a verb.
  LexiconWord(
    id: 9300008,
    kanji: ['霧霧'],
    readings: ['むむ'],
    pos: ['exp'],
    priority: _common,
  ),
  // A one-kanji noun, and ある (な is the stem of its negative).
  LexiconWord(
    id: 9300009,
    kanji: ['霧'],
    readings: ['む'],
    pos: ['n'],
    priority: _common,
  ),
  LexiconWord(
    id: 9300010,
    kanji: ['在る'],
    readings: ['ある'],
    pos: ['v5r-i', 'vi'],
    priority: _common,
  ),
  LexiconWord(
    id: 9300011,
    kanji: ['霧話'],
    readings: ['むわ'],
    pos: ['n', 'vs'],
    priority: _common,
  ),
  LexiconWord(id: 9300101, readings: ['ね'], pos: ['prt'], priority: _common),
];

InMemoryLexicon smallQualityLexicon() =>
    InMemoryLexicon([...smallQualityWords, ...testWords]);
