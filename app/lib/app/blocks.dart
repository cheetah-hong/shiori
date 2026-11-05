/// The block map: every slot a feature block plugs into, in one file.
///
/// Swapping a block is one provider override, for example in `main.dart`:
///
/// ```dart
/// ProviderScope(
///   overrides: [textRecognizerProvider.overrideWithValue(CloudVisionRecognizer())],
///   child: const ShioriApp(),
/// )
/// ```
///
/// Ports live in `package:shiori_core`; adapters in `lib/adapters/` or in core.
/// See docs/architecture.md for the full map and the next blocks.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/adapters/image_picker_source.dart';
import 'package:shiori/adapters/platform_text_recognizer.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

// ---------------------------------------------------------------- block slots

/// Time. Tests override it with `FixedClock`.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Device OCR: Apple Vision (iOS) / ML Kit (Android). Next: Cloud Vision, Claude.
final textRecognizerProvider = Provider<TextRecognizer>(
  (ref) => const PlatformTextRecognizer(),
);

/// "샘플 페이지로 해 보기": recorded OCR from assets (development builds only).
final sampleRecognizerProvider = Provider<TextRecognizer>(
  (ref) => devSampleRecognizer(rootBundle),
);

/// Page photos: image_picker. Next: document scanner, page flattening.
final imageSourceProvider = Provider<ImageSource>((ref) => ImagePickerSource());

/// Textbook layouts, auto-detected per page. Next: other textbooks.
final templateRegistryProvider = Provider<TemplateRegistry>(
  (ref) => TemplateRegistry(const [ListPageTemplate(), EntryPageTemplate()]),
);

/// JMdict unpacked from the app's assets. `main.dart` starts opening it before
/// the first frame without waiting for it.
/// Never fails: without the asset it holds `BundledDictionary.unavailable`.
final bundledDictionaryProvider = FutureProvider<BundledDictionary>((
  ref,
) async {
  final dictionary = await openAppDictionary();
  ref.onDispose(dictionary.close);
  return dictionary;
});

/// Dictionary for headword candidates and pair checks: JMdict once it is
/// open, `EmptyDictionary` until then or without dictionary data.
final dictionaryProvider = Provider<Dictionary>(
  (ref) =>
      ref.watch(bundledDictionaryProvider).value?.dictionary ??
      const EmptyDictionary(),
);

/// Corrector chain, in order (`standardCorrectors` in core).
final entryCorrectorsProvider = Provider<List<EntryCorrector>>(
  (ref) => standardCorrectors(ref.watch(dictionaryProvider)),
);

/// The SQLite file behind both storage blocks. `main.dart` opens it (the app
/// support folder is only known asynchronously) and overrides this provider.
/// Tests override the repositories, or this with `ShioriDatabase.memory()`.
final appDatabaseProvider = Provider<ShioriDatabase>(
  (ref) => throw StateError(
    'appDatabaseProvider is not set: open the database in main.dart',
  ),
);

/// Content storage: SQLite (drift). Tests: `InMemoryLibraryRepository`.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => DriftLibraryRepository(ref.watch(appDatabaseProvider)),
);

/// Learning state storage: SQLite (drift). Tests: `InMemoryReviewRepository`.
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => DriftReviewRepository(ref.watch(appDatabaseProvider)),
);

/// Intervals, day start hour, session size.
final studySettingsProvider = Provider<StudySettings>(
  (ref) => const StudySettings(),
);

/// Review timing: four Leitner steps. Next: FSRS.
final reviewSchedulerProvider = Provider<ReviewScheduler>(
  (ref) => LeitnerFourStepScheduler.checked(
    ref.watch(studySettingsProvider).intervals,
  ),
);

/// Pronunciation (optional). Next: flutter_tts.
final speechProvider = Provider<Speech>((ref) => const SilentSpeech());

// ---------------------------------------------------------------- composed from the blocks above

final capturePipelineProvider = Provider<CapturePipeline>(
  (ref) => CapturePipeline(
    templates: ref.watch(templateRegistryProvider),
    correctors: ref.watch(entryCorrectorsProvider),
  ),
);

final libraryServiceProvider = Provider<LibraryService>(
  (ref) => LibraryService(
    library: ref.watch(libraryRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final studyServiceProvider = Provider<StudyService>(
  (ref) => StudyService(
    library: ref.watch(libraryRepositoryProvider),
    reviews: ref.watch(reviewRepositoryProvider),
    scheduler: ref.watch(reviewSchedulerProvider),
    clock: ref.watch(clockProvider),
    settings: ref.watch(studySettingsProvider),
  ),
);
