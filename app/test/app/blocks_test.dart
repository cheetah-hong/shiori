import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmdict_block/jmdict_block.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/adapters/file_crash_log.dart';
import 'package:shiori/adapters/image_picker_source.dart';
import 'package:shiori/adapters/platform_text_recognizer.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

import '../support/dictionary.dart';

final class _FakeRecognizer implements TextRecognizer {
  @override
  String get id => 'fake';

  @override
  Future<OcrScan> recognize(PageImage image) async => const OcrScan(
    japanese: OcrPage(lines: []),
    korean: OcrPage(lines: []),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every slot starts with its first block', () {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    final c = ProviderContainer.test(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    expect(c.read(clockProvider), isA<SystemClock>());
    expect(c.read(textRecognizerProvider), isA<PlatformTextRecognizer>());
    // Tests run as the dev flavor (pubspec.yaml default-flavor).
    expect(c.read(devSamplesEnabledProvider), devSamplesEnabled);
    expect(c.read(sampleRecognizerProvider), isA<FixtureTextRecognizer>());
    expect(c.read(imageSourceProvider), isA<ImagePickerSource>());
    expect(c.read(templateRegistryProvider).templates.map((t) => t.id), [
      'vocab.list',
      'vocab.entry',
    ]);
    expect(c.read(dictionaryProvider), isA<EmptyDictionary>());
    // The core's standard chain (its order is tested in packages/core).
    expect(
      c.read(entryCorrectorsProvider).map((e) => e.id),
      standardCorrectors(const EmptyDictionary()).map((e) => e.id),
    );
    expect(c.read(libraryRepositoryProvider), isA<DriftLibraryRepository>());
    expect(c.read(reviewRepositoryProvider), isA<DriftReviewRepository>());
    expect(c.read(reviewSchedulerProvider), isA<LeitnerFourStepScheduler>());
    expect(c.read(speechProvider), isA<SilentSpeech>());
    expect(c.read(crashLogProvider), isA<FileCrashLog>());
  });

  test('swapping a block is one override', () {
    final fake = _FakeRecognizer();
    final c = ProviderContainer.test(
      overrides: [textRecognizerProvider.overrideWithValue(fake)],
    );
    expect(c.read(textRecognizerProvider), same(fake));
  });

  test('composed services follow the swapped blocks', () {
    final clock = FixedClock(DateTime(2026, 11, 5));
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    final c = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        studySettingsProvider.overrideWithValue(
          const StudySettings(intervals: [Duration(minutes: 1)], dailyGoal: 3),
        ),
      ],
    );
    expect(c.read(studyServiceProvider).clock, same(clock));
    expect(c.read(reviewSchedulerProvider).maxLevel, 1);
    expect(
      c.read(capturePipelineProvider).correctors.length,
      standardCorrectors(const EmptyDictionary()).length,
    );
  });

  test('storage needs the database opened by main', () {
    final c = ProviderContainer.test();
    expect(
      () => c.read(libraryRepositoryProvider),
      throwsA(
        predicate((e) => '$e'.contains('open the database in main.dart')),
      ),
    );
  });

  test('the storage blocks share one database and keep words', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    final c = ProviderContainer.test(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    final at = DateTime(2026, 11, 5);
    final library = c.read(libraryRepositoryProvider);
    await library.saveTextbook(Textbook(id: 'tb', title: '단어장', createdAt: at));
    await c
        .read(reviewRepositoryProvider)
        .saveCard(
          ReviewCard(
            wordId: 'tb:0001',
            level: 1,
            dueAt: at,
            lastReviewedAt: at,
          ),
        );
    expect((await library.textbooks()).single.id, 'tb');
    expect(await c.read(reviewRepositoryProvider).card('tb:0001'), isNotNull);
  });

  group('dictionary slot', () {
    test('holds the JMdict block once the bundled data is open', () async {
      final opened = BundledDictionary.opened(openMiniJmdict(), testEdition);
      addTearDown(opened.close);
      final c = ProviderContainer.test(
        overrides: [
          bundledDictionaryProvider.overrideWith((ref) async => opened),
        ],
      );
      await c.read(bundledDictionaryProvider.future);
      expect(c.read(dictionaryProvider), isA<JmdictDictionaryAdapter>());
      expect(c.read(dictionaryProvider), same(opened.jmdict));
      // The corrector chain and the pipeline are built on it.
      final pair = c
          .read(capturePipelineProvider)
          .correctors
          .whereType<DictionaryPairCorrector>()
          .single;
      expect(pair.dictionary, same(opened.jmdict));
    });

    test('stays empty without dictionary data', () async {
      final c = ProviderContainer.test(
        overrides: [
          bundledDictionaryProvider.overrideWith(
            (ref) async => const BundledDictionary.unavailable('no asset'),
          ),
        ],
      );
      await c.read(bundledDictionaryProvider.future);
      expect(c.read(dictionaryProvider), isA<EmptyDictionary>());
    });

    test('swapping the dictionary is one override', () {
      const other = EmptyDictionary();
      final c = ProviderContainer.test(
        overrides: [dictionaryProvider.overrideWithValue(other)],
      );
      expect(c.read(dictionaryProvider), same(other));
    });
  });
}
