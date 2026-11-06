// The Korean glossary slot and the word extractor built on it.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/glossary.dart';

void main() {
  test('holds the glossary block once the bundled data is open', () async {
    final opened = BundledGlossary.opened(
      openMiniKrdict(),
      testGlossaryEdition,
    );
    addTearDown(opened.close);
    final c = ProviderContainer.test(
      overrides: [bundledGlossaryProvider.overrideWith((ref) async => opened)],
    );
    await c.read(bundledGlossaryProvider.future);
    expect(c.read(koreanGlossaryProvider), isA<KrdictGlossary>());
    expect(
      c.read(generalExtractorProvider).koreanGlossary,
      same(opened.krdict),
    );
  });

  test('stays empty without glossary data', () async {
    final c = ProviderContainer.test(
      overrides: [
        bundledGlossaryProvider.overrideWith(
          (ref) async => const BundledGlossary.unavailable('no asset'),
        ),
      ],
    );
    await c.read(bundledGlossaryProvider.future);
    expect(c.read(koreanGlossaryProvider), isA<EmptyKoreanGlossary>());
    expect(c.read(generalExtractorProvider).koreanGlossary, isNull);
  });
}
