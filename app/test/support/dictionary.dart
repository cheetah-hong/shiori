import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jmdict_block/jmdict_block.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:sqlite3/sqlite3.dart';

/// JMdict test fixture of the dict_jmdict package (JMdict data only).
const miniJmdictSql = '../packages/dict_jmdict/test/fixtures/mini_jmdict.sql';

const testEdition = DictionaryEdition(
  variant: 'full-lean',
  sourceSha256:
      '7f6dc7a4a50411e5a99c35969f28740e174714f04708ea84d50d6bdc09a001ed',
  jmdictCreated: '2026-11-04',
  builtOn: '2026-11-05',
);

/// The fixture as an in-memory dictionary block.
JmdictDictionaryAdapter openMiniJmdict() {
  final db = sqlite3.openInMemory()
    ..execute(File(miniJmdictSql).readAsStringSync());
  return JmdictDictionaryAdapter(JmdictDictionary.fromDatabase(db));
}

/// The fixture as SQLite file bytes, like the unpacked asset.
Uint8List miniJmdictFileBytes(Directory scratch) {
  final file = File('${scratch.path}/mini.sqlite');
  sqlite3.open(file.path)
    ..execute(File(miniJmdictSql).readAsStringSync())
    ..close();
  final bytes = file.readAsBytesSync();
  file.deleteSync();
  return bytes;
}

String editionJson({String sha = 'aa', String builtOn = '2026-11-05'}) =>
    '{"variant": "full-lean", "source_sha256": "$sha", '
    '"jmdict_created": "2026-11-04", "built_on": "$builtOn"}';

/// Assets held in memory; records every key that was loaded.
final class MemoryAssetBundle extends CachingAssetBundle {
  MemoryAssetBundle(this.files);

  final Map<String, List<int>> files;
  final List<String> loads = [];

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    final bytes = files[key];
    if (bytes == null) throw FlutterError('Unable to load asset: "$key".');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}
