// K1–K8: lookups over the made-up sample (tools/dict/testdata/krdict_sample.json).
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/mini.dart';

void main() {
  late KrdictGlossary g;
  setUp(() => g = openMini());
  tearDown(() => g.close());

  group('K1 a pair and a kana equivalent of one sense', () {
    test('食堂 read しょくどう gives 식당', () async {
      expect(await heads(g, '食堂', readings: ['しょくどう']), ['식당']);
    });

    test('レストラン gives 식당 too', () async {
      expect(await heads(g, 'レストラン'), ['식당']);
    });

    test('a hiragana spelling of the katakana word gives the same', () async {
      expect(await heads(g, 'れすとらん'), ['식당']);
    });
  });

  group('K2 the reading and the kanji are matched together', () {
    test('食堂 / しょくどう never gives 식도 (食道)', () async {
      expect(await heads(g, '食堂', readings: ['しょくどう']), isNot(contains('식도')));
    });

    test('食道 gives 식도', () async {
      expect(await heads(g, '食道', readings: ['しょくどう']), ['식도']);
    });

    test('a kanji word with another reading is not matched', () async {
      expect(await heads(g, '食堂', readings: ['たべどころ']), isEmpty);
    });

    test('a kanji word without reading is matched by its spelling', () async {
      expect(await heads(g, '食堂'), ['식당']);
    });

    test('a katakana reading matches the hiragana one', () async {
      expect(await heads(g, '食道', readings: ['ショクドウ']), ['식도']);
    });

    test('any of several readings may match', () async {
      expect(await heads(g, '村', readings: ['そん']), ['마을']);
      expect(await heads(g, '村', readings: ['いなか', 'むら']), ['마을']);
    });
  });

  group('K3 な-adjective だ and 〜する', () {
    test('有名 and 有名だ both give 유명하다', () async {
      expect(await heads(g, '有名', readings: ['ゆうめい']), ['유명하다']);
      expect(await heads(g, '有名だ', readings: ['ゆうめいだ']), ['유명하다']);
      expect(await heads(g, '有名だ'), ['유명하다']);
    });

    test('勉強する gives 공부 (the dictionary has 勉強)', () async {
      expect(await heads(g, '勉強する', readings: ['べんきょうする']), ['공부']);
      expect(await heads(g, '勉強', readings: ['べんきょう']), ['공부']);
    });

    test('a kana verb in する matches without it', () async {
      expect(await heads(g, 'ドキドキする'), ['두근두근']);
      expect(await heads(g, 'どきどき'), ['두근두근']);
    });
  });

  group('K4 kana words keep their own だ', () {
    test('た is not ただ', () async {
      expect(await heads(g, 'た'), isEmpty);
    });

    test('か is not かする', () async {
      expect(await heads(g, 'か'), isEmpty);
      expect(await heads(g, 'かする'), ['스치다']);
    });
  });

  group('K5 senses without a Japanese equivalent', () {
    test('(対訳語無し) is never a word', () async {
      expect(await heads(g, '(対訳語無し)'), isEmpty);
      expect(await heads(g, '対訳語無し'), isEmpty);
    });

    test('another language is not looked up', () async {
      expect(await heads(g, 'restaurant'), isEmpty);
    });
  });

  group('K6 order', () {
    test('first place in the equivalent list before second place', () async {
      // 찻집: 喫茶店 first (고급). 카페: カフェ first, 喫茶店 second (초급).
      expect(await heads(g, '喫茶店', readings: ['きっさてん']), ['찻집', '카페']);
    });

    test('same place: beginner level before advanced', () async {
      // 접시 (고급) comes first in the file, 그릇 (초급) second.
      expect(await heads(g, '皿', readings: ['さら']), ['그릇', '접시']);
    });

    test('same place and level: the lower sense number first', () async {
      // 맛 sense 2 comes first in the file, 미각 sense 1 second.
      expect(await heads(g, '味', readings: ['あじ']), ['미각', '맛']);
    });
  });

  group('K7 several senses', () {
    test('three senses give three meanings, limit 2 the first two', () async {
      expect(await heads(g, '掛ける', readings: ['かける']), ['걸다', '앉다', '곱하다']);
      expect(await heads(g, '掛ける', readings: ['かける'], limit: 2), ['걸다', '앉다']);
    });

    test('each meaning carries its source, level and sense number', () async {
      final senses = await g.lookup('掛ける', readings: ['かける']);
      expect(
        senses[1],
        const KoreanSense(
          words: ['앉다'],
          source: GlossarySource.krdict,
          level: GlossaryLevel.beginner,
          senseNo: 2,
        ),
      );
      expect(senses[2].level, GlossaryLevel.intermediate);
    });

    test('a synonym that translates the same word joins its meaning', () async {
      final first = (await g.lookup('ただ')).first;
      expect(first.words, ['다만', '단지']);
      expect(first.text, '다만, 단지');
    });

    test('two senses of one Korean word give one meaning', () async {
      expect(await heads(g, '近い', readings: ['ちかい']), ['가깝다']);
    });

    test('limit 0 gives nothing', () async {
      expect(await g.lookup('ただ', limit: 0), isEmpty);
    });
  });

  group('K8 a kana headword', () {
    test('kana equivalents before kanji ones with the same reading', () async {
      // 공짜 (초급) has ただ【只】; 다만, 단지, 그저 (중급) have ただ in kana.
      expect(await heads(g, 'ただ'), ['다만', '그저', '공짜', '한갓']);
    });

    test('a kanji alternative after ・ is its own spelling', () async {
      expect(await heads(g, '唯', readings: ['ただ']), ['한갓']);
      expect(await heads(g, '只', readings: ['ただ']), ['공짜', '한갓']);
    });

    test('a katakana spelling in brackets is a kana word', () async {
      expect(await heads(g, 'タバコ'), ['담배']);
      expect(await heads(g, 'たばこ'), ['담배']);
    });
  });

  test('blank input gives nothing', () async {
    expect(await heads(g, ''), isEmpty);
    expect(await heads(g, '  '), isEmpty);
  });
}
