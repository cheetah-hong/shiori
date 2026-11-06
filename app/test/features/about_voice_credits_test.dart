import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/about/about_screen.dart';

import '../support/harness.dart';

void main() {
  testWidgets('정보 credits the voice, the engine and the accent data', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(TestBlocks()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('발음'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('VOICEVOX:四国めたん'), findsWidgets);
    expect(find.textContaining('VOICEVOX core'), findsWidgets);
    expect(find.textContaining('ONNX Runtime'), findsWidgets);
    expect(find.textContaining('Open JTalk'), findsWidgets);
    expect(find.textContaining('Kanjium'), findsWidgets);
    expect(
      find.textContaining(
        'The pitch accent notation, verb particle data, phonetics, homonyms '
        'and other additions or modifications to EDICT, KANJIDIC or KRADFILE '
        'were provided by Uros O. through his free database.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('CC BY-SA 4.0'), findsWidgets);
  });
}
