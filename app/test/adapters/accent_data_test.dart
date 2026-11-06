import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/accent_data.dart';

import '../support/dictionary.dart' show MemoryAssetBundle;

const _tsv = '箸\tはし\t1\n橋\tはし\t2,1\n';

Map<String, List<int>> _assets({
  String tsv = _tsv,
  Map<String, Object?>? edit,
}) {
  final raw = utf8.encode(tsv);
  final gz = gzip.encode(raw);
  final edition = <String, Object?>{
    'variant': 'kanjium-accents',
    'built_on': '2026-11-06',
    'gzip_bytes': gz.length,
    'tsv_bytes': raw.length,
    'tsv_sha256': sha256.convert(raw).toString(),
    'entries': 2,
    'source_url': 'https://example.invalid/accents.txt',
    'source_sha256': '0' * 64,
    'license': 'CC BY-SA 4.0',
    'attribution': 'credit line',
    ...?edit,
  };
  return {
    accentTableAsset: gz,
    accentEditionAsset: utf8.encode(jsonEncode(edition)),
  };
}

void main() {
  final logs = <String>[];
  setUp(logs.clear);

  test('opens the checked table', () async {
    final data = await openAccentData(
      bundle: MemoryAssetBundle(_assets()),
      log: logs.add,
    );
    expect(data.table.lookup('橋', 'はし'), [2, 1]);
    expect(data.edition?.license, 'CC BY-SA 4.0');
    expect(data.edition?.attribution, 'credit line');
  });

  test('a build without the accent data has an empty table', () async {
    final data = await openAccentData(
      bundle: MemoryAssetBundle({}),
      log: logs.add,
    );
    expect(data.table.length, 0);
    expect(data.edition, isNull);
  });

  test('a table that does not match its sha256 is not used', () async {
    // Same length, other content, and the gzip size the edition gives: only
    // the sha256 can tell.
    final assets = _assets();
    final gz = gzip.encode(utf8.encode('箸\tはし\t2\n橋\tはし\t2,1\n'));
    final edition =
        jsonDecode(utf8.decode(assets[accentEditionAsset]!))
            as Map<String, Object?>;
    edition['gzip_bytes'] = gz.length;
    assets[accentTableAsset] = gz;
    assets[accentEditionAsset] = utf8.encode(jsonEncode(edition));
    final data = await openAccentData(
      bundle: MemoryAssetBundle(assets),
      log: logs.add,
    );
    expect(data.table.length, 0);
    expect(logs.join('\n'), contains('sha256'));
  });

  test('a gzip of another size than the edition says is not used', () async {
    final data = await openAccentData(
      bundle: MemoryAssetBundle(_assets(edit: {'gzip_bytes': 3})),
      log: logs.add,
    );
    expect(data.table.length, 0);
  });
}
