// The glossary read backwards (V8): the spellings a reading has, each with
// the Korean words of one sense, over the made-up sample.
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/mini.dart';

void main() {
  late KrdictGlossary g;
  setUp(() => g = openMini());
  tearDown(() => g.close());

  test('it reads backwards', () {
    expect(g, isA<KoreanReverseGlossary>());
  });

  test('さら gives 皿 with each of its senses', () async {
    final found = await g.reverseLookup(['さら']);
    expect(found, hasLength(2));
    expect(found.map((s) => s.written).toSet(), {'皿'});
    expect(found.map((s) => s.reading).toSet(), {'さら'});
    expect(found.map((s) => s.words.first).toSet(), {'접시', '그릇'});
  });

  test('synonyms come with the sense word', () async {
    final found = await g.reverseLookup(['ただ']);
    final only = found.where((s) => s.written == '只').toList();
    expect(only.map((s) => s.words.first).toSet(), {'공짜', '한갓'});
    // a kana word written in kana comes back under its kana
    expect(found.where((s) => s.written == 'ただ'), isNotEmpty);
    final plain = found.firstWhere((s) => s.words.first == '다만');
    expect(plain.words, ['다만', '단지']);
  });

  test('several readings in one call; a katakana reading matches', () async {
    final found = await g.reverseLookup(['さら', 'アジ']);
    expect(found.map((s) => s.written).toSet(), {'皿', '味'});
  });

  test('a reading the sample does not have gives nothing', () async {
    expect(await g.reverseLookup(['ぬえ']), isEmpty);
    expect(await g.reverseLookup(const []), isEmpty);
  });

  test('after close it throws', () async {
    final h = openMini()..close();
    expect(() => h.reverseLookup(['さら']), throwsStateError);
  });
}
