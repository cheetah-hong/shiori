import 'dart:io';

import 'package:dict_jmdict/dict_jmdict.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQL dump of 89 JMdict entries (tools/dict/test_forms.txt).
const miniFixturePath = 'test/fixtures/mini_jmdict.sql';

/// The fixture loaded into an in-memory database.
JmdictDictionary openMiniDictionary() {
  final db = sqlite3.openInMemory()
    ..execute(File(miniFixturePath).readAsStringSync());
  return JmdictDictionary.fromDatabase(db);
}

/// Headwords of [candidates], in order.
List<String> headwords(Iterable<HeadwordCandidate> candidates) => [
  for (final c in candidates) c.headword,
];
