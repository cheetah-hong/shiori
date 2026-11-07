import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dictionary.dart' show digestFields;

/// The Wiktionary fallback glossary fixture of krdict_block (made-up words,
/// tools/dict/build_wikt_glossary.py --sample-sql). It has 月道 (달길, 월로),
/// which the Basic Korean Dictionary fixture does not.
const miniWiktSql = '../packages/krdict_block/test/fixtures/mini_wikt.sql';

const testWiktEdition = GlossaryEdition(
  variant: 'lean',
  builtOn: '2026-11-07',
  sources: [
    GlossarySourceInfo(
      source: GlossarySource.wiktionary,
      publisher: '한국어 위키낱말사전 기여자',
      license: 'CC BY-SA 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      edition: '2026-11-01',
    ),
    GlossarySourceInfo(
      source: GlossarySource.wiktionary,
      publisher: '영어 위키낱말사전(Wiktionary) 기여자',
      license: 'CC BY-SA 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      edition: '2026-10-01',
    ),
  ],
);

KrdictGlossary openMiniWikt() => KrdictGlossary.fromDatabase(
  sqlite3.openInMemory()..execute(File(miniWiktSql).readAsStringSync()),
);

Uint8List miniWiktFileBytes(Directory scratch) {
  final file = File('${scratch.path}/mini-wikt.sqlite');
  sqlite3.open(file.path)
    ..execute(File(miniWiktSql).readAsStringSync())
    ..close();
  final bytes = file.readAsBytesSync();
  file.deleteSync();
  return bytes;
}

/// The edition file next to the fallback asset (build_wikt_glossary.py).
String wiktEditionJson({List<int> sqlite = const [], List<int>? gz}) =>
    '{"variant": "lean", "built_on": "2026-11-07", "schema": 2, '
    '"attribution": "위키낱말사전(한국어판·영어판) 기여자, CC BY-SA 4.0, '
    '2026-11-01·2026-10-01판을 가공함", '
    '"krdict_sqlite_sha256": "${'0' * 64}", '
    '"sources": ['
    '{"source": "wiktionary", "name": "한국어 위키낱말사전", '
    '"publisher": "한국어 위키낱말사전 기여자", "edition": "2026-11-01", '
    '"license": "CC BY-SA 4.0", '
    '"license_url": "https://creativecommons.org/licenses/by-sa/4.0/", '
    '"url": "https://ko.wiktionary.org", "source_sha256": "bb"}, '
    '{"source": "wiktionary", "name": "영어 위키낱말사전", '
    '"publisher": "영어 위키낱말사전(Wiktionary) 기여자", "edition": "2026-10-01", '
    '"license": "CC BY-SA 4.0", '
    '"license_url": "https://creativecommons.org/licenses/by-sa/4.0/", '
    '"url": "https://en.wiktionary.org", "source_sha256": "cc"}], '
    '${digestFields(sqlite, gz: gz)}}';
