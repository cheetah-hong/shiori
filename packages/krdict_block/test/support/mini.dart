import 'dart:io';

import 'package:krdict_block/krdict_block.dart';
import 'package:sqlite3/sqlite3.dart';

/// Built from tools/dict/testdata/krdict_sample.json (made-up entries shaped
/// like the Basic Korean Dictionary download) by
/// `python3 tools/dict/build_ko_glossary.py --sample-sql`.
const miniKrdictSql = 'test/fixtures/mini_krdict.sql';

/// The index key table shared with tools/dict/test_build_ko_glossary.py.
const keyTable = '../../tools/dict/testdata/ko_glossary_keys.json';

KrdictGlossary openMini() => KrdictGlossary.fromDatabase(
  sqlite3.openInMemory()..execute(File(miniKrdictSql).readAsStringSync()),
);

/// The first word of each meaning, best first.
Future<List<String>> heads(
  KrdictGlossary g,
  String headword, {
  List<String> readings = const [],
  int limit = 10,
}) async => [
  for (final s in await g.lookup(headword, readings: readings, limit: limit))
    s.words.first,
];
