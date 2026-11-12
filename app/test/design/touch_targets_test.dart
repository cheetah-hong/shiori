// U4: everything you can press on the main screens is at least 44 × 44 pt
// (iOS), and no color is written into a screen outside the tokens.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/design.dart';

void main() {
  for (final screen in designScreens) {
    testWidgets('$screen: 44 pt touch targets', (tester) async {
      final handle = tester.ensureSemantics();
      await openDesignScreen(tester, screen);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  }

  test('screens take colors only from the tokens', () {
    final offenders = <String>[];
    final pattern = RegExp(r'Color\(0x|Colors\.(?!transparent\b)\w+');
    for (final dir in ['lib/features', 'lib/shared']) {
      for (final file in Directory(dir).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (final (i, line) in lines.indexed) {
          if (line.trimLeft().startsWith('//')) continue;
          if (pattern.hasMatch(line)) offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
