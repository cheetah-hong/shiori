import 'package:dict_jmdict/dict_jmdict.dart';
import 'package:dict_jmdict/src/kana.dart' show withoutRendaku, isKanji;
import 'package:dict_jmdict/src/spelling.dart'
    show isOkuriganaVariant, stripAffixes;
import 'package:test/test.dart';

void main() {
  group('kana', () {
    test('folds between hiragana and katakana', () {
      expect(toHiragana('テレビ'), 'てれび');
      expect(toHiragana('コーヒー'), 'こーひー');
      expect(toKatakana('ごみ'), 'ゴミ');
      expect(toHiragana('夕ベ'), '夕べ');
    });

    test('classifies characters', () {
      expect(hasKanji('夕べ'), isTrue);
      expect(hasKanji('タベ'), isFalse);
      expect(isKanaOnly('やりとり'), isTrue);
      expect(isKanaOnly(''), isFalse);
      expect(isKanji('々'.runes.single), isTrue);
    });

    test('removes rendaku from the first kana only', () {
      expect(withoutRendaku('がわ'), 'かわ');
      expect(withoutRendaku('ばしら'), 'はしら');
      expect(withoutRendaku('かわ'), isNull);
      expect(withoutRendaku(''), isNull);
      expect(withoutRendaku('ガワ'), isNull); // callers fold katakana first
    });
  });

  group('confusables', () {
    test('uses the reference corrector table in both directions', () {
      expect(confusableWhole['ー'], '一');
      expect(confusableInKanji['タ'], '夕');
      expect(areConfusable('タ'.runes.single, '夕'.runes.single), isTrue);
      expect(areConfusable('夕'.runes.single, 'タ'.runes.single), isTrue);
      expect(areConfusable('-'.runes.single, 'ー'.runes.single), isTrue);
      expect(areConfusable('タ'.runes.single, 'タ'.runes.single), isFalse);
      expect(areConfusable('タ'.runes.single, '口'.runes.single), isFalse);
    });

    test('glyphEdits lists changes or rejects unrelated text', () {
      expect(glyphEdits('工事', '工事'), isEmpty);
      expect(glyphEdits('エ事', '工事'), const [
        GlyphEdit(0, 'エ', '工', GlyphEditKind.lookAlike),
      ]);
      expect(glyphEdits('工事', '工場'), isNull);
      expect(glyphEdits('工', '工事'), isNull);
    });

    test('glyphVariants enumerates fewest changes first, within the cap', () {
      final v = glyphVariants('タベ');

      expect(v.first, 'タベ');
      expect(v, containsAll(['夕ベ', 'たベ', 'タべ', '夕べ']));
      expect(v.indexOf('夕べ'), greaterThan(v.indexOf('夕ベ')));
      expect(glyphVariants('ーーーーーーー', cap: 10), hasLength(10));
      expect(glyphVariants('abc'), ['abc']);
      expect(glyphVariants('タベ', cap: 1), ['タベ']);
      expect(glyphVariants('タベ', cap: 0), isEmpty);
      expect(() => glyphVariants('タベ').add('x'), throwsUnsupportedError);
    });
  });

  group('spelling', () {
    test('okurigana variants keep kanji and differ only in hiragana', () {
      expect(isOkuriganaVariant('締切', '締め切り'), isTrue);
      expect(isOkuriganaVariant('終る', '終わる'), isTrue);
      expect(isOkuriganaVariant('取扱い', '取り扱い'), isTrue);
      expect(isOkuriganaVariant('締め切い', '締め切り'), isFalse);
      expect(isOkuriganaVariant('菓子', 'お菓子'), isFalse);
      expect(isOkuriganaVariant('締め切り', '締め切り'), isFalse);
      expect(isOkuriganaVariant('しめきり', 'しめきり'), isFalse);
    });

    test('stripAffixes removes marks and endings', () {
      expect(stripAffixes('勉強する', 'べんきょうする'), ('勉強', 'べんきょう'));
      expect(stripAffixes('〜中', 'ちゅう'), ('中', 'ちゅう'));
      expect(stripAffixes('静か(な)', 'しずか'), ('静か', 'しずか'));
      expect(stripAffixes('びっくりする', ''), ('びっくり', ''));
      expect(stripAffixes('二', 'に'), isNull);
      expect(stripAffixes('する', 'する'), isNull);
    });

    test('stripAffixes reads an ending in parentheses on either side', () {
      expect(stripAffixes('静か(な)', 'しずかな'), ('静か', 'しずか'));
      expect(stripAffixes('静かな', 'しずか(な)'), ('静か', 'しずか'));
      expect(stripAffixes('勉強（する）', 'べんきょうする'), ('勉強', 'べんきょう'));
      expect(stripAffixes('(お)茶', 'ちゃ'), ('茶', 'ちゃ'));
    });

    test('stripAffixes removes the だ of a な-adjective written with kanji', () {
      expect(stripAffixes('静かだ', 'しずかだ'), ('静か', 'しずか'));
      expect(stripAffixes('静かだ', ''), ('静か', ''));
    });

    test('stripAffixes keeps the だ of a word without kanji', () {
      expect(stripAffixes('ただ', ''), anyOf(isNull, ('ただ', '')));
      expect(stripAffixes('まだ', ''), anyOf(isNull, ('まだ', '')));
      expect(stripAffixes('ただ', 'ただ'), anyOf(isNull, ('ただ', 'ただ')));
    });
  });

  group('WordClass', () {
    test('maps JMdict POS codes to textbook badges', () {
      expect(wordClassesOf(['v5k', 'vt']), {WordClass.verb});
      expect(wordClassesOf(['n', 'vs', 'vt', 'vi']), {WordClass.noun});
      expect(wordClassesOf(['vs-i']), {WordClass.verb});
      expect(wordClassesOf(['num']), {WordClass.noun});
      expect(wordClassesOf(['adj-i']), {WordClass.iAdjective});
      expect(wordClassesOf(['adj-na', 'n']), {
        WordClass.naAdjective,
        WordClass.noun,
      });
      expect(wordClassesOf(['adv', 'adv-to']), {WordClass.adverb});
      expect(wordClassesOf(['conj', 'int', 'adj-pn', 'prt']), {
        WordClass.conjunction,
        WordClass.interjection,
        WordClass.adnominal,
        WordClass.particle,
      });
      expect(wordClassesOf(['exp', 'aux-v', 'suf']), isEmpty);
    });
  });

  group('Priority', () {
    test('a pair keeps the tags both forms carry', () {
      const kanji = Priority(1 | 4, 14); // news1 ichi1 nf14
      const reading = Priority(4); // ichi1
      final pair = Priority.pair(kanji, reading);

      expect(pair.tags, [PriorityTag.ichi1]);
      expect(pair.nf, isNull);
      expect(Priority.pair(kanji, const Priority(1, 20)).nf, 20);
    });

    test('orders common, then nf band, then any tag, then tag count', () {
      const ordered = [
        Priority(1 | 4, 1),
        Priority(1, 5),
        Priority(4 | 16),
        Priority(4),
        Priority(2),
        Priority.none,
      ];

      expect([...ordered.reversed]..sort(), ordered);
    });

    test('prints JMdict codes', () {
      expect(const Priority(1 | 4, 3).codes, ['news1', 'ichi1', 'nf03']);
      expect(Priority.none.toString(), 'none');
      expect(const Priority(1).isCommon, isTrue);
      expect(const Priority(2).isCommon, isFalse);
    });
  });
}
