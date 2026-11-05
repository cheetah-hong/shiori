// The review screen with the Korean glossary plugged in: a meaning the page
// did not give is filled from the dictionary and shown as a guess (추정).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_glossary.dart';

import '../support/glossary.dart';
import '../support/harness.dart';

/// Opens sample page 11 (the second "DAY 01 자연, 몸" sample).
Future<void> openPage11(WidgetTester tester) async {
  await tester.tap(find.text('페이지 등록'));
  await tester.pumpAndSettle();
  final page11 = find.text('DAY 01 자연, 몸').last;
  await tester.ensureVisible(page11);
  await tester.pumpAndSettle();
  await tester.tap(page11);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('鼻 read without its meaning gets 코, marked 추정', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final opened = BundledGlossary.opened(openMiniKrdict(), testGlossaryEdition);
    addTearDown(opened.close);
    blocks.glossary = opened;
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await openPage11(tester);

    expect(find.text('DAY 01 자연, 몸 · 11쪽'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('鼻'), 200);
    expect(find.text('코'), findsOneWidget);
    expect(find.text('뜻 없음'), findsNothing);
    expect(
      find.byKey(const ValueKey('mark-meaning-inferred')),
      findsOneWidget,
    );
  });

  testWidgets('without the glossary the same meaning is flagged as missing', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(TestBlocks()));
    await tester.pumpAndSettle();
    await openPage11(tester);
    await tester.scrollUntilVisible(find.text('鼻'), 200);
    expect(find.text('뜻 없음'), findsOneWidget);
  });
}
