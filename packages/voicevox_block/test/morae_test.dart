import 'package:test/test.dart';
import 'package:voicevox_block/voicevox_block.dart';

void main() {
  group('splitMorae', () {
    test('a small kana joins the kana before it', () {
      expect(splitMorae('きょう'), ['きょ', 'う']);
      expect(splitMorae('シャツ'), ['シャ', 'ツ']);
      expect(splitMorae('ファイル'), ['ファ', 'イ', 'ル']);
    });

    test('ん, っ and ー are morae of their own', () {
      expect(splitMorae('がっこう'), ['が', 'っ', 'こ', 'う']);
      expect(splitMorae('せんせい'), ['せ', 'ん', 'せ', 'い']);
      expect(splitMorae('ケーキ'), ['ケ', 'ー', 'キ']);
    });

    test('empty text has no morae', () {
      expect(splitMorae(''), isEmpty);
    });
  });

  test('kana conversion leaves other characters alone', () {
    expect(toKatakana('はしが'), 'ハシガ');
    expect(toKatakana('箸です'), '箸デス');
    expect(toHiragana('ハシ'), 'はし');
    expect(toHiragana('パンー'), 'ぱんー');
  });

  group('pitchPattern (word + one particle slot)', () {
    List<String> hl(int morae, int accent) => [
      for (final h in pitchPattern(morae: morae, accent: accent)) h ? 'H' : 'L',
    ];

    test('flat rises after the first mora and stays up', () {
      expect(hl(2, 0).join(), 'LHH');
      expect(hl(4, 0).join(), 'LHHHH');
    });

    test('head-high starts high and falls after the first mora', () {
      expect(hl(2, 1).join(), 'HLL');
      expect(hl(3, 1).join(), 'HLLL');
    });

    test('middle and tail accents fall after the n-th mora', () {
      expect(hl(3, 2).join(), 'LHLL');
      expect(hl(4, 3).join(), 'LHHLL');
      expect(hl(2, 2).join(), 'LHL');
    });

    test('a one-mora word', () {
      expect(hl(1, 1).join(), 'HL');
      expect(hl(1, 0).join(), 'LH');
    });

    test('an accent past the last mora is refused', () {
      expect(() => pitchPattern(morae: 2, accent: 3), throwsArgumentError);
      expect(() => pitchPattern(morae: 0, accent: 0), throwsArgumentError);
    });
  });
}
