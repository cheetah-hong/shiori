import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori_core/shiori_core.dart';

/// The core package tests the same synthetic pages (tools/synthetic/make_pages.py).
const _coreCopy = '../packages/core/test/fixtures/synthetic';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every sample page is bundled and matches the core test copy', () {
    for (final sample in devSamples) {
      for (final lang in ['ja', 'ko']) {
        final name = '${sample.id}.$lang.json';
        expect(
          File('$devSampleDir/$name').readAsStringSync(),
          File('$_coreCopy/$name').readAsStringSync(),
          reason: '$name: run python3 tools/synthetic/make_pages.py',
        );
      }
    }
  });

  test(
    'the sample recognizer reads every page from the asset bundle',
    () async {
      final recognizer = devSampleRecognizer(rootBundle);
      final pipeline = CapturePipeline.standard();
      for (final sample in devSamples) {
        final draft = await pipeline.fromScan(
          await recognizer.recognize(sample.image),
        );
        expect(draft.meta.page, sample.page, reason: sample.id);
        expect(
          draft.templateId,
          sample.layout.startsWith('목록') ? 'vocab.list' : 'vocab.entry',
          reason: sample.id,
        );
        expect(draft.entries, isNotEmpty, reason: sample.id);
      }
    },
  );

  test('a missing sample is a recognition error', () async {
    expect(
      devSampleRecognizer(rootBundle).recognize(const PageImage('s999')),
      throwsA(isA<TextRecognitionException>()),
    );
  });
}
