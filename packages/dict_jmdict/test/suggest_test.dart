import 'package:dict_jmdict/dict_jmdict.dart';
import 'package:test/test.dart';

import 'support/mini_dictionary.dart';

void main() {
  late JmdictDictionary dict;

  setUp(() => dict = openMiniDictionary());
  tearDown(() => dict.close());

  List<String> suggest(String ocr, String? reading) => [
    for (final s in dict.suggestHeadword(ocr, reading)) s.headword,
  ];

  group('suggestHeadword with a missing headword', () {
    test('offers headwords for the reading, best first', () {
      final ni = dict.suggestHeadword('', 'に');

      expect(ni.first.headword, '二');
      expect(ni.first.basis, SuggestionBasis.readingOnly);
      expect(suggest('', 'さん').take(3), ['三', '酸', '賛']);
    });

    test('never offers the bare reading as the headword', () {
      expect(suggest('', 'に'), isNot(contains('に')));
      expect(suggest('', 'さん'), isNot(contains('さん')));
    });
  });

  group('suggestHeadword with OCR text', () {
    test('fixes look-alike glyphs, as the rule-based corrector does', () {
      expect(suggest('ー', 'いち').first, '一');
      expect(suggest('+', 'じゅう').first, '十');
      expect(suggest('ハ', 'はち').first, '八');
      expect(suggest('エ事', 'こうじ').first, '工事');
      expect(suggest('エ場', 'こうじょう').first, '工場');
      expect(suggest('タ方', 'ゆうがた').first, '夕方');
    });

    test('reports each edit with its kind', () {
      final yuube = dict.suggestHeadword('タベ', 'ゆうべ').first;

      expect(yuube.headword, '夕べ');
      expect(yuube.edits, const [
        GlyphEdit(0, 'タ', '夕', GlyphEditKind.lookAlike),
        GlyphEdit(1, 'ベ', 'べ', GlyphEditKind.kanaScript),
      ]);
      expect(yuube.confirmsOcr, isFalse);
    });

    test('undoes a wrong rule correction (夕行 → タ行)', () {
      final s = dict.suggestHeadword('夕行', 'たぎょう').single;

      expect(s.headword, 'タ行');
      expect(s.edits.single.kind, GlyphEditKind.lookAlike);
    });

    test('prefers a kanji over the bare reading in the other script', () {
      // The particle に matches ニ by script alone, but a printed reading
      // means the headword is not just that kana, so it comes last.
      expect(suggest('ニ', 'に'), ['二', 'に']);
    });

    test('passes the word-class preference through', () {
      expect(
        dict.suggestHeadword('', 'に', prefer: {WordClass.noun}).first.headword,
        '二',
      );
    });

    test('confirms OCR text that is already a dictionary form', () {
      expect(dict.suggestHeadword('タ行', 'たぎょう').first.confirmsOcr, isTrue);
      expect(dict.suggestHeadword('二', 'に').first.confirmsOcr, isTrue);
      expect(dict.suggestHeadword('ハ長調', 'ハちょうちょう').first.confirmsOcr, isTrue);
    });

    test('returns nothing when no confusion explains the text', () {
      expect(suggest('荷物', 'に'), isEmpty);
      expect(suggest('三', 'に'), isEmpty);
    });

    test('ignores spaces and respects the limit', () {
      expect(suggest(' エ 事 ', 'こうじ').first, '工事');
      expect(dict.suggestHeadword('', 'じゅう', limit: 2), hasLength(2));
      expect(dict.suggestHeadword('', 'に', limit: 0), isEmpty);
      expect(dict.suggestHeadword('', ''), isEmpty);
    });
  });

  test('never suggests search-only forms', () {
    // 御菓子 is a search-only (sK) spelling of お菓子.
    expect(dict.hasPair('御菓子', 'おかし'), isTrue);
    expect(suggest('御菓子', 'おかし'), isNot(contains('御菓子')));
    expect(suggest('御菓子', ''), isNot(contains('御菓子')));
  });

  group('suggestHeadword without a reading', () {
    test('passes the word-class preference through', () {
      // ニ could be 二 (kanji) or the particle に (kana): the hint decides.
      expect(
        dict
            .suggestHeadword('ニ', '', prefer: {WordClass.particle})
            .first
            .headword,
        'に',
      );
      expect(
        dict.suggestHeadword('ニ', '', prefer: {WordClass.noun}).first.headword,
        '二',
      );
    });

    test('fixes long vowel marks read as 一 in kana words', () {
      final coffee = dict.suggestHeadword('コ一ヒ一', null).single;

      expect(coffee.headword, 'コーヒー');
      expect(coffee.edits, hasLength(2));
    });

    test('finds kanji forms and kana words in either script', () {
      expect(suggest('ニ', ''), contains('二'));
      expect(suggest('てれび', '').first, 'テレビ');
      expect(dict.suggestHeadword('邪魔', '').first.candidate.reading, 'じゃま');
    });
  });
}
