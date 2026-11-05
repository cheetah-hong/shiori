import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/features/about/about_screen.dart';

import '../support/dictionary.dart';
import '../support/harness.dart';

const _projectUrl =
    'https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project';
const _licenseUrl = 'https://www.edrdg.org/edrdg/licence.html';

void main() {
  testWidgets('home → 정보: the JMdict notice, both links, the edition', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final opened = BundledDictionary.opened(openMiniJmdict(), testEdition);
    addTearDown(opened.close);
    blocks.dictionary = opened;
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(
      find.textContaining('This application uses the JMdict dictionary files'),
      findsOneWidget,
    );
    expect(find.text(_projectUrl), findsOneWidget);
    expect(find.text(_licenseUrl), findsOneWidget);
    expect(find.textContaining(testEdition.sourceSha256), findsOneWidget);
    expect(find.textContaining('2026-11-04'), findsWidgets);
    expect(find.textContaining('2026-11-05'), findsWidgets);
    expect(find.textContaining('CC BY-SA 4.0'), findsWidgets);
  });

  testWidgets('without dictionary data the screen says so', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), const AboutScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('사전 데이터가 들어 있지 않아요'), findsOneWidget);
    expect(find.textContaining(testEdition.sourceSha256), findsNothing);
  });

  testWidgets('the open source licences are one tap away', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), const AboutScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('오픈소스 라이선스'), 200);
    await tester.tap(find.text('오픈소스 라이선스'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  test('JMdict is listed among the licences', () async {
    registerDictionaryLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final jmdict = entries.where((e) => e.packages.contains('JMdict'));
    expect(jmdict, isNotEmpty);
    final text = jmdict.first.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('Electronic Dictionary Research and Development'));
    expect(text, contains(_licenseUrl));
  });
}
