import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';
import 'package:voicevox_block/voicevox_block.dart';

void main() {
  group('pronunciationMorae', () {
    test('turns hiragana into katakana morae', () {
      expect(pronunciationMorae('はし'), ['ハ', 'シ']);
      expect(pronunciationMorae('しゃしん'), ['シャ', 'シ', 'ン']);
    });

    test('o-row + う and e-row + い are long vowels', () {
      expect(pronunciationMorae('きょう'), ['キョ', 'オ']);
      expect(pronunciationMorae('こうえん'), ['コ', 'オ', 'エ', 'ン']);
      expect(pronunciationMorae('せんせい'), ['セ', 'ン', 'セ', 'エ']);
      expect(pronunciationMorae('とけい'), ['ト', 'ケ', 'エ']);
    });

    test('ー becomes the vowel before it', () {
      expect(pronunciationMorae('ケーキ'), ['ケ', 'エ', 'キ']);
      expect(pronunciationMorae('すーぷ'), ['ス', 'ウ', 'プ']);
      expect(pronunciationMorae('ノート'), ['ノ', 'オ', 'ト']);
    });

    test('a verb keeps its final う', () {
      expect(pronunciationMorae('おもう', pos: PartOfSpeech.verb), [
        'オ',
        'モ',
        'ウ',
      ]);
      expect(pronunciationMorae('かよう', pos: PartOfSpeech.verb), [
        'カ',
        'ヨ',
        'ウ',
      ]);
      // Not a verb: the same ending is a long vowel.
      expect(pronunciationMorae('ほうこう'), ['ホ', 'オ', 'コ', 'オ']);
    });

    test('a verb still lengthens inside the word', () {
      expect(pronunciationMorae('とうる', pos: PartOfSpeech.verb), [
        'ト',
        'オ',
        'ル',
      ]);
    });

    test('a reading with something that is not kana gives null', () {
      expect(pronunciationMorae('箸'), isNull);
      expect(pronunciationMorae(''), isNull);
      expect(pronunciationMorae('は し'), isNull);
    });
  });

  group('aquesTalkKana', () {
    test('marks the accented mora', () {
      expect(aquesTalkKana(['ハ', 'シ'], 1), "ハ'シ");
      expect(aquesTalkKana(['ハ', 'シ'], 2), "ハシ'");
      expect(aquesTalkKana(['デ', 'ン', 'ワ', 'バ', 'ン', 'ゴ', 'オ'], 4), "デンワバ'ンゴオ");
    });

    test('flat puts the mark after the last mora', () {
      expect(aquesTalkKana(['ハ', 'シ'], 0), "ハシ'");
      expect(aquesTalkKana(['ア', 'メ'], 0), "アメ'");
    });

    test('an accent outside the word is refused', () {
      expect(() => aquesTalkKana(['ハ', 'シ'], 3), throwsArgumentError);
      expect(() => aquesTalkKana(['ハ', 'シ'], -1), throwsArgumentError);
      expect(() => aquesTalkKana(const [], 0), throwsArgumentError);
    });
  });
}
