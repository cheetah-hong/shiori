// E4: the look-alike glyph fixes of the row templates, applied to the
// general extractor's headwords — only when the dictionary confirms them.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

/// The synthetic general lexicon without [drop].
InMemoryLexicon _lexiconWithout(String drop) {
  final json = readGeneralJson('lexicon.json');
  final entries = [
    for (final e in (json['entries'] as List).cast<Map<String, Object?>>())
      if (!(e['kanji'] as List).contains(drop)) e,
  ];
  return InMemoryLexicon.fromJson({'entries': entries});
}

void main() {
  test('g06: 人ロ (katakana ロ) becomes 人口 when the dictionary has 人口, '
      'with the reason', () async {
    final r = await GeneralExtractor(
      lexicon: generalLexicon(),
    ).extract(await loadGeneralScan('g06'));

    final w = r.words.singleWhere((w) => w.headword == '人口');
    expect(w.headwordNote, contains('글자 보정+사전'));
    expect(w.headwordNote, contains('人ロ'));
    expect(w.meaning, '인구');
    expect(w.readings, ['じんこう']);
    expect(w.readingSource, FieldSource.dictionary);

    final entry = w.toCapturedEntry(fragments: r.fragments);
    expect(entry.headword, '人口');
    expect(entry.evidence!.of(EntryField.headword)!.note, contains('글자 보정+사전'));
    expect(entry.statusOf(EntryField.headword), FieldStatus.corrected);
  });

  test('without 人口 in the dictionary the headword is not changed', () async {
    final r = await GeneralExtractor(
      lexicon: _lexiconWithout('人口'),
    ).extract(await loadGeneralScan('g06'));

    expect(r.words.where((w) => w.headword == '人口'), isEmpty);
    expect(r.fragments.where((f) => f.text == '人ロ'), isNotEmpty);
  });

  test('a lone look-alike inside a known word is left alone', () async {
    // カ月 is a word as printed: no change even though 力月 would be one glyph off.
    final lexicon = InMemoryLexicon(const [
      LexiconWord(id: 1, kanji: ['カ月'], readings: ['かげつ'], pos: ['n']),
      LexiconWord(id: 2, kanji: ['力月'], readings: ['りきげつ'], pos: ['n']),
    ]);
    final r = await GeneralExtractor(
      lexicon: lexicon,
    ).extract(scan(ja: [line('カ月', 0.1, 0.1), line('かげつ', 0.25, 0.1)]));

    expect(r.words.single.headword, 'カ月');
    expect(r.words.single.headwordNote, isNull);
  });
}
