// V10: "판독 기록 내보내기" on the review screen of a build that is not a
// release build. It hands both OCR passes in the recorded-fixture format
// (`<name>.ja.json`, `<name>.ko.json`) and the route decision to the share
// sheet, never the photo; a release build has no such button.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/capture/ocr_export.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

Future<({CaptureDraft draft, OcrScan scan})> _page() async {
  final scan = await fixtureFileRecognizer.recognize(const PageImage('g01'));
  final draft = await CaptureRouter(
    template: CapturePipeline.standard(),
    general: GeneralExtractor(),
  ).fromScan(scan);
  return (draft: draft, scan: scan);
}

void _sameLines(OcrPage a, OcrPage b) {
  expect(b.lines, hasLength(a.lines.length));
  for (final (i, l) in a.lines.indexed) {
    final m = b.lines[i];
    expect(
      (m.text, m.confidence, m.x, m.y, m.width, m.height),
      (l.text, l.confidence, l.x, l.y, l.width, l.height),
      reason: 'line $i',
    );
  }
}

void main() {
  testWidgets('not a release build: the button hands both passes and the '
      'route to the share sheet, and they read back as the same lines', (
    tester,
  ) async {
    usePhoneSize(tester);
    final page = (await tester.runAsync(_page))!;
    final shared = <ExportFile>[];
    await tester.pumpWidget(
      screen(
        TestBlocks(),
        ReviewScreen(
          draft: page.draft,
          scan: page.scan,
          photo: Uint8List.fromList(const [1, 2, 3]),
        ),
        extra: [
          ocrExportProvider.overrideWithValue(
            OcrExport(
              enabled: true,
              share: (files) async => shared.addAll(files),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    final button = find.byTooltip('판독 기록 내보내기');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pump();

    expect(shared, hasLength(3));
    final byName = {for (final f in shared) f.name: f.text};
    final ja = byName.keys.singleWhere((n) => n.endsWith('.ja.json'));
    final name = ja.substring(0, ja.length - '.ja.json'.length);
    expect(byName.keys.toSet(), {
      '$name.ja.json',
      '$name.ko.json',
      '$name.route.json',
    });

    final again = (await tester.runAsync(
      () => FixtureTextRecognizer(
        (n) async => byName[n]!,
      ).recognize(PageImage(name)),
    ))!;
    _sameLines(page.scan.japanese, again.japanese);
    _sameLines(page.scan.korean, again.korean);
    expect(again.japanese.engine, page.scan.japanese.engine);
    expect(again.korean.languages, page.scan.korean.languages);

    final route = (jsonDecode(byName['$name.route.json']!) as Map)
        .cast<String, Object?>();
    expect(route['route'], page.draft.route!.route.name);
    expect(route['reasons'], [
      for (final r in page.draft.route!.reasons) r.name,
    ]);
    expect(route['fit'], isA<Map<String, Object?>>());
    // The photo never leaves the phone this way.
    for (final f in shared) {
      expect(f.name, endsWith('.json'));
    }
  });

  testWidgets('a release build has no export button', (tester) async {
    usePhoneSize(tester);
    final page = (await tester.runAsync(_page))!;
    await tester.pumpWidget(
      screen(
        TestBlocks(),
        ReviewScreen(draft: page.draft, scan: page.scan),
        extra: [
          ocrExportProvider.overrideWithValue(
            OcrExport(enabled: false, share: (files) async {}),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byTooltip('판독 기록 내보내기'), findsNothing);
  });

  testWidgets('without OCR passes (an old draft) there is nothing to export', (
    tester,
  ) async {
    usePhoneSize(tester);
    final page = (await tester.runAsync(_page))!;
    await tester.pumpWidget(
      screen(
        TestBlocks(),
        ReviewScreen(draft: page.draft),
        extra: [
          ocrExportProvider.overrideWithValue(
            OcrExport(enabled: true, share: (files) async {}),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byTooltip('판독 기록 내보내기'), findsNothing);
  });

  test('the default follows the build: on unless it is a release build', () {
    expect(defaultOcrExportEnabled, !kReleaseMode);
  });
}
