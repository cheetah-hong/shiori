// U5: the first-run guide. Three pages on the first launch with an empty
// library, then never again once skipped or finished; not for someone who
// already has words; again from 정보 › 사용 안내 다시 보기. It never asks for
// the camera or photos. Made-up words only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/onboarding/onboarding_store.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/design.dart';
import '../support/harness.dart';
import '../support/study_modes.dart';

final class _CountingSource implements ImageSource {
  int picks = 0;

  @override
  Future<PageImage?> pick(ImageOrigin origin) async {
    picks++;
    return null;
  }

  @override
  Future<void> discard(PageImage image) async {}
}

final class _BrokenStore implements OnboardingStore {
  @override
  Future<bool> hasSeen() => Future.error(const FileSystemFailure());

  @override
  Future<void> markSeen() => Future.error(const FileSystemFailure());
}

final class FileSystemFailure implements Exception {
  const FileSystemFailure();
}

const _first = '교재 한 쪽을 찍으면';
const _second = '재생목록에 담아';
const _third = '네 가지 방식으로';

Future<void> _launch(
  WidgetTester tester,
  TestBlocks blocks,
  OnboardingStore store, {
  ImageSource? images,
}) async {
  usePhoneSize(tester);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        ...blocks.overrides,
        ...designBlocks(),
        onboardingStoreProvider.overrideWithValue(store),
        if (images != null) imageSourceProvider.overrideWithValue(images),
      ],
      child: const ShioriApp(firstLaunch: true),
    ),
  );
  await tester.pumpAndSettle();
}

bool _onHome() => find.text('오늘').evaluate().isNotEmpty;

void main() {
  testWidgets('first launch, empty library: page 1 of 3', (tester) async {
    final handle = tester.ensureSemantics();
    final store = InMemoryOnboardingStore();
    await _launch(tester, TestBlocks(), store);

    expect(find.textContaining(_first), findsOneWidget);
    expect(find.bySemanticsLabel('3장 중 1장'), findsOneWidget);
    expect(find.text('건너뛰기'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
    expect(_onHome(), isFalse);
    handle.dispose();
  });

  testWidgets('건너뛰기 goes home and the guide does not come back', (
    tester,
  ) async {
    final store = InMemoryOnboardingStore();
    final blocks = TestBlocks();
    await _launch(tester, blocks, store);
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(_onHome(), isTrue);
    expect(await store.hasSeen(), isTrue);

    await _launch(tester, blocks, store);
    expect(find.textContaining(_first), findsNothing);
    expect(_onHome(), isTrue);
  });

  testWidgets('다음 · 다음 · 시작하기 walks the three pages to home', (tester) async {
    final store = InMemoryOnboardingStore();
    await _launch(tester, TestBlocks(), store);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_second), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_third), findsOneWidget);
    expect(find.text('다음'), findsNothing);
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(_onHome(), isTrue);
    expect(await store.hasSeen(), isTrue);
  });

  testWidgets('the pages also turn by swiping', (tester) async {
    await _launch(tester, TestBlocks(), InMemoryOnboardingStore());
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(find.textContaining(_second), findsOneWidget);
  });

  testWidgets('someone who already has words never sees it', (tester) async {
    final blocks = TestBlocks();
    await seedModeWords(blocks);
    final store = InMemoryOnboardingStore();
    await _launch(tester, blocks, store);

    expect(find.textContaining(_first), findsNothing);
    expect(_onHome(), isTrue);
    expect(await store.hasSeen(), isTrue, reason: 'marked for next time');
  });

  testWidgets('the mark cannot be read, empty library: the guide shows', (
    tester,
  ) async {
    await _launch(tester, TestBlocks(), _BrokenStore());
    expect(find.textContaining(_first), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(_onHome(), isTrue, reason: 'a failed write does not trap you');
  });

  testWidgets('the mark cannot be read, words there: straight home', (
    tester,
  ) async {
    final blocks = TestBlocks();
    await seedModeWords(blocks);
    await _launch(tester, blocks, _BrokenStore());
    expect(find.textContaining(_first), findsNothing);
    expect(_onHome(), isTrue);
  });

  testWidgets('without firstLaunch (tests, previews) the app opens on 홈', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(TestBlocks()));
    await tester.pumpAndSettle();
    expect(_onHome(), isTrue);
  });

  testWidgets('it never asks for the camera or photos', (tester) async {
    final images = _CountingSource();
    await _launch(
      tester,
      TestBlocks(),
      InMemoryOnboardingStore(),
      images: images,
    );
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(images.picks, 0);
  });

  testWidgets('정보 › 사용 안내 다시 보기 shows it, 건너뛰기 goes back', (tester) async {
    final store = InMemoryOnboardingStore(seen: true);
    final blocks = TestBlocks();
    await seedModeWords(blocks);
    await _launch(tester, blocks, store);
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    await tapDesignText(tester, '사용 안내 다시 보기');

    expect(find.textContaining(_first), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '정보'), findsOneWidget);
  });

  for (final scale in designTextScales) {
    testWidgets('the three pages at ×$scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await _launch(tester, TestBlocks(), InMemoryOnboardingStore());
      for (final next in ['다음', '다음']) {
        await tapDesignText(tester, next);
      }
      expect(find.text('시작하기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the guide\'s buttons are 44 pt', (tester) async {
    final handle = tester.ensureSemantics();
    await _launch(tester, TestBlocks(), InMemoryOnboardingStore());
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
