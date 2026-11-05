// The sample pages ("샘플 페이지로 해 보기") belong to the dev flavor only.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/capture/capture_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  group('sample pages follow the flavor, not the build mode', () {
    test('dev: on', () {
      expect(devSamplesEnabledFor('dev'), isTrue);
    });

    test('prod: off', () {
      expect(devSamplesEnabledFor('prod'), isFalse);
    });

    test('no flavor: off', () {
      expect(devSamplesEnabledFor(null), isFalse);
    });

    test('any other name: off', () {
      for (final flavor in ['Dev', 'DEV', 'staging', '', ' dev']) {
        expect(devSamplesEnabledFor(flavor), isFalse, reason: flavor);
      }
    });

    test('the build switch is the flavor this build was made with', () {
      expect(devSamplesEnabled, devSamplesEnabledFor(appFlavor));
    });
  });

  test('prod: the sample block refuses every page', () async {
    final c = ProviderContainer.test(
      overrides: [
        devSamplesEnabledProvider.overrideWithValue(
          devSamplesEnabledFor('prod'),
        ),
      ],
    );
    expect(
      c.read(sampleRecognizerProvider).recognize(const PageImage('s010')),
      throwsA(isA<TextRecognitionException>()),
    );
  });

  for (final (flavor, shown) in [('dev', true), ('prod', false)]) {
    testWidgets('$flavor: "샘플 페이지로 해 보기" is ${shown ? '' : 'not '}there', (
      tester,
    ) async {
      usePhoneSize(tester);
      final blocks = TestBlocks()..devSamples = devSamplesEnabledFor(flavor);
      await tester.pumpWidget(screen(blocks, const CaptureScreen()));
      await tester.pumpAndSettle();

      final label = find.text('샘플 페이지로 해 보기', skipOffstage: false);
      final firstSample = find.text(
        devSamples.first.detail,
        skipOffstage: false,
      );
      expect(label, shown ? findsOneWidget : findsNothing);
      expect(firstSample, shown ? findsWidgets : findsNothing);
      // The photo sources are there either way.
      expect(find.text('카메라로 찍기'), findsOneWidget);
      expect(find.text('앨범에서 고르기'), findsOneWidget);
    });
  }
}
