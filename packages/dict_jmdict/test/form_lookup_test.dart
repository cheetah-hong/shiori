import 'package:dict_jmdict/dict_jmdict.dart';
import 'package:test/test.dart';

import 'support/mini_dictionary.dart';

void main() {
  late JmdictDictionary dict;
  setUp(() => dict = openMiniDictionary());
  tearDown(() => dict.close());

  test('kanji and kana forms in one call; unknown forms are left out', () {
    final found = dict.lookupForms(['勉強', 'テレビ', 'べんきょう', '無いもの']);

    expect(found.keys.toSet(), {'勉強', 'テレビ', 'べんきょう'});
    final benkyou = found['勉強']!.single;
    expect(benkyou.entryId, 1512670);
    expect(benkyou.readings, ['べんきょう']);
    expect(benkyou.partsOfSpeech, containsAll(['n', 'vs']));
    expect(benkyou.isKanaForm, isFalse);
    expect(benkyou.priority.isCommon, isTrue);

    final terebi = found['テレビ']!.single;
    expect(terebi.isKanaForm, isTrue);
    expect(terebi.kanjiForms, isEmpty);
    expect(found['べんきょう']!.single.kanjiForms, ['勉強']);
  });

  test('a kana form matches both scripts and keeps usually-kana marks', () {
    final gomi = dict.lookupForms(['ごみ'])['ごみ']!;

    final dust = gomi.firstWhere((e) => e.entryId == 1369900);
    expect(dust.usuallyKana, isTrue);
    expect(dust.kanjiForms, containsAll(['塵', '芥']));
  });

  test('a reading shared by many words returns each entry once', () {
    final ni = dict.lookupForms(['に'])['に']!;

    expect(ni.map((e) => e.entryId).toSet(), hasLength(ni.length));
    final particle = ni.firstWhere((e) => e.partsOfSpeech.contains('prt'));
    expect(particle.kanjiForms, isEmpty);
    expect(
      ni.firstWhere((e) => e.entryId == 1461140).kanjiForms,
      contains('二'),
    );
  });

  test('search-only spellings never match; irregular ones are marked', () {
    final found = dict.lookupForms(['御菓子', '遣り取り', 'お菓子']);

    expect(found.containsKey('御菓子'), isFalse);
    expect(found['遣り取り']!.single.irregular, isTrue);
    expect(found['お菓子']!.single.kanjiForms, ['お菓子']);
  });

  test('readings of a kanji form follow restrictions and JMdict order', () {
    final hi = dict.lookupForms(['日'])['日']!;

    expect(hi.map((e) => e.entryId), containsAll([1463770, 2083100]));
    expect(hi.firstWhere((e) => e.entryId == 1463770).readings, contains('ひ'));
  });

  test('no forms, no query', () {
    expect(dict.lookupForms(const []), isEmpty);
    expect(dict.lookupForms(['', '  ']), isEmpty);
  });
}
