// The crash log on a device: the global handlers write it to the app support
// folder, and 정보 → 오류 기록 shows it.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/crash_log_screenshot_test.dart
//
// Screenshot: docs/screenshots/21_about_crash_log.png. The two errors are made
// up here (with made-up stacks, so no build machine path shows); the log is
// emptied before and after.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/file_crash_log.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/crash_reporting.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  /// Raises one framework error and one async error through the real handlers.
  Future<void> raiseTwoErrors(CrashLog log) async {
    final dispatcher = PlatformDispatcher.instance;
    final previousFlutter = FlutterError.onError;
    final previousPlatform = dispatcher.onError;
    try {
      installCrashHandlers(log, dispatcher: dispatcher, present: (_) {});
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('시험용 오류: 카드를 그리지 못함'),
          stack: StackTrace.fromString(
            '#0      WordCard.build (package:shiori/features/study/word_card.dart:42:7)\n'
            '#1      StatelessElement.build (package:flutter/src/widgets/framework.dart:5800:49)',
          ),
          context: ErrorDescription('while building WordCard'),
        ),
      );
      dispatcher.onError!(
        StateError('시험용 오류: 저장이 끝나지 않음'),
        StackTrace.fromString(
          '#0      LibraryService.saveDraft (package:shiori_core/src/library/library_service.dart:88:5)',
        ),
      );
    } finally {
      FlutterError.onError = previousFlutter;
      dispatcher.onError = previousPlatform;
    }
    for (var i = 0; i < 50 && (await log.read()).length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  testWidgets('정보 → 오류 기록 shows what the handlers wrote', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    final log = FileCrashLog.appSupport();
    await log.clear();
    addTearDown(log.clear);

    await raiseTwoErrors(log);
    expect((await log.read()).map((r) => r.source), [
      CrashSource.flutter,
      CrashSource.platform,
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          crashLogProvider.overrideWithValue(log),
        ],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 교재 페이지를 등록해 주세요'));
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    final open = find.text('오류 기록 보기');
    await tester.scrollUntilVisible(open, 200);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await waitFor(tester, find.textContaining('저장이 끝나지 않음'));
    expect(find.textContaining('카드를 그리지 못함'), findsOneWidget);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('21_about_crash_log');
  });
}
