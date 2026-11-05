// Added after the freeze (freeze.md, addendum): the headword's ending in the
// ranking, and the honorific お / ご retry. Rows are added to the made-up
// fixture in memory, so the frozen sample stays as it is.
import 'dart:io';

import 'package:krdict_block/krdict_block.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/mini.dart';

void main() {
  late KrdictGlossary g;
  setUp(() {
    final db = sqlite3.openInMemory()
      ..execute(File(miniKrdictSql).readAsStringSync())
      ..execute('''
INSERT INTO sense VALUES (901, '유명', 1, 1, 0, '');
INSERT INTO ja VALUES ('有名', 'ゆうめい', 0, 0, '', 901);
INSERT INTO sense VALUES (902, '화장실', 1, 1, 0, '');
INSERT INTO ja VALUES ('お手洗い', 'おてあらい', 0, 0, '', 902);
INSERT INTO sense VALUES (903, '손 씻기', 1, 1, 0, '');
INSERT INTO ja VALUES ('手洗い', 'てあらい', 0, 0, '', 903);
''');
    g = KrdictGlossary.fromDatabase(db);
  });
  tearDown(() => g.close());

  group('the ending the headword was printed with', () {
    test('有名だ: the equivalent written with だ first', () async {
      expect(await heads(g, '有名だ', readings: ['ゆうめいだ']), ['유명하다', '유명']);
    });

    test('有名: the equivalent written without だ first', () async {
      expect(await heads(g, '有名', readings: ['ゆうめい']), ['유명', '유명하다']);
    });

    test('the place in the list still comes first', () async {
      // 카페 has 喫茶店 second; no ending on either side changes that.
      expect(await heads(g, '喫茶店', readings: ['きっさてん']), ['찻집', '카페']);
    });
  });

  group('an honorific お or ご the dictionary does not have', () {
    test('お皿 is looked up as 皿', () async {
      expect(await heads(g, 'お皿', readings: ['おさら']), ['그릇', '접시']);
      expect(await heads(g, 'お皿'), ['그릇', '접시']);
    });

    test('a word the dictionary has with お keeps it', () async {
      expect(await heads(g, 'お手洗い', readings: ['おてあらい']), ['화장실']);
    });

    test('a kana word is not cut', () async {
      expect(await heads(g, 'おさら'), isEmpty);
    });

    test('nothing without the prefix either: nothing', () async {
      expect(await heads(g, 'お茶', readings: ['おちゃ']), isEmpty);
    });
  });
}
