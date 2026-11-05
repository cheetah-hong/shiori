// Checks on a simulator that words and learning state outlive the app process.
// Uses the real database file (openAppDatabase) and a synthetic sample page.
//
//   cd app
//   xcrun simctl uninstall <simulator> com.nihongoapp.shiori.dev   # start empty (dev flavor)
//   flutter drive -d <simulator> --keep-app-running --driver=test_driver/integration_test.dart \
//     --target=integration_test/persistence_test.dart \
//     --dart-define=SHIORI_PERSISTENCE_STEP=save
//   xcrun simctl terminate <simulator> com.nihongoapp.shiori.dev
//   flutter drive ... (same) --dart-define=SHIORI_PERSISTENCE_STEP=reopen
//
// Screenshots land in docs/screenshots/ (see test_driver/integration_test.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/app_database.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

const _step = String.fromEnvironment('SHIORI_PERSISTENCE_STEP');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  /// Pumps until [finder] shows up (providers load asynchronously on device).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).first;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<ShioriDatabase> pumpApp(WidgetTester tester) async {
    final database = await openAppDatabase();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    return database;
  }

  testWidgets('save a page and study it', (tester) async {
    await pumpApp(tester);
    await waitFor(tester, find.text('먼저 교재 페이지를 등록해 주세요'));

    await tapText(tester, '페이지 등록');
    await tapText(tester, 'DAY 20 여행·교통');
    await tapText(tester, '단어 6개 저장');
    await tapText(tester, '오늘 학습 시작 · 6장');
    await tapText(tester, '다시 학습');
    for (var i = 0; i < 6; i++) {
      await tapText(tester, '알고있음');
    }
    expect(find.text('오늘 학습 끝'), findsOneWidget);
    await tapText(tester, '확인');
    await waitFor(tester, find.text('오늘 6개 외움'));
  }, skip: _step != 'save');

  testWidgets('after a restart the words and memory levels are back', (
    tester,
  ) async {
    final database = await pumpApp(tester);
    await waitFor(tester, find.text('오늘 6개 외움'));
    expect(find.text('먼저 교재 페이지를 등록해 주세요'), findsNothing);

    // Read back from the file: 6 words; the retried word at level 2, the
    // others at level 4; 7 presses (one 다시 학습, six 알고있음).
    final words = await DriftLibraryRepository(database).words();
    final reviews = DriftReviewRepository(database);
    final levels = (await reviews.cards()).values.map((c) => c.level).toList()
      ..sort();
    expect(words.length, 6);
    expect(levels, [2, 4, 4, 4, 4, 4]);
    expect((await reviews.logs()).length, 7);

    await tapText(tester, 'JLPT 단어장');
    await tester.scrollUntilVisible(find.text('DAY 20  여행·교통'), 400);
    await shot(tester, '16_textbook_after_restart');
  }, skip: _step != 'reopen');
}
