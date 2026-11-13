// M1 (정보 screen): with the meaning overrides file the Korean glossary part
// has a 「시오리 보정」 card — how many words, where the meanings come from,
// the file's day and licence; without it there is no such card.
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/features/about/about_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/glossary.dart';
import '../support/harness.dart';

void main() {
  testWidgets('with the file: its card, the count, the day and the licence', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final opened = BundledGlossary.opened(
      openMiniKrdict(),
      testGlossaryEdition,
      overrides: MeaningOverrides(const [
        MeaningOverride(forms: ['鼻'], reading: 'はな', meaning: '코끝'),
        MeaningOverride(forms: ['耳'], reading: 'みみ', meaning: '귀'),
      ], edition: '2026-11-14'),
    );
    addTearDown(opened.close);
    blocks.glossary = opened;
    await tester.pumpWidget(screen(blocks, const AboutScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('시오리 보정'), 200);
    expect(find.text('시오리 보정'), findsOneWidget);
    expect(find.textContaining('2개'), findsWidgets);
    expect(find.textContaining('JMdict'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('2026-11-14'), 200);
    expect(find.textContaining('2026-11-14'), findsWidgets);
    expect(find.textContaining('CC BY-SA 4.0'), findsWidgets);
  });

  testWidgets('without the file: no card', (tester) async {
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

    expect(find.text('시오리 보정'), findsNothing);
  });
}
