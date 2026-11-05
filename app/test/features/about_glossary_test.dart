// K13: the 정보 screen credits the Korean glossary with its edition.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/features/about/about_screen.dart';

import '../support/glossary.dart';
import '../support/harness.dart';

const _credit = '한국어기초사전, 국립국어원, CC BY-SA 2.0 KR, 2026-10-19판을 가공함';
const _licenseUrl = 'https://creativecommons.org/licenses/by-sa/2.0/kr/';

void main() {
  testWidgets('with the glossary: the credit line, the date and the licence', (
    tester,
  ) async {
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

    await tester.scrollUntilVisible(find.text(_credit), 200);
    expect(find.text(_credit), findsOneWidget);
    expect(find.textContaining('2026-10-19'), findsWidgets);
    await tester.scrollUntilVisible(find.text(_licenseUrl), 200);
    expect(find.text(_licenseUrl), findsOneWidget);
  });

  testWidgets('without the glossary the screen says so', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), const AboutScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('한국어 뜻 사전이'), 200);
    expect(find.textContaining('한국어 뜻 사전이 들어 있지 않아요'), findsOneWidget);
    expect(find.text(_credit), findsNothing);
  });

  test('the Basic Korean Dictionary is listed among the licences', () async {
    registerGlossaryLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final krdict = entries.where((e) => e.packages.contains('한국어기초사전'));
    expect(krdict, isNotEmpty);
    final text = krdict.first.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('국립국어원'));
    expect(text, contains(_licenseUrl));
  });
}
