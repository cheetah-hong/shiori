import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
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
    expect(d.lexicon, isA<EmptyLexicon>());
    expect(d.info, isNull);
    expect(d.problem, isNotNull);
    expect(logs, isNotEmpty);
    expect(unpacked().existsSync(), isFalse);
  });

  test('the first run unpacks the asset and opens it', () async {
    final gz = gzip.encode(miniJmdictFileBytes(support));
    final d = await open(bundleWith(gz, editionJson(sha: 'v1')));
    addTearDown(d.close);
    expect(d.isAvailable, isTrue);
    expect((await d.lexicon.lookup(['二'])).keys, ['二']);
    expect(d.edition?.sourceSha256, 'v1');
    expect(d.info?.attribution, contains('JMdict'));
    expect(unpacked().existsSync(), isTrue);
    expect(marker().readAsStringSync(), editionJson(sha: 'v1'));
  });

  test('the same edition is not unpacked again', () async {
    final gz = gzip.encode(miniJmdictFileBytes(support));
    (await open(bundleWith(gz, editionJson(sha: 'v1')))).close();
    final modified = unpacked().lastModifiedSync();

    // A broken archive proves the second run never reads it.
    final again = bundleWith(const [1, 2, 3], editionJson(sha: 'v1'));
    final d = await open(again);
    addTearDown(d.close);
    expect(d.isAvailable, isTrue);
    expect(again.loads, isNot(contains(dictionaryAsset)));
    expect(unpacked().lastModifiedSync(), modified);
  });

  test('a new edition is unpacked again', () async {
    final gz = gzip.encode(miniJmdictFileBytes(support));
    (await open(bundleWith(gz, editionJson(sha: 'v1')))).close();

    final newer = bundleWith(gz, editionJson(sha: 'v2', builtOn: '2026-12-01'));
    final d = await open(newer);
    addTearDown(d.close);
    expect(d.isAvailable, isTrue);
    expect(newer.loads, contains(dictionaryAsset));
    expect(
      marker().readAsStringSync(),
      editionJson(sha: 'v2', builtOn: '2026-12-01'),
    );
    expect(d.edition?.builtOn, '2026-12-01');
  });

  test('a broken gzip: no dictionary, no half-written file', () async {
    final d = await open(bundleWith(const [1, 2, 3], editionJson()));
    expect(d.isAvailable, isFalse);
    expect(d.lexicon, isA<EmptyLexicon>());
    expect(logs, isNotEmpty);
    expect(marker().existsSync(), isFalse);
    expect(unpacked().existsSync(), isFalse);
  });

  test('an archive that is not a dictionary is not used', () async {
    final d = await open(
      bundleWith(gzip.encode(utf8.encode('not sqlite')), editionJson()),
    );
    expect(d.isAvailable, isFalse);
    expect(logs, isNotEmpty);
    expect(marker().existsSync(), isFalse);
  });

  test('an unreadable edition file is a missing dictionary', () async {
    final gz = gzip.encode(miniJmdictFileBytes(support));
    for (final edition in ['not json', '{"variant": "full-lean"}']) {
      final d = await open(bundleWith(gz, edition));
      expect(d.isAvailable, isFalse, reason: edition);
    }
    expect(logs, hasLength(2));
  });

  test('a damaged unpacked file is unpacked again', () async {
    final gz = gzip.encode(miniJmdictFileBytes(support));
    (await open(bundleWith(gz, editionJson(sha: 'v1')))).close();
    unpacked().writeAsStringSync('damaged');

    final d = await open(bundleWith(gz, editionJson(sha: 'v1')));
    addTearDown(d.close);
    expect(d.isAvailable, isTrue);
    expect((await d.lexicon.lookup(['二'])).keys, ['二']);
  });

  test(
    'a support folder that cannot be found is a missing dictionary',
    () async {
      final gz = gzip.encode(miniJmdictFileBytes(support));
      final d = await openBundledDictionary(
        bundle: bundleWith(gz, editionJson()),
        supportDirectory: () => Future.error(const FileSystemException('no')),
        log: logs.add,
      );
      expect(d.isAvailable, isFalse);
      expect(logs, isNotEmpty);
    },
  );
}
