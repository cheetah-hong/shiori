// The flavor on a device: the dev build shows and bundles the sample pages,
// the prod build does neither.
//
//   cd app && flutter test integration_test/flavor_check_test.dart -d <device> --flavor prod
//   (and --flavor dev)
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sample pages: shown and bundled in dev only', (tester) async {
    final isDev = appFlavor == devFlavor;
    expect(appFlavor, isNotNull, reason: 'run with --flavor dev or prod');
    expect(devSamplesEnabled, isDev);

    final sampleFile = '$devSampleDir/${devSamples.first.id}.ja.json';
    final bundled = await rootBundle
        .loadString(sampleFile)
        .then((_) => true, onError: (Object _) => false);
    expect(bundled, isDev, reason: sampleFile);

    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    for (var i = 0; i < 100 && find.text('페이지 등록').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('페이지 등록').first);
    await tester.pumpAndSettle();
    expect(find.text('카메라로 찍기'), findsOneWidget);
    expect(
      find.text('샘플 페이지로 해 보기', skipOffstage: false),
      isDev ? findsOneWidget : findsNothing,
    );
  });
}
