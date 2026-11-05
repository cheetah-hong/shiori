import 'package:dict_jmdict/dict_jmdict.dart';
import 'package:test/test.dart';

import 'support/mini_dictionary.dart';

void main() {
  late JmdictDictionary dict;

  setUp(() => dict = openMiniDictionary());
  tearDown(() => dict.close());

  group('hasPair', () {
    test('accepts a headword with one of its readings', () {
      expect(dict.hasPair('二', 'に'), isTrue);
      expect(dict.hasPair('四', 'よん'), isTrue);
      expect(dict.hasPair('四', 'し'), isTrue);
      expect(dict.hasPair('夕べ', 'ゆうべ'), isTrue);
    });

    test('rejects a reading of another word', () {
      expect(dict.hasPair('二', 'さん'), isFalse);
      expect(dict.hasPair('夕行', 'たぎょう'), isFalse);
      expect(dict.hasPair('タベ', 'ゆうべ'), isFalse);
    });

    test('respects re_restr and re_nokanji', () {
      expect(dict.hasPair('円柱', 'えんちゅう'), isTrue);
      expect(dict.hasPair('丸柱', 'えんちゅう'), isFalse);
      expect(dict.hasPair('お洒落', 'オシャレ'), isFalse);
      expect(dict.hasPair('お洒落', 'おしゃれ'), isTrue);
    });

    test('without a reading, asks whether the form exists at all', () {
      expect(dict.hasPair('じゃま', null), isTrue); // kana word
      expect(dict.hasPair('邪魔', ''), isTrue);
      expect(dict.hasPair('ゴミ', ''), isTrue);
      expect(dict.hasPair('ぬぬぬ', null), isFalse);
      expect(dict.hasPair('', 'に'), isFalse);
    });

    test('accepts search-only spellings as existing pairs', () {
      expect(dict.hasPair('御菓子', 'おかし'), isTrue);
    });
  });

  group('checkPair', () {
    PairMatch match(String h, String? r) => dict.checkPair(h, r).match;

    test('exact pairs and kana words', () {
      expect(match('二', 'に'), PairMatch.exact);
      expect(match('やりとり', null), PairMatch.exact);
      expect(dict.checkPair('二', 'に').entryId, 1461140);
    });

    test('folds hiragana and katakana', () {
      final check = dict.checkPair('てれび', '');

      expect(check.match, PairMatch.kanaScript);
      expect(check.dictionaryForm, 'テレビ');
    });

    test('accepts okurigana variants of the same reading', () {
      final check = dict.checkPair('締め切', 'しめきり');

      expect(check.match, PairMatch.spellingVariant);
      expect(check.dictionaryForm, '締め切り');
    });

    test('reports the dictionary form only when it differs', () {
      final readingOnly = dict.checkPair('二', 'ニ');

      expect(readingOnly.match, PairMatch.kanaScript);
      expect(readingOnly.dictionaryForm, isNull);
      expect(dict.checkPair('静か', 'しずか(な)').dictionaryForm, isNull);
    });

    test('strips 〜, parentheses and する / な endings', () {
      expect(match('勉強する', 'べんきょうする'), PairMatch.affixStripped);
      expect(match('静かな', 'しずかな'), PairMatch.affixStripped);
      expect(match('静か(な)', 'しずか'), PairMatch.affixStripped);
      expect(match('静か(な)', 'しずかな'), PairMatch.affixStripped);
      expect(match('〜状', 'じょう'), PairMatch.affixStripped);
      expect(dict.checkPair('勉強する', 'べんきょうする').dictionaryForm, '勉強');
    });

    test('accepts two dictionary words in a row, rendaku included', () {
      final fee = dict.checkPair('材料費', 'ざいりょうひ');

      expect(fee.match, PairMatch.compound);
      expect(fee.parts, ['材料', '費']);
      expect(match('招待状', 'しょうたいじょう'), PairMatch.compound);
      expect(match('本棚', 'ほんだな'), PairMatch.compound);
      expect(match('本棚', 'ホンダナ'), PairMatch.compound);
      expect(() => fee.parts.add('x'), throwsUnsupportedError);
    });

    test('does not let kana or wrong readings pass as compounds', () {
      expect(match('タ方', 'ゆうがた'), PairMatch.none);
      expect(match('材料費', 'ざいりょうかね'), PairMatch.none);
    });

    test('a printed reading in the other script is not a kana headword', () {
      expect(match('ニ', 'に'), PairMatch.none);
      expect(match('に', 'に'), PairMatch.exact);
      expect(match('ごみ', 'ゴミ'), PairMatch.none);
    });

    test('reports OCR confusions as not found', () {
      expect(match('タベ', 'ゆうべ'), PairMatch.none);
      expect(match('夕行', 'たぎょう'), PairMatch.none);
      expect(match('エ事', 'こうじ'), PairMatch.none);
      expect(match('', 'に'), PairMatch.none);
      expect(dict.checkPair('ぬぬ', null).isKnown, isFalse);
    });
  });
}
