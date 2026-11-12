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

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/accent_data.dart';
import 'package:shiori/adapters/backup_files.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/bundled_examples.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/adapters/file_crash_log.dart';
import 'package:shiori/adapters/image_picker_source.dart';
import 'package:shiori/adapters/platform_text_recognizer.dart';
import 'package:shiori/adapters/voicevox_speech.dart';
import 'package:shiori/app/crash_reporting.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:voicevox_block/voicevox_block.dart';

// ---------------------------------------------------------------- block slots

/// Time. Tests override it with `FixedClock`.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Device OCR: Apple Vision (iOS) / ML Kit (Android). Next: Cloud Vision, Claude.
final textRecognizerProvider = Provider<TextRecognizer>(
  (ref) => const PlatformTextRecognizer(),
);

/// Whether "샘플 페이지로 해 보기" is on: the dev flavor only (`dev_samples.dart`).
final devSamplesEnabledProvider = Provider<bool>((ref) => devSamplesEnabled);

/// "샘플 페이지로 해 보기": recorded OCR from assets (dev flavor only).
final sampleRecognizerProvider = Provider<TextRecognizer>(
  (ref) => devSampleRecognizer(
    rootBundle,
    enabled: ref.watch(devSamplesEnabledProvider),
  ),
);

/// Page photos: image_picker. Next: document scanner, page flattening.
final imageSourceProvider = Provider<ImageSource>((ref) => ImagePickerSource());

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

/// The Korean glossary (한국어기초사전) unpacked from the app's assets, like
/// JMdict: `main.dart` starts opening it before the first frame.
/// Never fails: without the asset it holds `BundledGlossary.unavailable`.
final bundledGlossaryProvider = FutureProvider<BundledGlossary>((ref) async {
  final glossary = await openAppGlossary();
  ref.onDispose(glossary.close);
  return glossary;
});

/// Korean meanings for meaning cells the page did not give: the glossary
/// once it is open, `EmptyKoreanGlossary` until then or without data.
final koreanGlossaryProvider = Provider<KoreanGlossary>(
  (ref) =>
      ref.watch(bundledGlossaryProvider).value?.glossary ??
      const EmptyKoreanGlossary(),
);

/// Meanings of words the glossary has none for: the Wiktionary fallback
/// glossary unpacked with it (docs/dictionary.md, 13), null until then or
/// without its asset. Only the meaning of a dictionary word the page gives
/// none is filled from it; pairing uses [koreanGlossaryProvider] alone.
final wiktionaryGlossaryProvider = Provider<KoreanGlossary?>(
  (ref) => ref.watch(bundledGlossaryProvider).value?.wiktionary,
);

/// The Tatoeba example sentences unpacked from the app's assets, like the
/// dictionaries. Never fails: without the asset (a debug build) it holds
/// `BundledExamples.unavailable` and cards show page examples only.
final bundledExamplesProvider = FutureProvider<BundledExamples>((ref) async {
  final examples = await openAppExamples();
  ref.onDispose(examples.close);
  return examples;
});

/// Sentences for words whose page printed no example: Tatoeba once it is
/// open, `EmptyExampleSentences` until then or without the asset.
final exampleSentencesProvider = Provider<ExampleSentences>(
  (ref) =>
      ref.watch(bundledExamplesProvider).value?.sentences ??
      const EmptyExampleSentences(),
);

/// Dictionary facts for the general word extractor (forms, readings, POS,
/// frequency): JMdict once it is open, `EmptyLexicon` until then or without
/// dictionary data.
final lexiconProvider = Provider<Lexicon>(
  (ref) =>
      ref.watch(bundledDictionaryProvider).value?.lexicon ??
      const EmptyLexicon(),
);

/// The SQLite file behind the storage blocks. `main.dart` finds it (the app
/// support folder is only known asynchronously) and overrides this provider
/// with one that opens it (`startup.dart`); invalidating it opens a fresh
/// connection. Tests override the repositories, or this with
/// `ShioriDatabase.memory()`.
final appDatabaseProvider = Provider<ShioriDatabase>(
  (ref) => throw StateError(
    'appDatabaseProvider is not set: open the database in main.dart',
  ),
);

/// Library storage (words, playlists): SQLite (drift). Tests:
/// `InMemoryLibraryRepository`.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => DriftLibraryRepository(ref.watch(appDatabaseProvider)),
);

/// Learning state storage: SQLite (drift). Tests: `InMemoryReviewRepository`.
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => DriftReviewRepository(ref.watch(appDatabaseProvider)),
);

/// The learner's study options (설정): SQLite (drift). Tests:
/// `InMemoryStudyPreferencesRepository`.
final studyPreferencesRepositoryProvider = Provider<StudyPreferencesRepository>(
  (ref) => DriftStudyPreferencesRepository(ref.watch(appDatabaseProvider)),
);

/// The stored study options, read once and again after the settings screen
/// saves (it invalidates this).
final studyPreferencesProvider = FutureProvider<StudyPreferences>(
  (ref) => ref.watch(studyPreferencesRepositoryProvider).load(),
);

/// Intervals, day start hour, session size.
final studySettingsProvider = Provider<StudySettings>(
  (ref) => const StudySettings(),
);

/// What a shuffled session (설정 › 카드 순서 섞기) is shuffled with. Tests
/// plug in a seeded one.
final sessionRandomProvider = Provider<Random Function()>((ref) => Random.new);

/// Review timing: four Leitner steps. Next: FSRS.
final reviewSchedulerProvider = Provider<ReviewScheduler>(
  (ref) => LeitnerFourStepScheduler.checked(
    ref.watch(studySettingsProvider).intervals,
  ),
);

/// Pronunciation: VOICEVOX on the device (iOS and Android); elsewhere the
/// card shows no speaker buttons.
final speechProvider = Provider<Speech>((ref) => appVoicevoxSpeech());

/// Pitch accents (Kanjium) for the pitch line and the word's sound; an empty
/// table when the build has no accent data.
final accentTableProvider = FutureProvider<AccentTable>(
  (ref) async => (await ref.watch(accentDataProvider.future)).table,
);

/// The accent data with its edition (for the 정보 screen).
final accentDataProvider = FutureProvider<AccentData>(
  (ref) => openAppAccentData(),
);

/// Uncaught errors, kept on the device for the 정보 screen. `main.dart` plugs
/// in the same log its global error handlers write to. Next: a crash service
/// (docs/architecture.md, 5).
final crashLogProvider = Provider<CrashLog>((ref) => FileCrashLog.appSupport());

/// 설정 › 백업: every table read and replaced at once (SQLite).
final backupStoreProvider = Provider<BackupStore>(
  (ref) => DriftBackupStore(ref.watch(appDatabaseProvider)),
);

/// The copy kept before a restore: a file in the app support folder.
final backupKeeperProvider = Provider<BackupKeeper>(
  (ref) => FileBackupKeeper.appSupport(),
);

/// The app written into a backup file's header (version, build, schema).
final backupAppProvider = Provider<Future<BackupApp> Function()>(
  (ref) =>
      () => installedApp(schema: ref.read(appDatabaseProvider).schemaVersion),
);

/// Where a large backup is encoded and checked: another isolate. Tests run
/// it in place.
final backupWorkProvider = Provider<BackupWork>((ref) => backupWorkElsewhere);

/// The share sheet a new backup file goes to. Tests plug in a fake.
final backupShareProvider = Provider<BackupShare>((ref) => shareBackupFile);

/// The file picker a backup is restored from. Tests plug in a fake.
final backupPickerProvider = Provider<BackupPicker>((ref) => pickBackupFile);

/// "높음 전체 승인" on the review screen: confirms every entry whose
/// pairings are all high. On because no measured set has a high entry that
/// is wrong (docs/verification.md, 15 and 20); turn it off here if one
/// appears.
final highConfidenceApprovalProvider = Provider<bool>((ref) => true);

// ---------------------------------------------------------------- composed from the blocks above

/// The word extractor every page is read with: JMdict for the forms, the
/// Korean glossary for pairing and for meanings the page does not give, and
/// the Wiktionary fallback for meanings the glossary has none for.
final generalExtractorProvider = Provider<GeneralExtractor>((ref) {
  final glossary = ref.watch(koreanGlossaryProvider);
  return GeneralExtractor(
    lexicon: ref.watch(lexiconProvider),
    koreanGlossary: glossary is EmptyKoreanGlossary ? null : glossary,
    meaningFallback: ref.watch(wiktionaryGlossaryProvider),
  );
});

/// The example a study card shows: the word's page example, else a Tatoeba
/// sentence of its dictionary entry (looked up when the card is shown, so
/// nothing is stored, and a card's answer goes when no card shows it), else
/// null.
final cardExampleProvider = FutureProvider.autoDispose
    .family<CardExample?, Word>(
      (ref, word) => cardExampleOf(
        word,
        lexicon: ref.watch(lexiconProvider),
        examples: ref.watch(exampleSentencesProvider),
      ),
    );

final libraryServiceProvider = Provider<LibraryService>(
  (ref) => LibraryService(
    library: ref.watch(libraryRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    store: ref.watch(backupStoreProvider),
    keeper: ref.watch(backupKeeperProvider),
    clock: ref.watch(clockProvider),
    app: ref.watch(backupAppProvider),
    work: ref.watch(backupWorkProvider),
  ),
);

final studyServiceProvider = Provider<StudyService>(
  (ref) => StudyService(
    library: ref.watch(libraryRepositoryProvider),
    reviews: ref.watch(reviewRepositoryProvider),
    scheduler: ref.watch(reviewSchedulerProvider),
    clock: ref.watch(clockProvider),
    settings: ref.watch(studySettingsProvider),
    random: ref.watch(sessionRandomProvider),
    // Only the record mode shapes the service; until the options are read
    // (or when they cannot be), the default. Watching the whole options
    // would rebuild the service, and every summary with it, when the study
    // mode is picked or first read.
    preferences: StudyPreferences(
      recordMode: ref.watch(
        studyPreferencesProvider.select(
          (p) => p.value?.recordMode ?? RecordMode.shared,
        ),
      ),
    ),
  ),
);
