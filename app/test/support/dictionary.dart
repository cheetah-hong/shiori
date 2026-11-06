import 'dart:io';

import 'package:crypto/crypto.dart';
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

/// The fixture as an in-memory dictionary.
JmdictDictionary openMiniJmdict() {
  final db = sqlite3.openInMemory()
    ..execute(File(miniJmdictSql).readAsStringSync());
  return JmdictDictionary.fromDatabase(db);
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

/// The edition file next to the asset (tools/dict/build_app_asset.py). Its
/// sizes and sha256 describe [sqlite] packed as [gz] (default: [sqlite]
/// gzipped), as the build script writes them.
String editionJson({
  String sha = 'aa',
  String builtOn = '2026-11-05',
  List<int> sqlite = const [],
  List<int>? gz,
}) =>
    '{"variant": "full-lean", "source_sha256": "$sha", '
    '"jmdict_created": "2026-11-04", "built_on": "$builtOn", '
    '${digestFields(sqlite, gz: gz)}}';

/// `gzip_bytes`, `sqlite_bytes` and `sqlite_sha256` of [sqlite] packed as
/// [gz] (default: [sqlite] gzipped), as JSON members.
String digestFields(List<int> sqlite, {List<int>? gz}) =>
    '"gzip_bytes": ${(gz ?? gzip.encode(sqlite)).length}, '
    '"sqlite_bytes": ${sqlite.length}, '
    '"sqlite_sha256": "${sha256.convert(sqlite)}"';

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
