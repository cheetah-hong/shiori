// X5: the 정보 screen credits the Tatoeba example sentences in a card of
// their own (source, tatoeba.org, CC BY 2.0 FR), and the licence page lists
// them.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_examples.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori/features/about/about_screen.dart';
import 'package:shiori/features/about/examples_card.dart';

import '../support/examples.dart';
import '../support/harness.dart';

const _licenseUrl = 'https://creativecommons.org/licenses/by/2.0/fr/';

void main() {
  testWidgets('with the sentences: their card, the credit, the export and the '
      'licence', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final opened = BundledExamples.opened(
      openMiniExamples(),
      testExamplesEdition,
    );
    addTearDown(opened.close);
    blocks.examples = opened;
    await tester.pumpWidget(screen(blocks, const AboutScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Tatoeba'), 200);
    expect(find.text('Tatoeba'), findsOneWidget);
    expect(find.text(testExamplesEdition.attribution), findsOneWidget);
    await tester.scrollUntilVisible(find.text(_licenseUrl), 200);
    expect(find.text(_licenseUrl), findsOneWidget);
    await tester.scrollUntilVisible(find.text('https://tatoeba.org'), 200);
    expect(find.text('https://tatoeba.org'), findsOneWidget);
    expect(find.textContaining('CC BY 2.0 FR'), findsWidgets);
    expect(find.textContaining('2026-11-12'), findsWidgets);
  });

  testWidgets('without the sentences the card says so', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(screen(blocks, const AboutScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Tatoeba 예문이 들어 있지 않아요'),
      200,
    );
    expect(find.textContaining('Tatoeba 예문이 들어 있지 않아요'), findsOneWidget);
  });

  testWidgets('a damaged file is told apart', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks()
      ..examples = const BundledExamples.unavailable(
        'bad',
        problemKind: DictionaryProblem.damaged,
      );
    await tester.pumpWidget(screen(blocks, const AboutScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('예문 파일을 열지 못해'), 200);
    expect(find.textContaining('예문 파일을 열지 못해'), findsOneWidget);
  });

  test('Tatoeba is listed among the licences', () async {
    registerExampleLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final text = entries
        .where((e) => e.packages.contains('Tatoeba'))
        .expand((e) => e.paragraphs)
        .map((p) => p.text)
        .join('\n');
    expect(text, contains('https://tatoeba.org'));
    expect(text, contains('CC BY 2.0 FR'));
    expect(text, contains(_licenseUrl));
  });
}
