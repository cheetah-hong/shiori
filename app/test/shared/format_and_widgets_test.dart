import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/entry_editor_sheet.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/widgets.dart';

void main() {
  group('format', () {
    test('interval labels', () {
      expect(intervalLabel(const Duration(minutes: 30)), '30분 후');
      expect(intervalLabel(const Duration(seconds: 10)), '1분 후');
      expect(intervalLabel(const Duration(hours: 5)), '5시간 후');
      expect(intervalLabel(const Duration(days: 21)), '21일 후');
    });

    test('dates, elapsed time and readings', () {
      expect(dateHeading(DateTime(2026, 11, 5)), '11월 5일 목요일');
      expect(elapsedLabel(const Duration(seconds: 42)), '42초');
      expect(elapsedLabel(const Duration(seconds: -5)), '0초');
      expect(elapsedLabel(const Duration(minutes: 2, seconds: 17)), '2분 17초');
      expect(readingsLabel(const ['あした', 'あす']), 'あした / あす');
      expect(readingsLabel(const []), '–');
    });

    test('reading input accepts the usual separators', () {
      expect(parseReadingInput('あした / あす'), ['あした', 'あす']);
      expect(parseReadingInput('こう・く'), ['こう', 'く']);
      expect(parseReadingInput('  '), isEmpty);
    });
  });

  group('HighlightedSentence', () {
    test('falls back to the kanji stem for conjugated forms', () {
      expect(HighlightedSentence.stemOf('揺れる'), '揺');
      expect(HighlightedSentence.stemOf('乗り換える'), '乗り換');
      expect(
        HighlightedSentence.stemOf('もう'),
        'もう',
        reason: 'kana words stay whole',
      );
    });

    testWidgets('marks the word inside the example', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(
            body: HighlightedSentence(
              sentence: 'バスがひどく揺れた。',
              focus: '揺れる',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
      final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      expect(rich.children!.map((s) => (s as TextSpan).text), [
        'バスがひどく',
        '揺',
        'れた。',
      ]);
    });
  });

  testWidgets('dark theme carries the dark tokens', (tester) async {
    late ShioriTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Builder(
          builder: (context) {
            tokens = context.tokens;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tokens.paper, ShioriTokens.dark.paper);
    expect(
      ShioriTokens.light.lerp(ShioriTokens.dark, 1).ink,
      ShioriTokens.dark.ink,
    );
  });
}
