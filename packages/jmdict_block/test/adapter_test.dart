// The adapter over the JMdict test fixture (JMdict data only).
import 'package:jmdict_block/jmdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/mini.dart';

void main() {
  late JmdictDictionaryAdapter dict;

  setUp(() => dict = openMiniAdapter());
  tearDown(() => dict.close());

  List<String> headwords(List<DictionaryEntry> found) => [
    for (final e in found) e.headword,
  ];

  group('byReading', () {
    test('homophones come best first', () async {
      expect(headwords(await dict.byReading('に')).first, '二');
      expect(headwords(await dict.byReading('さん')), contains('三'));
    });

    test('a printed reading is not offered back as its own headword', () async {
      expect(headwords(await dict.byReading('に')), isNot(contains('に')));
    });

    test('limit and the reading travel with each entry', () async {
      final found = await dict.byReading('さん', limit: 2);
      expect(found, hasLength(lessThanOrEqualTo(2)));
      for (final e in found) {
        expect(e.readings, ['さん']);
      }
    });

    test('a POS hint never removes words', () async {
      final plain = headwords(await dict.byReading('ひ', limit: 20));
      final hinted = headwords(
        await dict.byReading('ひ', limit: 20, pos: PartOfSpeech.noun),
      );
      expect(hinted.toSet(), plain.toSet());
      expect(hinted.first, '日');
    });

    test('an empty reading finds nothing', () async {
      expect(await dict.byReading(''), isEmpty);
    });
  });

  test('byHeadword returns the word and its readings', () async {
    final found = await dict.byHeadword('二');
    expect(found.first.headword, '二');
    expect(found.first.readings, contains('に'));
  });

  group('checkPair', () {
    test('known, compound only, not found', () async {
      expect(await dict.checkPair('二', ['に']), PairStatus.known);
      expect(await dict.checkPair('材料費', ['ざいりょうひ']), PairStatus.compoundOnly);
      expect(await dict.checkPair('夕行', ['たぎょう']), PairStatus.notFound);
    });

    test('textbook spellings the dictionary allows are known', () async {
      expect(await dict.checkPair('勉強する', ['べんきょうする']), PairStatus.known);
      expect(await dict.checkPair('てれび', const []), PairStatus.known);
    });

    test('a な-adjective printed with だ is known', () async {
      expect(await dict.checkPair('静かだ', ['しずかだ']), PairStatus.known);
      expect(await dict.checkPair('静かだ', const []), PairStatus.known);
    });

    test('a kana word is checked without a reading', () async {
      expect(await dict.checkPair('テレビ', const []), PairStatus.known);
      expect(await dict.checkPair('てれぶ', const []), PairStatus.notFound);
    });

    test('every reading must match', () async {
      expect(await dict.checkPair('二', ['に', 'さん']), PairStatus.notFound);
    });

    test('an empty headword is not found', () async {
      expect(await dict.checkPair('', ['に']), PairStatus.notFound);
    });
  });

  group('fixHeadword', () {
    test('look-alike glyphs become the dictionary headword', () async {
      expect((await dict.fixHeadword('ー日', 'いちにち')).first, '一日');
      expect((await dict.fixHeadword('タ方', 'ゆうがた')).first, '夕方');
    });

    test('a broken katakana word goes back to katakana', () async {
      expect((await dict.fixHeadword('夕行', 'たぎょう')).first, 'タ行');
    });

    test('nothing to fix gives no headwords; limit is kept', () async {
      expect(await dict.fixHeadword('雨傘具', 'あまがさぐ'), isEmpty);
      expect(
        await dict.fixHeadword('ー日', 'いちにち', limit: 1),
        hasLength(lessThanOrEqualTo(1)),
      );
    });
  });

  group('wordClassesFor', () {
    test('every textbook badge maps to dictionary word classes', () {
      for (final pos in PartOfSpeech.values) {
        expect(wordClassesFor(pos), isNotEmpty, reason: pos.name);
      }
      expect(wordClassesFor(null), isEmpty);
    });

    test('badges map to the classes they name', () {
      expect(wordClassesFor(PartOfSpeech.noun), {WordClass.noun});
      expect(wordClassesFor(PartOfSpeech.verb), {WordClass.verb});
      expect(wordClassesFor(PartOfSpeech.adjective), {
        WordClass.iAdjective,
        WordClass.naAdjective,
      });
      expect(wordClassesFor(PartOfSpeech.prenominal), {WordClass.adnominal});
    });
  });

  test('the data notice comes from the database', () {
    expect(dict.info.attribution, contains('JMdict'));
    expect(dict.info.sourceSha256, hasLength(64));
  });
}
