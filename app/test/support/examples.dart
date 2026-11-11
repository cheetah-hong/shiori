import 'dart:io';

import 'package:example_block/example_block.dart';
import 'package:flutter/foundation.dart';
import 'package:shiori/adapters/bundled_examples.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dictionary.dart' show digestFields;

/// The example sentence fixture of example_block (made-up sentences,
/// tools/dict/build_examples.py --sample-sql).
const miniExamplesSql =
    '../packages/example_block/test/fixtures/mini_examples.sql';

/// JMdict entries of the fixture: 静か (Korean), 本 (English), 汚す (none).
const shizukaEntry = 1381820;
const honEntry = 1522150;
const yogosuEntry = 1178960;

const testExamplesEdition = ExamplesEdition(
  builtOn: '2026-11-12',
  edition: '2026-11-07',
  license: 'CC BY 2.0 FR',
  licenseUrl: 'https://creativecommons.org/licenses/by/2.0/fr/',
  url: 'https://tatoeba.org',
  attribution:
      'Tatoeba (https://tatoeba.org) 문장, CC BY 2.0 FR, 2026-11-07 내보내기',
);

TatoebaExamples openMiniExamples() => TatoebaExamples.fromDatabase(
  sqlite3.openInMemory()..execute(File(miniExamplesSql).readAsStringSync()),
);

Uint8List miniExamplesFileBytes(Directory scratch) {
  final file = File('${scratch.path}/mini-examples.sqlite');
  sqlite3.open(file.path)
    ..execute(File(miniExamplesSql).readAsStringSync())
    ..close();
  final bytes = file.readAsBytesSync();
  file.deleteSync();
  return bytes;
}

/// The edition file next to the example asset (build_examples.py).
String examplesEditionJson({List<int> sqlite = const [], List<int>? gz}) =>
    '{"variant": "one-per-reading", "built_on": "2026-11-12", "schema": 1, '
    '"attribution": "Tatoeba (https://tatoeba.org) 문장, CC BY 2.0 FR, '
    '2026-11-07 내보내기", '
    '"sources": [{"source": "tatoeba", "name": "Tatoeba", '
    '"publisher": "Tatoeba 기여자", "edition": "2026-11-07", '
    '"license": "CC BY 2.0 FR", '
    '"license_url": "https://creativecommons.org/licenses/by/2.0/fr/", '
    '"url": "https://tatoeba.org", "source_sha256": "aa"}], '
    '"files": {}, "examples": 13, "korean": 2, "english": 5, "untranslated": 6, '
    '${digestFields(sqlite, gz: gz)}}';
