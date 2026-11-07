// W5: the 정보 screen credits the Wiktionary fallback glossary in a card of
// its own, and the licence page lists it.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/features/about/about_screen.dart';

import '../support/glossary.dart';
import '../support/harness.dart';
import '../support/wikt.dart';

const _licenseUrl = 'https://creativecommons.org/licenses/by-sa/4.0/';

void main() {
  testWidgets('with the fallback: its card, the credit, the editions and the '
      'licence', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final opened = BundledGlossary.opened(
      openMiniKrdict(),
      testGlossaryEdition,
      wiktionary: openMiniWikt(),
      wiktionaryEdition: testWiktEdition,
    );
    addTearDown(opened.close);
    blocks.glossary = opened;
    await tester.pumpWidget(screen(blocks, const AboutScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('위키낱말사전'), 200);
    expect(find.text('위키낱말사전'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('2026-11-01'), 200);
    expect(find.textContaining('2026-11-01'), findsWidgets);
    expect(find.textContaining('2026-10-01'), findsWidgets);
    expect(find.textContaining('CC BY-SA 4.0'), findsWidgets);
    await tester.scrollUntilVisible(find.text(_licenseUrl), 200);
    expect(find.text(_licenseUrl), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('https://ko.wiktionary.org'),
      200,
    );
    expect(find.text('https://ko.wiktionary.org'), findsOneWidget);
    // The Basic Korean Dictionary card stays.
    expect(
      find.text('한국어기초사전, 국립국어원, CC BY-SA 2.0 KR, 2026-10-19판을 가공함'),
      findsOneWidget,
    );
  });

  testWidgets('without the fallback the card says so', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final opened = BundledGlossary.opened(
      openMiniKrdict(),
      testGlossaryEdition,
    );
    addTearDown(opened.close);
    blocks.glossary = opened;
    await tester.pumpWidget(screen(blocks, const AboutScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('위키낱말사전 뜻이 들어 있지 않아요'),
      200,
    );
    expect(find.textContaining('위키낱말사전 뜻이 들어 있지 않아요'), findsOneWidget);
    expect(find.text(_licenseUrl), findsNothing);
  });

  test('Wiktionary is listed among the licences', () async {
    registerGlossaryLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final wikt = entries.where((e) => e.packages.contains('위키낱말사전'));
    expect(wikt, isNotEmpty);
    final text = wikt.first.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('CC BY-SA 4.0'));
    expect(text, contains(_licenseUrl));
    expect(text, contains('wiktionary.org'));
    expect(entries.where((e) => e.packages.contains('한국어기초사전')), isNotEmpty);
  });
}
