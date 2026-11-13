// M1 (app side): the meaning overrides file (시오리 보정) is read next to the
// Basic Korean Dictionary and put over it, so the word extractor, the word
// sheet and the built-in decks all get its meanings; without it (a debug
// build) or with a damaged one the app runs with the dictionary as it is and
// logs one line.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/dictionary.dart' show MemoryAssetBundle;
import '../support/glossary.dart';

/// 鼻 read はな: the test dictionary says 코; the table says 코끝 (made up).
const _overridesJson =
    '{"format":"shiori-meaning-overrides","version":1,"edition":"2026-11-14",'
    '"rows":[\n{"f":["鼻"],"r":"はな","m":"코끝"}\n]}\n';

String _editionJson(List<int> json) =>
    '{"attribution": "뜻 보정: 시오리", "built_on": "2026-11-14", '
    '"format": "shiori-meaning-overrides", "jmdict_created": "2026-11-04", '
    '"json_bytes": ${json.length}, "json_sha256": "${sha256.convert(json)}", '
    '"license": "CC BY-SA 4.0", "rows": 1, "skipped": 0, '
    '"table_sha256": "aa", "version": 1}';

void main() {
  late Directory support;
  late List<String> logs;

  setUp(() {
    support = Directory.systemTemp.createTempSync('shiori_overrides_');
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

  Map<String, List<int>> overridesAssets({bool damaged = false}) {
    final json = utf8.encode(_overridesJson);
    return {
      meaningOverridesAsset: damaged
          ? utf8.encode(_overridesJson.replaceAll('코끝', '콧등'))
          : json,
      meaningOverridesEditionAsset: utf8.encode(_editionJson(json)),
    };
  }

  test('the asset names', () {
    expect(meaningOverridesAsset, 'assets/dict/meaning-overrides.json');
    expect(
      meaningOverridesEditionAsset,
      'assets/dict/meaning-overrides.edition.json',
    );
  });

  test('with the file: the glossary answers its meanings first, as 시오리 '
      '보정, and still reads backwards', () async {
    final g = await open(
      MemoryAssetBundle({...krdictAssets(), ...overridesAssets()}),
    );
    addTearDown(g.close);

    expect(g.isAvailable, isTrue);
    expect(g.overrides?.length, 1);
    expect(g.overrides?.edition, '2026-11-14');
    expect(g.overridesProblem, isNull);
    final senses = await g.glossary.lookup('鼻', readings: ['はな']);
    expect(senses.first.text, '코끝');
    expect(senses.first.source, GlossarySource.shiori);
    expect([for (final s in senses) s.text], contains('코'));
    expect(g.glossary, isA<KoreanReverseGlossary>());
  });

  test('without the file: the dictionary as it is, one log line', () async {
    final g = await open(MemoryAssetBundle(krdictAssets()));
    addTearDown(g.close);

    expect(g.isAvailable, isTrue);
    expect(g.overrides, isNull);
    expect(g.overridesProblem, isNotNull);
    expect(g.glossary, same(g.krdict));
    expect(logs.where((l) => l.contains('meaning overrides')), hasLength(1));
  });

  test(
    'a file that does not match its edition: the dictionary as it is',
    () async {
      final g = await open(
        MemoryAssetBundle({
          ...krdictAssets(),
          ...overridesAssets(damaged: true),
        }),
      );
      addTearDown(g.close);

      expect(g.overrides, isNull);
      expect(g.overridesProblem, isNotNull);
      expect((await g.glossary.lookup('鼻', readings: ['はな'])).first.text, '코');
    },
  );

  test('no dictionary: no glossary, whatever the file says', () async {
    final g = await open(MemoryAssetBundle(overridesAssets()));
    addTearDown(g.close);

    expect(g.isAvailable, isFalse);
    expect(g.glossary, isA<EmptyKoreanGlossary>());
  });

  test('the extractor and the word sheet get the table\'s meaning', () async {
    final krdict = openMiniKrdict();
    final bundled = BundledGlossary.opened(
      krdict,
      testGlossaryEdition,
      overrides: parseMeaningOverrides(_overridesJson),
    );
    addTearDown(bundled.close);
    final container = ProviderContainer(
      overrides: [bundledGlossaryProvider.overrideWith((ref) async => bundled)],
    );
    addTearDown(container.dispose);
    await container.read(bundledGlossaryProvider.future);

    final glossary = container.read(koreanGlossaryProvider);
    expect(glossary, isA<OverriddenKoreanGlossary>());
    final extractor = container.read(generalExtractorProvider);
    expect(
      (await extractor.koreanGlossary!.lookup(
        '鼻',
        readings: ['はな'],
      )).first.text,
      '코끝',
    );
    expect(krdict, isA<KrdictGlossary>());
  });
}
