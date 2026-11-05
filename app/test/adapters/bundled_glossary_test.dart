// K10 (app side): the Korean glossary asset is unpacked and opened, or the
// app runs with EmptyKoreanGlossary.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/dictionary.dart' show MemoryAssetBundle;
import '../support/glossary.dart';

void main() {
  late Directory support;
  late List<String> logs;

  setUp(() {
    support = Directory.systemTemp.createTempSync('shiori_ko_');
    logs = [];
  });
  tearDown(() => support.deleteSync(recursive: true));

  Future<BundledGlossary> open(MemoryAssetBundle bundle) => openBundledGlossary(
    bundle: bundle,
    supportDirectory: () async => support,
    log: logs.add,
  );

  File unpacked() => File('${support.path}/$glossaryFileName');

  MemoryAssetBundle bundleWith(List<int> gz, String edition) =>
      MemoryAssetBundle({
        glossaryAsset: gz,
        glossaryEditionAsset: utf8.encode(edition),
      });

  test('no asset: the empty glossary, a log line, and no exception', () async {
    final g = await open(MemoryAssetBundle({}));
    expect(g.isAvailable, isFalse);
    expect(g.glossary, isA<EmptyKoreanGlossary>());
    expect(await g.glossary.lookup('食堂', readings: ['しょくどう']), isEmpty);
    expect(g.edition, isNull);
    expect(g.problem, isNotNull);
    expect(logs, isNotEmpty);
    expect(unpacked().existsSync(), isFalse);
  });

  test('the first run unpacks the asset and opens it', () async {
    final gz = gzip.encode(miniKrdictFileBytes(support));
    final g = await open(bundleWith(gz, glossaryEditionJson(sha: 'v1')));
    addTearDown(g.close);
    expect(g.isAvailable, isTrue);
    expect(g.glossary, isA<KrdictGlossary>());
    final senses = await g.glossary.lookup('食堂', readings: ['しょくどう']);
    expect(senses.first.words, ['식당']);
    expect(g.edition?.sources.single.edition, '2026-10-19');
    expect(
      g.edition?.sources.single.attribution,
      '한국어기초사전, 국립국어원, CC BY-SA 2.0 KR, 2026-10-19판을 가공함',
    );
    expect(unpacked().existsSync(), isTrue);
  });

  test('the same edition is not unpacked again; a new one is', () async {
    final gz = gzip.encode(miniKrdictFileBytes(support));
    (await open(bundleWith(gz, glossaryEditionJson(sha: 'v1')))).close();

    final again = bundleWith(gz, glossaryEditionJson(sha: 'v1'));
    final g = await open(again);
    expect(g.isAvailable, isTrue);
    g.close();
    expect(again.loads, isNot(contains(glossaryAsset)));

    final newer = bundleWith(gz, glossaryEditionJson(sha: 'v2'));
    final h = await open(newer);
    addTearDown(h.close);
    expect(h.isAvailable, isTrue);
    expect(newer.loads, contains(glossaryAsset));
  });

  test('an asset that is not a glossary database is refused', () async {
    final notDb = gzip.encode(utf8.encode('not a database'));
    final g = await open(bundleWith(notDb, glossaryEditionJson()));
    expect(g.isAvailable, isFalse);
    expect(g.glossary, isA<EmptyKoreanGlossary>());
    expect(unpacked().existsSync(), isFalse);
    expect(logs, isNotEmpty);
  });

  test('an unreadable edition file is a missing glossary', () async {
    final gz = gzip.encode(miniKrdictFileBytes(support));
    for (final edition in [
      'not json',
      '{"variant": "lean"}',
      '{"variant": "lean", "built_on": "2026-11-05", "sources": '
          '[{"source": "other"}]}',
    ]) {
      final g = await open(bundleWith(gz, edition));
      expect(g.isAvailable, isFalse, reason: edition);
    }
    expect(logs, hasLength(3));
  });
}
