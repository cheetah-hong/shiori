import 'package:test/test.dart';
import 'package:voicevox_block/voicevox_block.dart';

const _tsv =
    '箸\tはし\t1\n'
    '橋\tはし\t2,1\n'
    '端\tはし\t0\n'
    'パン\t\t1\n'
    'ふわり\t\t2,3\n';

void main() {
  final table = AccentTable.parse(_tsv);

  test('finds a (form, reading) pair', () {
    expect(table.lookup('箸', 'はし'), [1]);
    expect(table.lookup('端', 'はし'), [0]);
  });

  test('several values come in the data order, the main one first', () {
    expect(table.lookup('橋', 'はし'), [2, 1]);
  });

  test('a kana word is found by its form as the reading', () {
    expect(table.lookup('パン', 'パン'), [1]);
    expect(table.lookup('ふわり', 'ふわり'), [2, 3]);
  });

  test('a katakana reading of a kanji word is read as hiragana', () {
    expect(table.lookup('箸', 'ハシ'), [1]);
  });

  test('nothing for an unknown pair or another reading', () {
    expect(table.lookup('箸', 'ちょ'), isEmpty);
    expect(table.lookup('雲', 'くも'), isEmpty);
    expect(table.lookup('', ''), isEmpty);
  });

  test('counts entries and keeps the first line of a repeated pair', () {
    expect(table.length, 5);
    final twice = AccentTable.parse('箸\tはし\t1\n箸\tはし\t2\n');
    expect(twice.length, 1);
    expect(twice.lookup('箸', 'はし'), [1]);
  });

  test('a trailing newline and blank lines are fine', () {
    expect(AccentTable.parse('\n箸\tはし\t1\n\n').length, 1);
    expect(AccentTable.parse('').length, 0);
  });

  test('a malformed line is refused', () {
    for (final bad in ['箸\tはし\n', '箸\tはし\tいち\n', '箸\tはし\t\n', '\tはし\t1\n']) {
      expect(() => AccentTable.parse(bad), throwsFormatException, reason: bad);
    }
  });

  test('the empty table has nothing', () {
    expect(AccentTable.empty.length, 0);
    expect(AccentTable.empty.lookup('箸', 'はし'), isEmpty);
  });
}
