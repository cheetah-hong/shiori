// E11: the data the word extractor ships with is credited on the 정보 screen
// and on the licences page: JL's deconjugation rules (Apache-2.0) and the
// Unicode Han Database (Unicode License v3).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/about/about_screen.dart';

import '../support/harness.dart';

void main() {
  testWidgets('정보 shows JL (Apache-2.0) and Unihan (Unicode License)', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), const AboutScreen()));
    await tester.pumpAndSettle();

    final jl = find.textContaining('JL');
    await tester.scrollUntilVisible(
      jl,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(jl, findsWidgets);
    expect(find.textContaining('Apache License 2.0'), findsWidgets);
    expect(find.textContaining('Unihan'), findsWidgets);
    expect(find.textContaining('Unicode License'), findsWidgets);
  });

  test('both are listed among the licences', () async {
    registerExtractorLicenses();
    final entries = await LicenseRegistry.licenses.toList();

    String textOf(String package) => entries
        .where((e) => e.packages.contains(package))
        .expand((e) => e.paragraphs)
        .map((p) => p.text)
        .join('\n');

    final jl = textOf('JL deconjugation rules');
    expect(jl, contains('Apache License'));
    expect(jl, contains('https://github.com/rampaa/JL'));
    expect(jl, contains('Nazeka'));
    final unihan = textOf('Unihan');
    expect(unihan, contains('UNICODE LICENSE V3'));
    expect(unihan, contains('Unicode, Inc.'));
  });
}
