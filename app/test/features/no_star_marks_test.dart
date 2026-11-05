// The textbook's ★ means nothing to the learner: the sample pages print it, but
// no screen shows it and the edit sheet has nothing to switch. Synthetic
// sample pages only.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/capture/capture_controller.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori/features/library/textbook_screen.dart';
import 'package:shiori/features/study/word_card.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

/// The synthetic pages in the ML Kit shape (`m011`, `m140`), kept in core.
const _mlKitDir = '../packages/core/test/fixtures/synthetic_mlkit';

final _mlKitRecognizer = FixtureTextRecognizer(
  (name) => SynchronousFuture(File('$_mlKitDir/$name').readAsStringSync()),
);

final class _Camera implements ImageSource {
  _Camera(this.page);

  final String page;
  final discarded = <String>[];

  @override
  Future<PageImage?> pick(ImageOrigin origin) async => PageImage(page);

  @override
  Future<void> discard(PageImage image) async => discarded.add(image.path);
}

final Finder _anyStar = find.textContaining(RegExp('[★☆]'));

Future<CaptureDraft> _draftOf(String page) async => CapturePipeline.standard()
    .fromScan(await fixtureFileRecognizer.recognize(PageImage(page)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final page in ['s011', 's140', 's147']) {
    testWidgets('review screen of $page shows no ★', (tester) async {
      usePhoneSize(tester);
      final draft = await _draftOf(page);
      await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: draft)));
      await tester.pumpAndSettle();
      expect(find.text('검토'), findsOneWidget);
      expect(_anyStar, findsNothing);
    });
  }

  testWidgets('the edit sheet has no ★ switch', (tester) async {
    usePhoneSize(tester);
    final draft = await _draftOf('s011');
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: draft)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('川'));
    await tester.pumpAndSettle();
    expect(find.text('고치기'), findsWidgets, reason: 'the sheet is open');
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(_anyStar, findsNothing);
    expect(find.textContaining('기출'), findsNothing);
  });

  testWidgets('textbook screen shows no ★', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final textbook = await blocks.seedPage('s011');
    await blocks.seedPage('s140');
    await tester.pumpWidget(
      screen(blocks, TextbookScreen(textbookId: textbook.id)),
    );
    await tester.pumpAndSettle();
    expect(find.text('川'), findsOneWidget);
    expect(_anyStar, findsNothing);
    await tester.scrollUntilVisible(find.text('DAY 20  여행·교통'), 300);
    expect(_anyStar, findsNothing);
  });

  testWidgets('study card shows no ★, before and after revealing', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s140');
    final words = await blocks.library.words();
    final word = words.singleWhere((w) => w.no == '1211');
    await tester.pumpWidget(
      screen(
        blocks,
        Scaffold(
          body: WordCard(
            item: SessionItem(word: word, before: null),
            maxLevel: 4,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('乗り換える'), findsOneWidget);
    expect(_anyStar, findsNothing);
    await tester.tap(find.text('뜻 보기'));
    await tester.pumpAndSettle();
    expect(_anyStar, findsNothing);
    expect(find.textContaining('기출'), findsNothing);
  });

  test('the capture flow ends at the review draft with no ★ step', () async {
    for (final (page, recognizer) in [
      ('m011', _mlKitRecognizer),
      ('m140', _mlKitRecognizer),
      ('s011', fixtureFileRecognizer),
    ]) {
      final camera = _Camera(page);
      final c = ProviderContainer.test(
        overrides: [
          imageSourceProvider.overrideWithValue(camera),
          textRecognizerProvider.overrideWithValue(recognizer),
          capturePipelineProvider.overrideWithValue(CapturePipeline.standard()),
        ],
      );
      c.listen(captureControllerProvider, (_, _) {});
      await c.read(captureControllerProvider.notifier).pick(ImageOrigin.camera);
      expect(camera.discarded, [page], reason: 'the photo is freed');
      final state = c.read(captureControllerProvider);
      expect(state, isA<CaptureReady>(), reason: page);
      final draft = (state as CaptureReady).draft;
      final expected = await CapturePipeline.standard().fromScan(
        await recognizer.recognize(PageImage(page)),
      );
      expect(draft.entries, expected.entries, reason: page);
    }
  });
}
