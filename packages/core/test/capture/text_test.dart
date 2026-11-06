import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/capture/text/py.dart';
import 'package:test/test.dart';

void main() {
  group('character classes', () {
    test('kana, kanji and hangul ranges match the reference', () {
      expect(isHira('ぁ'.runes.first), isTrue);
      expect(isKata('ヿ'.runes.first), isTrue);
      expect(isKanji('々'.runes.first), isTrue);
      expect(isKanji('鿿'.runes.first), isTrue);
      expect(isHangul('힣'.runes.first), isTrue);
      expect(
        isHangul('ㅇ'.runes.first),
        isFalse,
        reason: 'compatibility jamo is not a syllable',
      );
    });

    test('kanaOnly ignores spaces and slashes but needs at least one kana', () {
      expect(kanaOnly('し/よん'), isTrue);
      expect(kanaOnly(' / '), isFalse);
      expect(kanaOnly('しち 7'), isFalse);
    });

    test('ratio skips whitespace and returns 0 for blank text', () {
      expect(ratio('가나 ab', isHangul), 0.5);
      expect(ratio('   ', isHangul), 0.0);
    });
  });

  group('python helpers', () {
    test('median averages the two middle values for even counts', () {
      expect(median([3.0, 1.0, 2.0]), 2.0);
      expect(median([4.0, 1.0, 3.0, 2.0]), 2.5);
    });

    test('stableSorted keeps the input order on ties', () {
      final items = [('a', 1), ('b', 0), ('c', 1), ('d', 0)];
      final sorted = stableSorted(items, (p, q) => cmpNum(p.$2, q.$2));
      expect(sorted.map((e) => e.$1), ['b', 'd', 'a', 'c']);
      expect(items.first.$1, 'a', reason: 'input is not mutated');
    });

    test('minBy returns the first minimal element', () {
      expect(minBy(['bb', 'a', 'c'], (s) => s.length), 'a');
      expect(minBy(<String>[], (s) => s.length), isNull);
    });

    test('pyRound2 matches Python round(x, 2) including half-even ties', () {
      const cases = <(double, double)>[
        (0.125, 0.12),
        (0.375, 0.38),
        (0.625, 0.62),
        (0.875, 0.88),
        (-0.125, -0.12),
        (0.1275, 0.13),
        (0.135, 0.14),
        (0.145, 0.14),
        (0.2849999, 0.28),
        (0.0049, 0.0),
        (1.005, 1.0),
        (0.115, 0.12),
      ];
      for (final (input, expected) in cases) {
        expect(pyRound2(input), expected, reason: '$input');
      }
    });

    test('pad4 formats like Python f"{k:04d}"', () {
      expect(pad4(16), '0016');
      expect(pad4(1412), '1412');
      expect(pad4(-1), '-001');
    });

    test('stripChars removes only the given characters from both ends', () {
      expect(stripChars(' . 강, 개천 .', ' .'), '강, 개천');
    });

    test('isDecimal accepts only non-empty digit strings', () {
      expect(isDecimal('12'), isTrue);
      expect(isDecimal('１２'), isTrue);
      expect(isDecimal(''), isFalse);
      expect(isDecimal('1a'), isFalse);
    });

    test('pyInt reads full-width digits', () {
      expect(pyInt(' １２ '), 12);
    });
  });

  test('maxBy returns the first largest, or null when empty', () {
    expect(maxBy(['a', 'bb', 'cc'], (x) => x.length), 'bb');
    expect(maxBy(<String>[], (x) => x.length), isNull);
  });
}
