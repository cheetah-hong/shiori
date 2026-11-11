// The v4 → v5 step writes the new version inside its own transaction: the
// tables and the version land together (a stop in between cannot leave a
// v5 file marked v4), and a failure takes both back.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

import 'generated/schema_v4.dart' as v4;

Future<int> _version(GeneratedDatabase db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('shiori_v4_version_');
    file = File('${dir.path}/shiori.sqlite');
    final old = v4.DatabaseAtV4(NativeDatabase(file));
    await old.customStatement(
      "INSERT INTO settings (key, value) VALUES ('study.scope_mode', 'x')",
    );
    expect(await _version(old), 4);
    await old.close();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('inside the step the file already says v5 and has the mode '
      'columns', () async {
    late ShioriDatabase db;
    int? seen;
    List<String>? columns;
    db = ShioriDatabase.file(
      file,
      onMigrate: () async {
        seen = await _version(db);
        columns = [
          for (final r
              in await db
                  .customSelect(
                    "SELECT name FROM pragma_table_info('review_cards')",
                  )
                  .get())
            r.read<String>('name'),
        ];
      },
    );
    addTearDown(db.close);
    expect(await _version(db), 5);
    expect(seen, 5);
    expect(columns, contains('mode'));
  });

  test('a failure takes the version back with the tables', () async {
    final failing = ShioriDatabase.file(
      file,
      onMigrate: () async => throw StateError('stop'),
    );
    await expectLater(
      failing.customSelect('SELECT 1').get(),
      throwsA(predicate((e) => '$e'.contains('stop'))),
    );
    await failing.close();

    final raw = v4.DatabaseAtV4(NativeDatabase(file));
    expect(await _version(raw), 4);
    final columns = [
      for (final r
          in await raw
              .customSelect(
                "SELECT name FROM pragma_table_info('review_cards')",
              )
              .get())
        r.read<String>('name'),
    ];
    expect(columns, isNot(contains('mode')));
    await raw.close();

    final again = ShioriDatabase.file(file);
    addTearDown(again.close);
    expect(await _version(again), 5);
  });
}
