// M1, M8: the class a word is printed as moves the Korean senses of that
// class forward (never leaves one out), over the made-up sample
// (tools/dict/testdata/krdict_sample.json); a schema 1 file keeps the order
// it always had.
import 'dart:convert';
import 'dart:io';

import 'package:krdict_block/krdict_block.dart';
import 'package:krdict_block/src/korean_pos.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/mini.dart';

void main() {
  late KrdictGlossary g;
  setUp(() => g = openMini());
  tearDown(() => g.close());

  group('M1 a class hint moves its senses forward', () {
    // 静森 (made up): 고요히 (adverb, 초급) and 고요숲 (noun, 고급), both the
    // first equivalent of their sense.
    test(
      'without a hint the order is as before: the easier level first',
      () async {
        expect(await heads(g, '静森', readings: ['しずもり']), ['고요히', '고요숲']);
      },
    );

    test('a noun hint puts the noun first', () async {
      expect(await heads(g, '静森', readings: ['しずもり'], pos: PartOfSpeech.noun), [
        '고요숲',
        '고요히',
      ]);
    });

    test('an adverb hint keeps the adverb first', () async {
      expect(
        await heads(g, '静森', readings: ['しずもり'], pos: PartOfSpeech.adverb),
        ['고요히', '고요숲'],
      );
    });

    test(
      'a class no sense has keeps the order and leaves nothing out',
      () async {
        expect(
          await heads(g, '静森', readings: ['しずもり'], pos: PartOfSpeech.verb),
          ['고요히', '고요숲'],
        );
        expect(
          await heads(g, '静森', readings: ['しずもり'], pos: PartOfSpeech.particle),
          ['고요히', '고요숲'],
        );
      },
    );

    test('the hint applies before the limit', () async {
      expect(
        await heads(
          g,
          '静森',
          readings: ['しずもり'],
          limit: 1,
          pos: PartOfSpeech.noun,
        ),
        ['고요숲'],
      );
    });

    // 青む (made up): 푸름 (noun, 초급) and 푸르다 (adjective, 고급).
    test('verbs and adjectives are one class: a Japanese verb prefers a Korean '
        'adjective to a noun', () async {
      expect(await heads(g, '青む', readings: ['あおむ']), ['푸름', '푸르다']);
      for (final pos in [
        PartOfSpeech.verb,
        PartOfSpeech.iAdjective,
        PartOfSpeech.naAdjective,
        PartOfSpeech.adjective,
      ]) {
        expect(await heads(g, '青む', readings: ['あおむ'], pos: pos), [
          '푸르다',
          '푸름',
        ], reason: '$pos');
      }
    });

    // 星波 (made up): 별물결 (noun, 초급), -물결 (suffix, 중급), 반짝이
    // (adverb, 고급).
    test('a suffix (no class of its own) is never moved back', () async {
      expect(await heads(g, '星波', readings: ['ほしなみ']), ['별물결', '-물결', '반짝이']);
      expect(
        await heads(g, '星波', readings: ['ほしなみ'], pos: PartOfSpeech.adverb),
        ['-물결', '반짝이', '별물결'],
      );
      expect(
        await heads(g, '星波', readings: ['ほしなみ'], pos: PartOfSpeech.conjunction),
        ['-물결', '반짝이', '별물결'],
        reason: 'a conjunction is a Korean adverb',
      );
    });

    test('the hint does not outrank how the word matched', () async {
      // ただ: the kana word's senses (adverbs) before the kanji words read
      // ただ (공짜 noun, 한갓 adverb); among those the noun comes first.
      final plain = await heads(g, 'ただ');
      final noun = await heads(g, 'ただ', pos: PartOfSpeech.noun);
      expect(plain.take(2), ['다만', '그저']);
      expect(noun.take(2), ['다만', '그저']);
      expect(noun.indexOf('공짜'), lessThan(noun.indexOf('한갓')));
      expect(noun.toSet(), plain.toSet());
    });

    test('lookupSync takes the hint too', () {
      expect(
        g
            .lookupSync('静森', readings: ['しずもり'], pos: PartOfSpeech.noun)
            .first
            .words,
        ['고요숲'],
      );
    });
  });

  group('M8 a schema 1 file (no Korean part of speech)', () {
    late KrdictGlossary old;
    setUp(() => old = openMiniV1());
    tearDown(() => old.close());

    test('opens, and every hint gives the order without one', () async {
      for (final (headword, readings) in [
        ('ただ', <String>[]),
        ('掛ける', ['かける']),
        ('皿', ['さら']),
        ('喫茶店', ['きっさてん']),
      ]) {
        final plain = await heads(old, headword, readings: readings);
        expect(plain, isNotEmpty, reason: headword);
        for (final pos in PartOfSpeech.values) {
          expect(
            await heads(old, headword, readings: readings, pos: pos),
            plain,
            reason: '$headword $pos',
          );
        }
      }
    });

    test('gives the same senses as the schema 2 file without a hint', () async {
      for (final (headword, readings) in [
        ('ただ', <String>[]),
        ('掛ける', ['かける']),
        ('有名だ', ['ゆうめいだ']),
      ]) {
        expect(
          await old.lookup(headword, readings: readings, limit: 10),
          await g.lookup(headword, readings: readings, limit: 10),
          reason: headword,
        );
      }
    });
  });

  test(
    'the part-of-speech codes are the table build_ko_glossary.py writes',
    () {
      final table =
          (jsonDecode(File(posTable).readAsStringSync()) as Map)['codes']
              as Map;
      expect(koreanPosCodes, table.cast<String, int>());
    },
  );
}
