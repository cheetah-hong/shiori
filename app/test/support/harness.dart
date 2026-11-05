import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori_core/shiori_core.dart';

/// Thursday 5 November 2026, 21:00.
final testNow = DateTime(2026, 11, 5, 21);

/// Reads the synthetic sample pages straight from `assets/dev_samples/`
/// (synchronous I/O, so it completes inside the widget-test fake clock).
final fixtureFileRecognizer = FixtureTextRecognizer(
  (name) => SynchronousFuture(File('$devSampleDir/$name').readAsStringSync()),
);

/// Fresh in-memory blocks per test, a fixed clock and file-backed samples.
final class TestBlocks {
  TestBlocks({LibraryRepository? library})
    : library = library ?? InMemoryLibraryRepository();

  final LibraryRepository library;
  final reviews = InMemoryReviewRepository();
  FixedClock clock = FixedClock(testNow);

  /// Block behind "샘플 페이지로 해 보기"; tests may swap it before pumping.
  TextRecognizer sampleRecognizer = fixtureFileRecognizer;

  /// Sample pages on (as in the dev flavor), whatever `--flavor` the tests run with.
  bool devSamples = true;

  /// No dictionary data unless a test plugs one in before pumping.
  BundledDictionary dictionary = const BundledDictionary.unavailable(
    'no dictionary in tests',
  );

  /// No Korean glossary unless a test plugs one in before pumping.
  BundledGlossary glossary = const BundledGlossary.unavailable(
    'no glossary in tests',
  );

  List<Override> get overrides => [
    clockProvider.overrideWith((ref) => clock),
    libraryRepositoryProvider.overrideWithValue(library),
    reviewRepositoryProvider.overrideWithValue(reviews),
    devSamplesEnabledProvider.overrideWithValue(devSamples),
    sampleRecognizerProvider.overrideWithValue(sampleRecognizer),
    bundledDictionaryProvider.overrideWith((ref) async => dictionary),
    bundledGlossaryProvider.overrideWith((ref) async => glossary),
  ];

  /// Saves the words of a sample page as if it had been captured and reviewed.
  Future<Textbook> seedPage(String fixture, {String title = 'JLPT 단어장'}) async {
    final service = LibraryService(library: library, clock: clock);
    final existing = await library.textbooks();
    final textbook = existing.isNotEmpty
        ? existing.first
        : await service.createTextbook(title);
    final draft = await CapturePipeline.standard().fromScan(
      await fixtureFileRecognizer.recognize(PageImage(fixture)),
    );
    await service.saveDraft(draft, textbookId: textbook.id);
    return textbook;
  }
}

/// Providers do not retry in tests, so a failure shows at once.
Duration? _noRetry(int retryCount, Object error) => null;

Widget app(TestBlocks blocks, {List<Override> extra = const []}) =>
    ProviderScope(
      retry: _noRetry,
      overrides: [...blocks.overrides, ...extra],
      child: const ShioriApp(),
    );

Widget screen(TestBlocks blocks, Widget child) => ProviderScope(
  retry: _noRetry,
  overrides: blocks.overrides,
  child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
);

/// iPhone-sized surface (390 × 844 points) instead of the default 800 × 600.
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
