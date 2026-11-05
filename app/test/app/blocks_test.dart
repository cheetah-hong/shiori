import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/image_picker_source.dart';
import 'package:shiori/adapters/platform_text_recognizer.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';

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
    final c = ProviderContainer.test();
    expect(c.read(clockProvider), isA<SystemClock>());
    expect(c.read(textRecognizerProvider), isA<PlatformTextRecognizer>());
    expect(c.read(sampleRecognizerProvider), isA<FixtureTextRecognizer>());
    expect(c.read(imageSourceProvider), isA<ImagePickerSource>());
    expect(c.read(templateRegistryProvider).templates.map((t) => t.id), [
      'vocab.list',
      'vocab.entry',
    ]);
    expect(c.read(dictionaryProvider), isA<EmptyDictionary>());
    expect(c.read(entryCorrectorsProvider).map((e) => e.id), [
      'confusable-glyphs',
      'kana-okurigana',
      'dictionary-candidates',
      'missing-fields',
    ]);
    expect(c.read(libraryRepositoryProvider), isA<InMemoryLibraryRepository>());
    expect(c.read(reviewRepositoryProvider), isA<InMemoryReviewRepository>());
    expect(c.read(reviewSchedulerProvider), isA<LeitnerFourStepScheduler>());
    expect(c.read(speechProvider), isA<SilentSpeech>());
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
    final c = ProviderContainer.test(
      overrides: [
        clockProvider.overrideWithValue(clock),
        studySettingsProvider.overrideWithValue(
          const StudySettings(intervals: [Duration(minutes: 1)], dailyGoal: 3),
        ),
      ],
    );
    expect(c.read(studyServiceProvider).clock, same(clock));
    expect(c.read(reviewSchedulerProvider).maxLevel, 1);
    expect(c.read(capturePipelineProvider).correctors.length, 4);
  });
}
