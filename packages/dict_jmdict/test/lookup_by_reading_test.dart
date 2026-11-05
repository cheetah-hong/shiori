import 'package:dict_jmdict/dict_jmdict.dart';
import 'package:test/test.dart';

import 'support/mini_dictionary.dart';

void main() {
  late JmdictDictionary dict;

  setUp(() => dict = openMiniDictionary());
  tearDown(() => dict.close());

  group('lookupByReading', () {
    test('ranks the most frequent common pair first, with its reason', () {
      final found = dict.lookupByReading('に', requireKanji: true);

      expect(headwords(found).take(2), ['二', '荷']);
      expect(found.first.priority.isCommon, isTrue);
      expect(found.first.priority.nf, 1);
      expect(found.first.rankReason, 'common news1 ichi1 nf01');
      expect(found.first.partsOfSpeech, contains('num'));
      expect(found.first.glosses, ['two', '2']);
      expect(found.first.isKanaOnly, isFalse);
      expect(
        dict
            .lookupByReading('に', limit: 50)
            .firstWhere((c) => c.headword == 'に')
            .isKanaOnly,
        isTrue,
      );
    });

    test('puts numbers before their homophones', () {
      expect(headwords(dict.lookupByReading('さん', limit: 3)), ['三', '酸', '賛']);
      expect(dict.lookupByReading('はち').first.headword, '八');
      expect(dict.lookupByReading('じゅう').first.headword, '十');
    });

    test('offers kana headwords only for words written in kana', () {
      final all = headwords(dict.lookupByReading('に', limit: 50));
      final kanjiOnly = headwords(
        dict.lookupByReading('に', limit: 50, requireKanji: true),
      );

      expect(all, contains('に')); // the particle has no kanji form
      expect(kanjiOnly, isNot(contains('に')));
    });

    test('uses the pair priority, not the kanji form alone', () {
      // 獣 is common as けもの; read じゅう it carries no tag.
      final juu = dict.lookupByReading('じゅう', limit: 50);
      final beast = juu.firstWhere((c) => c.headword == '獣');

      expect(beast.priority, Priority.none);
      expect(
        headwords(juu).indexOf('獣'),
        greaterThan(headwords(juu).indexOf('銃')),
      );
    });

    test('ranks rare and outdated forms after normal ones', () {
      final ni = headwords(dict.lookupByReading('に', limit: 50));

      expect(ni.indexOf('貳'), greaterThan(ni.indexOf('丹'))); // 貳 is oK
    });

    test('puts an entry\'s untagged variant spellings after other words', () {
      final ni = headwords(dict.lookupByReading('に', limit: 50));

      expect(
        ni.indexOf('２'),
        greaterThan(ni.indexOf('煮')),
      ); // ２ is a variant of 二
    });

    test('ranks the preferred word class first but never filters by it', () {
      final particle = dict.lookupByReading('に', prefer: {WordClass.particle});
      final noKanjiParticle = dict.lookupByReading(
        'に',
        requireKanji: true,
        prefer: {WordClass.particle},
      );

      expect(particle.first.headword, 'に');
      expect(noKanjiParticle.first.headword, '二');
    });

    test('leaves out search-only forms', () {
      final okashi = headwords(dict.lookupByReading('おかし', limit: 50));

      expect(okashi, contains('お菓子'));
      expect(okashi, isNot(contains('御菓子'))); // sK
    });

    test('respects re_restr and re_nokanji', () {
      expect(headwords(dict.lookupByReading('えんちゅう')), ['円柱']);
      // まるばしら has no re_restr, so it goes with both kanji forms.
      expect(headwords(dict.lookupByReading('まるばしら')), ['円柱', '丸柱']);
      // オシャレ is re_nokanji: お洒落 comes only through the hiragana reading.
      final oshare = dict.lookupByReading('オシャレ');
      expect(headwords(oshare), containsAll(['お洒落', 'オシャレ']));
      expect(oshare.firstWhere((c) => c.headword == 'お洒落').reading, 'おしゃれ');
      expect(oshare.firstWhere((c) => c.headword == 'オシャレ').reading, 'オシャレ');
    });

    test('finds katakana readings from hiragana input', () {
      expect(headwords(dict.lookupByReading('てれび')), ['テレビ']);
    });

    test('returns nothing for empty input or a zero limit', () {
      expect(dict.lookupByReading(' '), isEmpty);
      expect(dict.lookupByReading('に', limit: 0), isEmpty);
      expect(dict.lookupByReading('ぬぬぬ'), isEmpty);
    });
  });

  group('lookupByHeadword', () {
    test('returns every reading of a kanji headword', () {
      final yon = dict.lookupByHeadword('四');

      expect(yon.first.readings, containsAll(['し', 'よん']));
      expect(yon.first.priority.isCommon, isTrue);
    });

    test('keeps readings restricted to other kanji forms out', () {
      expect(dict.lookupByHeadword('丸柱').single.readings, ['まるばしら']);
    });

    test('matches kana headwords in either script', () {
      final gomi = dict.lookupByHeadword('ゴミ');

      expect(gomi.map((w) => w.headword), contains('ごみ'));
    });

    test('returns one word per entry for a kana headword', () {
      final gomi = dict.lookupByHeadword('ごみ');
      final ids = gomi.map((w) => w.entryId).toList();

      expect(ids.toSet(), hasLength(ids.length));
      expect(
        gomi.firstWhere((w) => w.entryId == 1369900).readings,
        containsAll(['ごみ', 'ゴミ']),
      );
      expect(() => gomi.first.readings.add('x'), throwsUnsupportedError);
    });

    test('finds kanji-table forms that are not kanji (２)', () {
      expect(dict.lookupByHeadword('２').single.readings, contains('に'));
    });

    test('returns nothing for unknown or empty headwords', () {
      expect(dict.lookupByHeadword('夕行'), isEmpty);
      expect(dict.lookupByHeadword(''), isEmpty);
    });
  });
}
