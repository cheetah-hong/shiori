import 'dart:convert';
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
  final preferences = InMemoryStudyPreferencesRepository();
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
    studyPreferencesRepositoryProvider.overrideWithValue(preferences),
    devSamplesEnabledProvider.overrideWithValue(devSamples),
    sampleRecognizerProvider.overrideWithValue(sampleRecognizer),
    bundledDictionaryProvider.overrideWith((ref) async => dictionary),
    bundledGlossaryProvider.overrideWith((ref) async => glossary),
  ];

  /// Adds the printed words of a sample page's answer sheet to playlist
  /// [name] (made when missing), in the page's order, as if captured.
  Future<Playlist> seedPage(String fixture, {String name = 'JLPT 단어장'}) async {
    final service = LibraryService(library: library, clock: clock);
    final existing = [
      for (final p in await library.playlists())
        if (p.name == name) p,
    ];
    final answers =
        (jsonDecode(File(syntheticAnswers).readAsStringSync()) as Map)['pages']
            as List;
    final vocab =
        (answers.cast<Map<String, Object?>>().singleWhere(
                  (p) => p['fixture'] == fixture,
                )['vocab']!
                as List)
            .cast<Map<String, Object?>>();
    final result = await service.addDraft(
      CaptureDraft(
        entries: [
          for (final v in vocab)
            CapturedEntry(
              headword: v['headword']! as String,
              readings: [for (final r in v['readings']! as List) r as String],
              pos: null,
              meaning: v['meaning']! as String,
            ),
        ],
      ),
      to: existing.isEmpty
          ? NewPlaylist(name)
          : ExistingPlaylist(existing.single.id),
    );
    return result.playlist;
  }
}

/// The answer sheet of the synthetic word-book pages (core's copy).
const syntheticAnswers =
    '../packages/core/test/fixtures/synthetic/ground_truth.json';

/// Providers do not retry in tests, so a failure shows at once.
Duration? _noRetry(int retryCount, Object error) => null;

Widget app(TestBlocks blocks, {List<Override> extra = const []}) =>
    ProviderScope(
      retry: _noRetry,
      overrides: [...blocks.overrides, ...extra],
      child: const ShioriApp(),
    );

Widget screen(
  TestBlocks blocks,
  Widget child, {
  List<Override> extra = const [],
}) => ProviderScope(
  retry: _noRetry,
  overrides: [...blocks.overrides, ...extra],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
);

/// iPhone-sized surface (390 × 844 points) instead of the default 800 × 600.
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
