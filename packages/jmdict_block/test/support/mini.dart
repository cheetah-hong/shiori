import 'dart:io';

import 'package:jmdict_block/jmdict_block.dart';
import 'package:sqlite3/sqlite3.dart';

/// dict_jmdict's test fixture: JMdict entries for the forms in
/// tools/dict/test_forms.txt, as SQL text.
const miniFixturePath = '../dict_jmdict/test/fixtures/mini_jmdict.sql';

/// The synthetic pages of the core package (tools/synthetic/make_pages.py).
const syntheticDir = '../core/test/fixtures/synthetic';

/// The adapter over the fixture loaded into an in-memory database.
JmdictDictionaryAdapter openMiniAdapter() {
  final db = sqlite3.openInMemory()
    ..execute(File(miniFixturePath).readAsStringSync());
  return JmdictDictionaryAdapter(JmdictDictionary.fromDatabase(db));
}
