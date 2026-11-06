import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/pitch_line.dart';
import 'package:shiori/features/study/word_card.dart';
import 'package:shiori_core/shiori_core.dart';

Word _word({Example? example}) => Word(
  id: 'w1',
  headword: '箸',
  readings: const ['はし'],
  meaning: '젓가락',
  createdAt: DateTime(2026, 11, 6),
  pos: PartOfSpeech.noun,
  example: example,
);

const _example = Example(ja: '箸で食べます。', ko: '젓가락으로 먹습니다.');

Future<void> _pump(
  WidgetTester tester, {
  Word? word,
  Future<void> Function()? onSpeakWord,
  Future<void> Function()? onSpeakExample,
  PitchInfo? pitch,
  Future<int?> Function()? estimatePitch,
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
            onSpeakWord: onSpeakWord,
            onSpeakExample: onSpeakExample,
            pitch: pitch,
            estimatePitch: estimatePitch,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('T3 word button', () {
    testWidgets('no speech, no button', (tester) async {
      await _pump(tester);
      expect(find.byTooltip('발음 듣기'), findsNothing);
    });

    testWidgets('one tap asks for the word once', (tester) async {
      var calls = 0;
      await _pump(tester, onSpeakWord: () async => calls++);
      await tester.tap(find.byTooltip('발음 듣기'));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('tapping again after it started plays it again', (
      tester,
    ) async {
      var calls = 0;
      await _pump(tester, onSpeakWord: () async => calls++);
      await tester.tap(find.byTooltip('발음 듣기'));
      await tester.pump();
      await tester.tap(find.byTooltip('발음 듣기'));
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('while the sound is being made it says so and takes no taps', (
      tester,
    ) async {
      final pending = Completer<void>();
      var calls = 0;
      await _pump(
        tester,
        onSpeakWord: () {
          calls++;
          return pending.future;
        },
      );
      await tester.tap(find.byTooltip('발음 듣기'));
      await tester.pump();
      expect(find.byTooltip('불러오는 중'), findsOneWidget);
      await tester.tap(find.byTooltip('불러오는 중'));
      await tester.pump();
      expect(calls, 1);
      pending.complete();
      await tester.pump();
      expect(find.byTooltip('발음 듣기'), findsOneWidget);
    });

    testWidgets('a failure keeps the card and tells the learner', (
      tester,
    ) async {
      await _pump(
        tester,
        onSpeakWord: () async => throw const SpeechFailure('발음 데이터가 손상됐어요'),
      );
      await tester.tap(find.byTooltip('발음 듣기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('발음 데이터가 손상됐어요'), findsOneWidget);
      expect(find.text('箸'), findsOneWidget);
      expect(find.byTooltip('발음 듣기'), findsOneWidget);
    });

    testWidgets('an unexpected error also leaves the card working', (
      tester,
    ) async {
      await _pump(tester, onSpeakWord: () async => throw StateError('boom'));
      await tester.tap(find.byTooltip('발음 듣기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('소리를 재생하지 못했어요'), findsOneWidget);
      expect(find.byTooltip('발음 듣기'), findsOneWidget);
    });
  });

  group('T4 example button', () {
    testWidgets('shown only with an example and speech', (tester) async {
      await _pump(tester, onSpeakExample: () async {});
      expect(find.byTooltip('예문 듣기'), findsNothing);
      await _pump(tester, word: _word(example: _example));
      expect(find.byTooltip('예문 듣기'), findsNothing);
    });

    testWidgets('asks for the example, shows loading, then is ready', (
      tester,
    ) async {
      final pending = Completer<void>();
      var calls = 0;
      await _pump(
        tester,
        word: _word(example: _example),
        onSpeakWord: () async {},
        onSpeakExample: () {
          calls++;
          return pending.future;
        },
      );
      await tester.tap(find.byTooltip('예문 듣기'));
      await tester.pump();
      expect(calls, 1);
      expect(find.byTooltip('불러오는 중'), findsOneWidget);
      // The word button still works while the example loads.
      expect(find.byTooltip('발음 듣기'), findsOneWidget);
      pending.complete();
      await tester.pump();
      expect(find.byTooltip('예문 듣기'), findsOneWidget);
    });

    testWidgets('an example failure is told, the card stays', (tester) async {
      await _pump(
        tester,
        word: _word(example: _example),
        onSpeakExample: () async => throw const SpeechFailure('소리를 만들지 못했어요'),
      );
      await tester.tap(find.byTooltip('예문 듣기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('소리를 만들지 못했어요'), findsOneWidget);
      expect(find.byTooltip('예문 듣기'), findsOneWidget);
    });
  });

  group('T9 pitch line', () {
    const known = PitchInfo(morae: ['は', 'し'], accent: 1, estimated: false);
    const guessed = PitchInfo(morae: ['は', 'し'], accent: null, estimated: true);

    testWidgets('appears with the reading, not before', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, pitch: known);
      expect(find.bySemanticsLabel(RegExp('음 높이')), findsNothing);
      await tester.tap(find.text('읽기 보기'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('음 높이')), findsOneWidget);
      expect(find.byType(PitchLine), findsOneWidget);
      expect(find.text('추정'), findsNothing);
      semantics.dispose();
    });

    testWidgets('an estimated accent is marked 추정 and asked for once', (
      tester,
    ) async {
      var asked = 0;
      await _pump(
        tester,
        pitch: guessed,
        estimatePitch: () async {
          asked++;
          return 2;
        },
      );
      expect(asked, 0);
      await tester.tap(find.text('읽기 보기'));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(find.text('추정'), findsOneWidget);
      final line = tester.widget<PitchLine>(find.byType(PitchLine));
      expect(line.info.estimated, isTrue);
      // Closing and opening the reading again does not ask again.
      await tester.tap(find.text('읽기 가리기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('읽기 보기'));
      await tester.pumpAndSettle();
      expect(asked, 1);
    });

    testWidgets('an estimate that fails still says 추정, no line', (
      tester,
    ) async {
      await _pump(tester, pitch: guessed, estimatePitch: () async => null);
      await tester.tap(find.text('읽기 보기'));
      await tester.pumpAndSettle();
      expect(find.text('추정'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      final line = tester.widget<PitchLine>(find.byType(PitchLine));
      expect(line.info.accent, isNull);
    });
  });

  group('PitchInfo', () {
    test('highs follow the accent with a particle slot', () {
      const info = PitchInfo(morae: ['は', 'し'], accent: 0, estimated: false);
      expect(info.highs, [false, true, true]);
      const none = PitchInfo(morae: ['は', 'し'], accent: null, estimated: true);
      expect(none.highs, isNull);
    });
  });
}
