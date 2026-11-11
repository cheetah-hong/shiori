// A filled (Tatoeba) example reads aloud when its text is tapped, as a page
// example does (study-modes' 예문 눌러 듣기).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/word_card.dart';
import 'package:shiori_core/shiori_core.dart';

void main() {
  testWidgets('tapping the filled sentence plays it once', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: WordCard(
            item: SessionItem(
              word: Word(
                id: 'w1',
                headword: '雪森',
                readings: const ['ゆきもり'],
                meaning: '눈숲',
                createdAt: DateTime(2026, 11, 12),
              ),
              before: null,
            ),
            maxLevel: 4,
            filledExample: const CardExample(
              ja: '雪森へ行きます。',
              en: 'I go to the snow wood.',
              origin: ExampleOrigin.tatoeba,
            ),
            onSpeakExample: () async => calls++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('example-ja')));
    await tester.pump();
    expect(calls, 1);
  });
}
