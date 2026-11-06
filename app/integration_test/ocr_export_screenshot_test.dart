// "판독 기록 내보내기" on a simulator: a build that is not a release build shows
// the export button in the review screen's top bar.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/ocr_export_screenshot_test.dart
//
// The screenshot lands in docs/screenshots/. Uses the synthetic sample pages
// only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  testWidgets('review screen: the export button', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    final sample = find.text(generalDevSamples.first.detail);
    await tester.scrollUntilVisible(sample, 200);
    await tester.pumpAndSettle();
    await tester.tap(sample);
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));
    expect(find.byTooltip('판독 기록 내보내기'), findsOneWidget);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('40_review_ocr_export');
  });
}
