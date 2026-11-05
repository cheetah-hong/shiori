import 'dart:io';

import 'package:dict_jmdict/dict_jmdict.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/mini_dictionary.dart';

void main() {
  test('info carries source, date and the licence notice', () {
    final dict = openMiniDictionary();
    addTearDown(dict.close);

    expect(dict.info.schemaVersion, jmdictSchemaVersion);
    expect(dict.info.jmdictCreated, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(dict.info.sourceSha256, hasLength(64));
    expect(dict.info.entryCount, greaterThan(50));
    expect(dict.info.license, 'CC BY-SA 4.0');
    expect(dict.info.attribution, contains('Electronic Dictionary Research'));
    expect(dict.info.attribution, contains(dict.info.licenseUrl));
    expect(dict.info.projectUrl, startsWith('https://www.edrdg.org/'));
    expect(dict.info.entries, 'all');
    expect(dict.info.glosses, 'first');
  });

  test('opens a database file read-only', () {
    final dir = Directory.systemTemp.createTempSync('dict_jmdict_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/mini.sqlite';
    sqlite3.open(path)
      ..execute(File(miniFixturePath).readAsStringSync())
      ..close();

    final dict = JmdictDictionary.open(path);
    addTearDown(dict.close);

    expect(dict.hasPair('二', 'に'), isTrue);
  });

  test('rejects databases with another schema', () {
    final empty = sqlite3.openInMemory();
    addTearDown(empty.close);
    final wrongVersion = sqlite3.openInMemory()
      ..execute(
        'CREATE TABLE meta (key TEXT, value TEXT); PRAGMA user_version = 7;',
      );
    addTearDown(wrongVersion.close);

    expect(
      () => JmdictDictionary.fromDatabase(empty),
      throwsA(isA<JmdictFormatException>()),
    );
    expect(
      () => JmdictDictionary.fromDatabase(wrongVersion),
      throwsA(
        isA<JmdictFormatException>().having(
          (e) => e.toString(),
          'message',
          contains('schema 7'),
        ),
      ),
    );
  });

  test('open closes the file again when the schema is wrong', () {
    final dir = Directory.systemTemp.createTempSync('dict_jmdict_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/other.sqlite';
    sqlite3.open(path)
      ..execute('CREATE TABLE t (x)')
      ..close();

    expect(
      () => JmdictDictionary.open(path),
      throwsA(isA<JmdictFormatException>()),
    );
  });

  test('a closed dictionary refuses lookups; closing twice is fine', () {
    final dict = openMiniDictionary()..close();

    expect(() => dict.hasPair('二', 'に'), throwsStateError);
    // Calls that would return early on their input still refuse.
    expect(() => dict.lookupByReading(''), throwsStateError);
    expect(() => dict.lookupByHeadword(''), throwsStateError);
    expect(() => dict.checkPair('', 'に'), throwsStateError);
    expect(() => dict.suggestHeadword('', ''), throwsStateError);
    dict.close();
  });
}
