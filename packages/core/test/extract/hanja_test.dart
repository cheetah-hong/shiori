// Korean readings of kanji words (Unihan), used to pair headwords and meanings.
import 'package:shiori_core/src/extract/hanja.dart';
import 'package:test/test.dart';

void main() {
  test('kanji words spell their Korean readings', () {
    expect(sinoKoreanReadings('図書館'), contains('도서관'));
    expect(sinoKoreanReadings('運動'), contains('운동'));
  });

  test('a Japanese simplified form reads like its old form (験 → 驗 → 험)', () {
    expect(sinoKoreanReadings('経験'), contains('경험'));
  });

  test('the initial-sound rule applies at the start (料理 → 요리, 旅行 → 여행)', () {
    expect(sinoKoreanReadings('料理'), contains('요리'));
    expect(sinoKoreanReadings('旅行'), contains('여행'));
  });

  test('kana are skipped; unknown kanji give nothing', () {
    expect(sinoKoreanReadings('静か'), contains('정'));
    expect(sinoKoreanReadings('たべる'), isEmpty);
  });

  test('match length counts the syllables spelled in a row', () {
    expect(hanjaMatchLength('図書館', '도서관'), 3);
    expect(hanjaMatchLength('運動', '운동하다, 움직이다'), 2);
    expect(hanjaMatchLength('料理', '요리'), 2);
    expect(hanjaMatchLength('食べる', '먹다'), 0);
    expect(hanjaMatchLength('運動', '도서관'), 0);
  });
}
