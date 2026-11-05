// K10: opening, refusing and closing the database.
import 'dart:io';

import 'package:krdict_block/krdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/mini.dart';

void main() {
  late Directory scratch;
  setUp(() => scratch = Directory.systemTemp.createTempSync('krdict_block_'));
  tearDown(() => scratch.deleteSync(recursive: true));

  File fileWith(String sql) {
    final file = File('${scratch.path}/g.sqlite');
    sqlite3.open(file.path)
      ..execute(sql)
      ..close();
    return file;
  }

  test('opens the file the build script writes', () async {
    final g = KrdictGlossary.open(
      fileWith(File(miniKrdictSql).readAsStringSync()).path,
    );
    addTearDown(g.close);
    expect(await heads(g, '食堂', readings: ['しょくどう']), ['식당']);
  });

  test('a missing file is refused', () {
    expect(
      () => KrdictGlossary.open('${scratch.path}/none.sqlite'),
      throwsA(anything),
    );
    expect(File('${scratch.path}/none.sqlite').existsSync(), isFalse);
  });

  test('another schema version is refused', () {
    final sql = File(
      miniKrdictSql,
    ).readAsStringSync().replaceAll('PRAGMA user_version = 1;', '');
    final file = fileWith('$sql\nPRAGMA user_version = 99;');
    expect(
      () => KrdictGlossary.open(file.path),
      throwsA(isA<KrdictFormatException>()),
    );
  });

  test('a database without the tables is refused', () {
    final file = fileWith(
      'CREATE TABLE other(x); PRAGMA user_version = $krdictSchemaVersion;',
    );
    expect(
      () => KrdictGlossary.open(file.path),
      throwsA(isA<KrdictFormatException>()),
    );
  });

  test('a file that is not SQLite is refused', () {
    final file = File('${scratch.path}/junk.sqlite')
      ..writeAsStringSync('not a database');
    expect(
      () => KrdictGlossary.open(file.path),
      throwsA(isA<KrdictFormatException>()),
    );
  });

  test('a lookup after close is an error; closing twice is not', () {
    final g = openMini()..close();
    expect(() => g.lookupSync('食堂'), throwsStateError);
    expect(g.close, returnsNormally);
  });

  test('the source and edition for the credit line', () {
    final g = openMini();
    addTearDown(g.close);
    final info = g.sources.single;
    expect(info.source, GlossarySource.krdict);
    expect(info.publisher, '국립국어원');
    expect(info.license, 'CC BY-SA 2.0 KR');
    expect(info.licenseUrl, startsWith('https://creativecommons.org/'));
    expect(info.edition, '2026-10-19');
    expect(
      info.attribution,
      '한국어기초사전, 국립국어원, CC BY-SA 2.0 KR, 2026-10-19판을 가공함',
    );
  });

  test('the empty block knows nothing', () async {
    const empty = EmptyKoreanGlossary();
    expect(await empty.lookup('食堂', readings: ['しょくどう']), isEmpty);
    expect(empty.sources, isEmpty);
  });
}
