// The 정보 screen tells a build without the Wiktionary fallback (a debug
// build) from one whose fallback asset did not open.
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori/features/about/about_screen.dart';

import '../support/glossary.dart';
import '../support/harness.dart';

void main() {
  Future<void> pumpWith(WidgetTester tester, DictionaryProblem kind) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final opened = BundledGlossary.opened(
      openMiniKrdict(),
      testGlossaryEdition,
      wiktionaryProblem: 'wikt problem',
      wiktionaryProblemKind: kind,
    );
    addTearDown(opened.close);
    blocks.glossary = opened;
    await tester.pumpWidget(screen(blocks, const AboutScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('a damaged fallback asset: says it did not open', (tester) async {
    await pumpWith(tester, DictionaryProblem.damaged);
    final notice = find.textContaining('위키낱말사전 뜻 파일을 열지 못해');
    await tester.scrollUntilVisible(notice, 200);
    expect(notice, findsOneWidget);
    expect(find.textContaining('위키낱말사전 뜻이 들어 있지 않아요'), findsNothing);
  });

  testWidgets('no fallback asset in the build: says it is not there', (
    tester,
  ) async {
    await pumpWith(tester, DictionaryProblem.missing);
    final notice = find.textContaining('위키낱말사전 뜻이 들어 있지 않아요');
    await tester.scrollUntilVisible(notice, 200);
    expect(notice, findsOneWidget);
  });
}
