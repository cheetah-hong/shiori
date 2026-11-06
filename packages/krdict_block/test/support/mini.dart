import 'dart:io';

import 'package:krdict_block/krdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:sqlite3/sqlite3.dart';

/// Built from tools/dict/testdata/krdict_sample.json (made-up entries shaped
/// like the Basic Korean Dictionary download) by
/// `python3 tools/dict/build_ko_glossary.py --sample-sql`.
const miniKrdictSql = 'test/fixtures/mini_krdict.sql';

/// The same sample built with schema 1 (before `sense.pos`), as at main
/// f19991a: an app with an old asset reads files like it.
const miniKrdictV1Sql = 'test/fixtures/mini_krdict_v1.sql';

/// The index key table shared with tools/dict/test_build_ko_glossary.py.
const keyTable = '../../tools/dict/testdata/ko_glossary_keys.json';

/// The Korean part-of-speech codes shared with build_ko_glossary.py.
const posTable = '../../tools/dict/testdata/ko_pos_codes.json';

KrdictGlossary openMini() => KrdictGlossary.fromDatabase(
  sqlite3.openInMemory()..execute(File(miniKrdictSql).readAsStringSync()),
);

KrdictGlossary openMiniV1() => KrdictGlossary.fromDatabase(
  sqlite3.openInMemory()..execute(File(miniKrdictV1Sql).readAsStringSync()),
);

/// The first word of each meaning, best first.
Future<List<String>> heads(
  KrdictGlossary g,
  String headword, {
  List<String> readings = const [],
  int limit = 10,
  PartOfSpeech? pos,
}) async => [
  for (final s in await g.lookup(
    headword,
    readings: readings,
    limit: limit,
    pos: pos,
  ))
    s.words.first,
];
