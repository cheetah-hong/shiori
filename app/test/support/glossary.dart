import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dictionary.dart' show digestFields;

/// Korean glossary test fixture of the krdict_block package (made-up entries
/// shaped like the Basic Korean Dictionary).
const miniKrdictSql = '../packages/krdict_block/test/fixtures/mini_krdict.sql';

const testGlossaryEdition = GlossaryEdition(
  variant: 'lean',
  builtOn: '2026-11-05',
  sources: [
    GlossarySourceInfo(
      source: GlossarySource.krdict,
      publisher: '국립국어원',
      license: 'CC BY-SA 2.0 KR',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/2.0/kr/',
      edition: '2026-10-19',
    ),
  ],
);

/// The fixture as an in-memory glossary block.
KrdictGlossary openMiniKrdict() => KrdictGlossary.fromDatabase(
  sqlite3.openInMemory()..execute(File(miniKrdictSql).readAsStringSync()),
);

/// The fixture as SQLite file bytes, like the unpacked asset.
Uint8List miniKrdictFileBytes(Directory scratch) {
  final file = File('${scratch.path}/mini-ko.sqlite');
  sqlite3.open(file.path)
    ..execute(File(miniKrdictSql).readAsStringSync())
    ..close();
  final bytes = file.readAsBytesSync();
  file.deleteSync();
  return bytes;
}

/// The edition file next to the asset (tools/dict/build_ko_glossary.py).
/// Its sizes and sha256 describe [sqlite] packed as [gz] (default: [sqlite]
/// gzipped).
String glossaryEditionJson({
  String sha = 'aa',
  String edition = '2026-10-19',
  List<int> sqlite = const [],
  List<int>? gz,
}) =>
    '{"variant": "lean", "built_on": "2026-11-05", '
    '"attribution": "한국어기초사전, 국립국어원, CC BY-SA 2.0 KR, $edition판을 가공함", '
    '"sources": [{"source": "krdict", "name": "한국어기초사전", '
    '"publisher": "국립국어원", "edition": "$edition", '
    '"license": "CC BY-SA 2.0 KR", '
    '"license_url": "https://creativecommons.org/licenses/by-sa/2.0/kr/", '
    '"source_sha256": "$sha"}], ${digestFields(sqlite, gz: gz)}}';
