// D5: the 정보 screen carries everything the two data licences ask for —
// JMdict (the EDRDG notice, the JMdict date, the build day, the variant, the
// source sha256, that the data is a converted copy under CC BY-SA 4.0) and
// the Korean glossary (source, publisher, edition, licence, "가공").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/features/about/about_screen.dart';

import '../support/dictionary.dart';
import '../support/glossary.dart';
import '../support/harness.dart';

const _ccBySa40 = 'https://creativecommons.org/licenses/by-sa/4.0/';
const _ccBySa20Kr = 'https://creativecommons.org/licenses/by-sa/2.0/kr/';
const _krdictCredit = '한국어기초사전, 국립국어원, CC BY-SA 2.0 KR, 2026-10-19판을 가공함';

void main() {
  testWidgets('both dictionaries: every credit, edition and licence', (
    tester,
  ) async {
    usePhoneSize(tester);
    final dictionary = BundledDictionary.opened(openMiniJmdict(), testEdition);
    addTearDown(dictionary.close);
    final glossary = BundledGlossary.opened(
      openMiniKrdict(),
      testGlossaryEdition,
    );
    addTearDown(glossary.close);
    final blocks = TestBlocks()
      ..dictionary = dictionary
      ..glossary = glossary;
    await tester.pumpWidget(screen(blocks, const AboutScreen()));
    await tester.pumpAndSettle();

    Future<void> sees(Finder finder) async {
      for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
      expect(finder, findsWidgets);
    }

    // JMdict
    await sees(
      find.textContaining('This application uses the JMdict dictionary files'),
    );
    await sees(find.textContaining('변환'));
    await sees(find.text(_ccBySa40));
    await sees(find.text(testEdition.jmdictCreated));
    await sees(find.text(testEdition.builtOn));
    await sees(find.textContaining(testEdition.variant));
    await sees(find.text(testEdition.sourceSha256));
    // The Korean glossary
    await sees(find.text(_krdictCredit));
    await sees(find.text(_ccBySa20Kr));
    await sees(find.text(testGlossaryEdition.sources.single.edition));
    await sees(find.textContaining(testGlossaryEdition.variant));
  });
}
