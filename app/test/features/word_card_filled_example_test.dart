// X5: a card whose word has no page example shows the Tatoeba sentence in
// the example's place: Korean, else English in italics, else no translation
// line, and a small 「예문: Tatoeba」 under it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/word_card.dart';
import 'package:shiori_core/shiori_core.dart';

Word _word({Example? example}) => Word(
  id: 'w1',
  headword: '雪森',
  readings: const ['ゆきもり'],
  meaning: '눈숲',
  createdAt: DateTime(2026, 11, 12),
  example: example,
);

Future<void> _pump(
  WidgetTester tester, {
  Word? word,
  CardExample? filled,
  Future<void> Function()? onSpeakExample,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: WordCard(
            item: SessionItem(word: word ?? _word(), before: null),
            maxLevel: 4,
            filledExample: filled,
            onSpeakExample: onSpeakExample,
          ),
        ),
      ),
    ),
  );
}

/// Text in the card, also inside rich text (the example highlights its word).
Finder _text(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText() == text,
);

void main() {
  testWidgets('Korean translation under the sentence, and the source', (
    tester,
  ) async {
    await _pump(
      tester,
      filled: const CardExample(
        ja: '雪森へ行きます。',
        ko: '눈숲에 갑니다.',
        origin: ExampleOrigin.tatoeba,
      ),
    );
    expect(_text('雪森へ行きます。'), findsOneWidget);
    expect(find.text('눈숲에 갑니다.'), findsOneWidget);
    expect(find.text('예문: Tatoeba'), findsOneWidget);
    expect(find.textContaining('영어 번역'), findsNothing);
    final ko = tester.widget<Text>(find.text('눈숲에 갑니다.'));
    expect(ko.style?.fontStyle, isNot(FontStyle.italic));
  });

  testWidgets('English in italics when there is no Korean, and it says so', (
    tester,
  ) async {
    await _pump(
      tester,
      filled: const CardExample(
        ja: '雪森へ行きます。',
        en: 'I go to the snow wood.',
        origin: ExampleOrigin.tatoeba,
      ),
    );
    final en = tester.widget<Text>(find.text('I go to the snow wood.'));
    expect(en.style?.fontStyle, FontStyle.italic);
    expect(find.text('예문: Tatoeba · 영어 번역'), findsOneWidget);
  });

  testWidgets('no translation: no translation line', (tester) async {
    await _pump(
      tester,
      filled: const CardExample(ja: '雪森へ行きます。', origin: ExampleOrigin.tatoeba),
    );
    expect(_text('雪森へ行きます。'), findsOneWidget);
    expect(find.text('번역 가림'), findsNothing);
    expect(find.text('예문: Tatoeba'), findsOneWidget);
  });

  testWidgets('the page example comes first, with no source line', (
    tester,
  ) async {
    await _pump(
      tester,
      word: _word(
        example: const Example(ja: '雪森が白い。', ko: '눈숲이 하얗다.'),
      ),
      filled: const CardExample(
        ja: '雪森へ行きます。',
        ko: '눈숲에 갑니다.',
        origin: ExampleOrigin.tatoeba,
      ),
    );
    expect(_text('雪森が白い。'), findsOneWidget);
    expect(_text('雪森へ行きます。'), findsNothing);
    expect(find.textContaining('예문: Tatoeba'), findsNothing);
  });

  testWidgets('no example at all: no example, no button', (tester) async {
    await _pump(tester, onSpeakExample: () async {});
    expect(find.textContaining('예문'), findsNothing);
    expect(find.byTooltip('예문 듣기'), findsNothing);
  });

  testWidgets('the filled sentence has the speaker button', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      filled: const CardExample(ja: '雪森へ行きます。', origin: ExampleOrigin.tatoeba),
      onSpeakExample: () async => calls++,
    );
    await tester.tap(find.byTooltip('예문 듣기'));
    await tester.pump();
    expect(calls, 1);
  });
}
