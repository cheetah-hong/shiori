// X4: the example sentence file (tools/dict/build_examples.py) read by the
// block. Built from made-up sentences: tools/dict/testdata/tatoeba_sample/,
// joined to packages/dict_jmdict's JMdict test fixture.
import 'dart:io';

import 'package:example_block/example_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// `python3 tools/dict/build_examples.py --sample-sql`.
const _miniSql = 'test/fixtures/mini_examples.sql';

const _shichi = 1319210; // 七: しち, なな, …
const _shizuka = 1381820; // 静か
const _hon = 1522150; // 本
const _yogosu = 1178960; // 汚す
const _benkyou = 1512670; // 勉強

TatoebaExamples _open() => TatoebaExamples.fromDatabase(
  sqlite3.openInMemory()..execute(File(_miniSql).readAsStringSync()),
);

void main() {
  late TatoebaExamples ex;
  setUp(() => ex = _open());
  tearDown(() => ex.close());

  test('the file has the current schema and names its Tatoeba export', () {
    expect(ex.edition, '2026-11-07');
    expect(ex.builtOn, '2026-11-12');
    expect(ex.license, 'CC BY 2.0 FR');
  });

  test('one row per entry and reading', () async {
    final got = await ex.lookup([_shichi]);
    expect({for (final r in got) r.reading: r.ja}, {
      'しち': '七時に起きます。',
      'なな': '七回聞きました。',
    });
    expect({for (final r in got) r.entryId}, {_shichi});
  });

  test('Korean, else English, else no translation', () async {
    final shizuka = (await ex.lookup([_shizuka])).single;
    expect((shizuka.ja, shizuka.ko, shizuka.en), (
      '静かにしなさい。',
      '조용히 하세요.',
      null,
    ));
    final hon = (await ex.lookup([_hon])).single;
    expect((hon.ko, hon.en), (null, 'I read books every day.'));
    final yogosu = (await ex.lookup([_yogosu])).single;
    expect((yogosu.ko, yogosu.en), (null, null));
    expect(yogosu.surface, '汚して');
  });

  test('the sentence number and the reading of any row', () async {
    final row = (await ex.lookup([_benkyou])).single;
    expect(row.sentenceId, 107);
    expect(row.reading, '');
  });

  test('rows follow the order of the ids asked', () async {
    final got = await ex.lookup([_hon, _shizuka]);
    expect([for (final r in got) r.entryId], [_hon, _shizuka]);
    final back = await ex.lookup([_shizuka, _hon]);
    expect([for (final r in back) r.entryId], [_shizuka, _hon]);
  });

  test('no ids, unknown ids: nothing', () async {
    expect(await ex.lookup(const []), isEmpty);
    expect(await ex.lookup([1]), isEmpty);
  });

  test('many ids at once', () async {
    final ids = [for (var i = 1; i <= 2500; i++) i, _benkyou];
    final got = await ex.lookup(ids);
    expect([for (final r in got) r.entryId], [_benkyou]);
  });

  test('implements the core port', () {
    expect(ex, isA<ExampleSentences>());
  });

  test('another schema is refused', () {
    final db = sqlite3.openInMemory()
      ..execute(File(_miniSql).readAsStringSync())
      ..execute('PRAGMA user_version = 99');
    expect(
      () => TatoebaExamples.fromDatabase(db),
      throwsA(isA<ExampleFormatException>()),
    );
  });

  test('a file without the example table is refused', () {
    final db = sqlite3.openInMemory()
      ..execute('PRAGMA user_version = $exampleSchemaVersion')
      ..execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
    expect(
      () => TatoebaExamples.fromDatabase(db),
      throwsA(isA<ExampleFormatException>()),
    );
  });

  test('open() reads a file read-only and refuses a missing one', () {
    final dir = Directory.systemTemp.createTempSync('examples');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/examples.sqlite';
    sqlite3.open(path)
      ..execute(File(_miniSql).readAsStringSync())
      ..close();
    final opened = TatoebaExamples.open(path);
    expect(opened.edition, '2026-11-07');
    opened.close();
    expect(
      () => TatoebaExamples.open('${dir.path}/none.sqlite'),
      throwsA(anything),
    );
  });
}
