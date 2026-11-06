import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/dictionary.dart';

void main() {
  late Directory support;
  late List<String> logs;

  setUp(() {
    support = Directory.systemTemp.createTempSync('shiori_dict_');
    logs = [];
  });
  tearDown(() => support.deleteSync(recursive: true));

  Future<BundledDictionary> open(MemoryAssetBundle bundle) =>
      openBundledDictionary(
        bundle: bundle,
        supportDirectory: () async => support,
        log: logs.add,
      );

  File unpacked() => File('${support.path}/$dictionaryFileName');
  File marker() => File('${support.path}/$dictionaryMarkerName');

  MemoryAssetBundle bundleWith(List<int> gz, String edition) =>
      MemoryAssetBundle({
        dictionaryAsset: gz,
        dictionaryEditionAsset: utf8.encode(edition),
      });

  test('no asset: no dictionary, a log line, and no exception', () async {
    final d = await open(MemoryAssetBundle({}));
    expect(d.isAvailable, isFalse);
    expect(d.problemKind, DictionaryProblem.missing);
    expect(d.lexicon, isA<EmptyLexicon>());
    expect(d.info, isNull);
    expect(d.problem, isNotNull);
    expect(logs, isNotEmpty);
    expect(unpacked().existsSync(), isFalse);
  });

  test('the first run unpacks the asset and opens it', () async {
    final db = miniJmdictFileBytes(support);
    final gz = gzip.encode(db);
    final d = await open(bundleWith(gz, editionJson(sha: 'v1', sqlite: db)));
    addTearDown(d.close);
    expect(d.isAvailable, isTrue);
    expect(d.problemKind, isNull);
    expect((await d.lexicon.lookup(['二'])).keys, ['二']);
    expect(d.edition?.sourceSha256, 'v1');
    expect(d.info?.attribution, contains('JMdict'));
    expect(unpacked().existsSync(), isTrue);
    expect(marker().readAsStringSync(), editionJson(sha: 'v1', sqlite: db));
  });

  test('the same edition is not unpacked again', () async {
    final db = miniJmdictFileBytes(support);
    final gz = gzip.encode(db);
    (await open(bundleWith(gz, editionJson(sha: 'v1', sqlite: db)))).close();
    final modified = unpacked().lastModifiedSync();

    // A broken archive proves the second run never reads it.
    final again = bundleWith(const [
      1,
      2,
      3,
    ], editionJson(sha: 'v1', sqlite: db, gz: gz));
    final d = await open(again);
    addTearDown(d.close);
    expect(d.isAvailable, isTrue);
    expect(again.loads, isNot(contains(dictionaryAsset)));
    expect(unpacked().lastModifiedSync(), modified);
  });

  test('a new edition is unpacked again', () async {
    final db = miniJmdictFileBytes(support);
    final gz = gzip.encode(db);
    (await open(bundleWith(gz, editionJson(sha: 'v1', sqlite: db)))).close();

    final newer = bundleWith(
      gz,
      editionJson(sha: 'v2', builtOn: '2026-12-01', sqlite: db),
    );
    final d = await open(newer);
    addTearDown(d.close);
    expect(d.isAvailable, isTrue);
    expect(newer.loads, contains(dictionaryAsset));
    expect(
      marker().readAsStringSync(),
      editionJson(sha: 'v2', builtOn: '2026-12-01', sqlite: db),
    );
    expect(d.edition?.builtOn, '2026-12-01');
  });

  test('a broken gzip: no dictionary, no half-written file', () async {
    const broken = [1, 2, 3];
    final d = await open(
      bundleWith(broken, editionJson(sqlite: const [4, 5], gz: broken)),
    );
    expect(d.isAvailable, isFalse);
    expect(d.problemKind, DictionaryProblem.damaged);
    expect(d.lexicon, isA<EmptyLexicon>());
    expect(logs, isNotEmpty);
    expect(marker().existsSync(), isFalse);
    expect(unpacked().existsSync(), isFalse);
  });

  test('an archive that is not a dictionary is not used', () async {
    final notDb = utf8.encode('not sqlite');
    final d = await open(
      bundleWith(gzip.encode(notDb), editionJson(sqlite: notDb)),
    );
    expect(d.isAvailable, isFalse);
    expect(unpacked().existsSync(), isFalse);
    expect(logs, isNotEmpty);
    expect(marker().existsSync(), isFalse);
  });

  test('an unreadable edition file is a damaged dictionary', () async {
    final gz = gzip.encode(miniJmdictFileBytes(support));
    for (final edition in ['not json', '{"variant": "full-lean"}']) {
      final d = await open(bundleWith(gz, edition));
      expect(d.isAvailable, isFalse, reason: edition);
      expect(d.problemKind, DictionaryProblem.damaged, reason: edition);
    }
    expect(logs, hasLength(2));
  });

  test('an edition without the sizes and sha256 is a damaged dictionary, '
      'and nothing is unpacked', () async {
    final gz = gzip.encode(miniJmdictFileBytes(support));
    final d = await open(
      bundleWith(
        gz,
        '{"variant": "full-lean", "source_sha256": "aa", '
        '"jmdict_created": "2026-11-04", "built_on": "2026-11-05"}',
      ),
    );
    expect(d.isAvailable, isFalse);
    expect(d.problemKind, DictionaryProblem.damaged);
    expect(unpacked().existsSync(), isFalse);
    expect(marker().existsSync(), isFalse);
  });

  test('an asset that differs from its edition (sha256): damaged, nothing '
      'kept, and the next run with a good asset opens', () async {
    final db = miniJmdictFileBytes(support);
    final gz = gzip.encode(db);
    final other = [...db]..[db.length - 1] ^= 1;
    final d = await open(bundleWith(gz, editionJson(sqlite: other, gz: gz)));
    expect(d.isAvailable, isFalse);
    expect(d.problemKind, DictionaryProblem.damaged);
    expect(d.problem, contains('sqliteSha256'));
    expect(unpacked().existsSync(), isFalse);
    expect(marker().existsSync(), isFalse);

    final again = await open(bundleWith(gz, editionJson(sqlite: db)));
    addTearDown(again.close);
    expect(again.isAvailable, isTrue);
  });

  test('a damaged unpacked file is unpacked again', () async {
    final db = miniJmdictFileBytes(support);
    final gz = gzip.encode(db);
    (await open(bundleWith(gz, editionJson(sha: 'v1', sqlite: db)))).close();
    unpacked().writeAsStringSync('damaged');

    final d = await open(bundleWith(gz, editionJson(sha: 'v1', sqlite: db)));
    addTearDown(d.close);
    expect(d.isAvailable, isTrue);
    expect((await d.lexicon.lookup(['二'])).keys, ['二']);
  });

  test(
    'a support folder that cannot be found is a missing dictionary',
    () async {
      final db = miniJmdictFileBytes(support);
      final d = await openBundledDictionary(
        bundle: bundleWith(gzip.encode(db), editionJson(sqlite: db)),
        supportDirectory: () => Future.error(const FileSystemException('no')),
        log: logs.add,
      );
      expect(d.isAvailable, isFalse);
      expect(d.problemKind, DictionaryProblem.failed);
      expect(logs, isNotEmpty);
    },
  );
}
