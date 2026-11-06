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
    expect(c.read(lexiconProvider), isA<EmptyLexicon>());
    expect(c.read(koreanGlossaryProvider), isA<EmptyKoreanGlossary>());
    expect(c.read(generalExtractorProvider).lexicon, isA<EmptyLexicon>());
    expect(c.read(libraryRepositoryProvider), isA<DriftLibraryRepository>());
    expect(c.read(reviewRepositoryProvider), isA<DriftReviewRepository>());
    expect(
      c.read(studyPreferencesRepositoryProvider),
      isA<DriftStudyPreferencesRepository>(),
    );
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
    await library.savePlaylist(
      Playlist(id: 'pl', name: '단어장', createdAt: at, position: 0),
    );
    await library.insertWords([
      Word(
        id: 'w-1',
        headword: '雨',
        readings: const [],
        meaning: '비',
        createdAt: at,
      ),
    ]);
    await c
        .read(reviewRepositoryProvider)
        .saveCard(
          ReviewCard(wordId: 'w-1', level: 1, dueAt: at, lastReviewedAt: at),
        );
    await c
        .read(studyPreferencesRepositoryProvider)
        .save(const StudyPreferences(scopeMode: StudyScopeMode.playlistOnly));
    expect((await library.playlists()).single.id, 'pl');
    expect(await c.read(reviewRepositoryProvider).card('w-1'), isNotNull);
    expect(
      (await DriftStudyPreferencesRepository(db).load()).scopeMode,
      StudyScopeMode.playlistOnly,
    );
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
      final lexicon = c.read(lexiconProvider);
      expect(lexicon, isA<JmdictLexiconAdapter>());
      expect((lexicon as JmdictLexiconAdapter).jmdict, same(opened.jmdict));
      // The word extractor is built on it.
      expect(
        c.read(generalExtractorProvider).lexicon,
        isA<JmdictLexiconAdapter>(),
      );
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
      expect(c.read(lexiconProvider), isA<EmptyLexicon>());
    });

    test('swapping the dictionary is one override', () {
      final other = InMemoryLexicon(const []);
      final c = ProviderContainer.test(
        overrides: [lexiconProvider.overrideWithValue(other)],
      );
      expect(c.read(lexiconProvider), same(other));
      expect(c.read(generalExtractorProvider).lexicon, same(other));
    });
  });
}
