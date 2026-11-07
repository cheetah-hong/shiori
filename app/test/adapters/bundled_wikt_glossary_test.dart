// W5 (app side): the Wiktionary fallback glossary is unpacked and opened
// next to the Basic Korean Dictionary; without it (a debug build) the app
// runs with the Basic Korean Dictionary alone and logs one line.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/dictionary.dart' show MemoryAssetBundle;
import '../support/glossary.dart';
import '../support/wikt.dart';

void main() {
  late Directory support;
  late List<String> logs;

  setUp(() {
    support = Directory.systemTemp.createTempSync('shiori_wikt_');
    logs = [];
  });
  tearDown(() => support.deleteSync(recursive: true));

  Future<BundledGlossary> open(MemoryAssetBundle bundle) => openBundledGlossary(
    bundle: bundle,
    supportDirectory: () async => support,
    log: logs.add,
  );

  Map<String, List<int>> krdictAssets() {
    final db = miniKrdictFileBytes(support);
    return {
      glossaryAsset: gzip.encode(db),
      glossaryEditionAsset: utf8.encode(glossaryEditionJson(sqlite: db)),
    };
  }

  Map<String, List<int>> wiktAssets({bool damaged = false}) {
    final db = miniWiktFileBytes(support);
    final gz = gzip.encode(db);
    final shipped = damaged ? gz.sublist(0, gz.length ~/ 2) : gz;
    return {
      wiktGlossaryAsset: shipped,
      wiktGlossaryEditionAsset: utf8.encode(
        wiktEditionJson(sqlite: db, gz: shipped),
      ),
    };
  }

  test('the asset names', () {
    expect(wiktGlossaryAsset, 'assets/dict/wikt-glossary.sqlite.gz');
    expect(wiktGlossaryEditionAsset, 'assets/dict/wikt-glossary.edition.json');
    expect(wiktGlossaryFileName, isNot(glossaryFileName));
  });

  test('both assets: the glossary and its fallback open, the fallback from '
      'Wiktionary', () async {
    final g = await open(
      MemoryAssetBundle({...krdictAssets(), ...wiktAssets()}),
    );
    addTearDown(g.close);

    expect(g.isAvailable, isTrue);
    expect(g.wiktionary, isA<KrdictGlossary>());
    expect(g.wiktionaryProblem, isNull);
    expect(g.wiktionaryEdition?.sources, hasLength(2));
    expect(g.wiktionaryEdition?.sources.first.license, 'CC BY-SA 4.0');
    final senses = await g.wiktionary!.lookup('月道', readings: ['つきみち']);
    expect(senses.first.text, '달길, 월로');
    expect(senses.first.source, GlossarySource.wiktionary);
    // The pairing glossary is the Basic Korean Dictionary alone.
    expect(await g.glossary.lookup('月道', readings: ['つきみち']), isEmpty);
    expect(File('${support.path}/$wiktGlossaryFileName').existsSync(), isTrue);
  });

  test(
    'no fallback asset: the glossary alone, one log line, no exception',
    () async {
      final g = await open(MemoryAssetBundle(krdictAssets()));
      addTearDown(g.close);

      expect(g.isAvailable, isTrue);
      expect(g.wiktionary, isNull);
      expect(g.wiktionaryEdition, isNull);
      expect(g.wiktionaryProblem, isNotNull);
      expect(logs.where((l) => l.contains('wiktionary')), hasLength(1));
      expect((await g.glossary.lookup('鼻', readings: ['はな'])).first.words, [
        '코',
      ]);
    },
  );

  test('a damaged fallback: the glossary alone, nothing kept', () async {
    final g = await open(
      MemoryAssetBundle({...krdictAssets(), ...wiktAssets(damaged: true)}),
    );
    addTearDown(g.close);

    expect(g.isAvailable, isTrue);
    expect(g.wiktionary, isNull);
    expect(g.wiktionaryProblem, isNotNull);
    expect(File('${support.path}/$wiktGlossaryFileName').existsSync(), isFalse);
  });

  test('the word extractor gets the fallback for meanings', () async {
    final krdict = openMiniKrdict();
    final wikt = openMiniWikt();
    final bundled = BundledGlossary.opened(
      krdict,
      testGlossaryEdition,
      wiktionary: wikt,
      wiktionaryEdition: testWiktEdition,
    );
    addTearDown(bundled.close);
    final container = ProviderContainer(
      overrides: [bundledGlossaryProvider.overrideWith((ref) async => bundled)],
    );
    addTearDown(container.dispose);
    await container.read(bundledGlossaryProvider.future);

    final extractor = container.read(generalExtractorProvider);
    expect(extractor.koreanGlossary, same(krdict));
    expect(extractor.meaningFallback, same(wikt));
  });

  test('without the fallback the extractor has none', () async {
    final bundled = BundledGlossary.opened(
      openMiniKrdict(),
      testGlossaryEdition,
    );
    addTearDown(bundled.close);
    final container = ProviderContainer(
      overrides: [bundledGlossaryProvider.overrideWith((ref) async => bundled)],
    );
    addTearDown(container.dispose);
    await container.read(bundledGlossaryProvider.future);

    expect(container.read(generalExtractorProvider).meaningFallback, isNull);
  });
}
