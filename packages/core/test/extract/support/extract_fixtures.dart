// Shared data for the word extractor tests: a small lexicon whose values were
// checked against JMdict (2026-11-04 edition), and helpers that build OCR scans.
import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/shiori_core.dart';

/// Words the unit tests use, with their JMdict id, POS codes and priority.
const List<LexiconWord> testWords = [
  LexiconWord(
    id: 1172910,
    kanji: ['運動'],
    readings: ['うんどう'],
    pos: ['n', 'vs', 'vi'],
    priority: 5,
    nf: 1,
  ),
  LexiconWord(
    id: 1370420,
    kanji: ['図書館'],
    readings: ['としょかん'],
    pos: ['n'],
    priority: 5,
    nf: 5,
  ),
  LexiconWord(
    id: 1358280,
    kanji: ['食べる'],
    readings: ['たべる'],
    pos: ['v1', 'vt'],
    priority: 6,
    nf: 25,
  ),
  LexiconWord(
    id: 1343950,
    kanji: ['書く'],
    readings: ['かく'],
    pos: ['v5k', 'vt'],
    priority: 4,
  ),
  LexiconWord(
    id: 1578850,
    kanji: ['行く'],
    readings: ['いく'],
    pos: ['v5k-s', 'vi', 'aux-v'],
    priority: 4,
  ),
  // 行った could also be 行う in the past: kept here so the irregular rule must win.
  LexiconWord(
    id: 1589060,
    kanji: ['行う'],
    readings: ['おこなう'],
    pos: ['v5u', 'vt'],
    priority: 5,
    nf: 1,
  ),
  LexiconWord(
    id: 1547720,
    kanji: ['来る'],
    readings: ['くる'],
    pos: ['vk', 'vi', 'aux-v'],
    priority: 5,
    nf: 16,
    usuallyKana: true,
  ),
  LexiconWord(
    id: 1157170,
    kanji: ['為る'],
    readings: ['する'],
    pos: ['vs-i', 'vi', 'vt', 'suf', 'aux-v'],
    usuallyKana: true,
  ),
  LexiconWord(
    id: 1381820,
    kanji: ['静か'],
    readings: ['しずか'],
    pos: ['adj-na'],
    priority: 5,
    nf: 5,
  ),
  LexiconWord(
    id: 1283190,
    kanji: ['高い'],
    readings: ['たかい'],
    pos: ['adj-i'],
    priority: 5,
    nf: 8,
  ),
  LexiconWord(
    id: 1456360,
    kanji: ['読む'],
    readings: ['よむ'],
    pos: ['v5m', 'vt'],
    priority: 5,
    nf: 12,
  ),
  LexiconWord(
    id: 1499320,
    kanji: ['部屋'],
    readings: ['へや'],
    pos: ['n'],
    priority: 5,
    nf: 2,
  ),
  LexiconWord(
    id: 1270590,
    kanji: ['ご飯'],
    readings: ['ごはん'],
    pos: ['n'],
    priority: 4,
  ),
  LexiconWord(
    id: 1206730,
    kanji: ['学校'],
    readings: ['がっこう'],
    pos: ['n'],
    priority: 5,
    nf: 1,
  ),
  LexiconWord(
    id: 1402540,
    kanji: ['走る'],
    readings: ['はしる'],
    pos: ['v5r', 'vi'],
    priority: 5,
    nf: 10,
  ),
  LexiconWord(
    id: 1008630,
    kanji: ['迚も'],
    readings: ['とても'],
    pos: ['adv'],
    priority: 4,
    usuallyKana: true,
  ),
  LexiconWord(
    id: 1584930,
    kanji: ['余り'],
    readings: ['あまり'],
    pos: ['n', 'adj-no', 'adv', 'adj-na', 'n-suf'],
    priority: 5,
    nf: 15,
    usuallyKana: true,
  ),
  // に is also the number 二: a kana に in a sentence must stay the particle.
  LexiconWord(
    id: 1461140,
    kanji: ['二'],
    readings: ['に'],
    pos: ['num'],
    priority: 5,
    nf: 1,
  ),
  LexiconWord(id: 2029010, readings: ['を'], pos: ['prt'], priority: 16),
  LexiconWord(id: 2028990, readings: ['に'], pos: ['prt', 'conj'], priority: 16),
  LexiconWord(id: 2028930, readings: ['が'], pos: ['prt', 'conj'], priority: 16),
  LexiconWord(id: 2028920, readings: ['は'], pos: ['prt'], priority: 16),
  LexiconWord(id: 2029110, readings: ['な'], pos: ['prt', 'int'], priority: 16),
  LexiconWord(
    id: 1628500,
    readings: ['です'],
    pos: ['cop', 'aux-v'],
    priority: 16,
  ),
  LexiconWord(
    id: 2089020,
    readings: ['だ'],
    pos: ['aux-v', 'cop'],
    priority: 16,
  ),
  // Not a word: a noun spelled like the false v1 base of 高くない (T7).
  LexiconWord(id: 9000001, kanji: ['高くる'], readings: ['たかくる'], pos: ['n']),
];

InMemoryLexicon testLexicon() => InMemoryLexicon(testWords);

/// Korean words for a headword, standing in for a Korean gloss block.
Future<List<String>> testGlosses(
  String headword,
  List<String> readings,
) async =>
    const {
      '食べる': ['먹다'],
      '走る': ['달리다'],
    }[headword] ??
    const [];

/// One OCR line; `w` defaults to a width from the character count.
OcrLine line(
  String t,
  double x,
  double y, {
  double? w,
  double h = 0.02,
  double c = 1.0,
}) => OcrLine(
  text: t,
  x: x,
  y: y,
  width: w ?? t.runes.length * h * 0.95,
  height: h,
  confidence: c,
);

/// A scan whose two passes hold [ja] and [ko].
OcrScan scan({List<OcrLine> ja = const [], List<OcrLine> ko = const []}) =>
    OcrScan(
      japanese: OcrPage(
        lines: ja,
        engine: 'test',
        languages: const ['ja-JP', 'ko-KR'],
      ),
      korean: OcrPage(
        lines: ko,
        engine: 'test',
        languages: const ['ko-KR', 'ja-JP'],
      ),
    );

/// A line both passes read the same way (mixed Japanese and Korean text).
OcrScan sameInBoth(List<OcrLine> lines) => scan(ja: lines, ko: lines);

/// The synthetic set for the word extractor (tools/synthetic/make_general_pages.py).
const String generalDir = 'test/fixtures/synthetic_general';

Map<String, Object?> readGeneralJson(String name) =>
    (jsonDecode(File('$generalDir/$name').readAsStringSync()) as Map)
        .cast<String, Object?>();

Future<OcrScan> loadGeneralScan(String fixture) => FixtureTextRecognizer(
  (name) => File('$generalDir/$name').readAsString(),
).recognize(PageImage(fixture));

InMemoryLexicon generalLexicon() =>
    InMemoryLexicon.fromJson(readGeneralJson('lexicon.json'));
