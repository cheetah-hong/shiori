// The study card of each mode: 일본어 떠올리기 hides the Japanese until asked,
// 객관식 and 듣고 맞히기 ask for one meaning out of four (a pick is stored at
// once, the result stays until 다음), 듣고 맞히기 plays the word by itself
// once, and the example sentence reads aloud when its text is tapped.
// Made-up words.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

import '../support/harness.dart';
import '../support/study_modes.dart';

void main() {
  late RecordingSpeech speech;

  List<Override> blocksWith(Speech s) => [
    speechProvider.overrideWithValue(s),
    accentTableProvider.overrideWith((ref) async => AccentTable.empty),
  ];

  /// Seeds the five words, picks [mode] and opens today's study.
  Future<(TestBlocks, List<Word>)> open(
    WidgetTester tester,
    StudyMode mode, {
    Speech? using,
  }) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await seedModeWords(blocks);
    await blocks.preferences.save(StudyPreferences(mode: mode));
    await tester.pumpWidget(app(blocks, extra: blocksWith(using ?? speech)));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
    return (blocks, words);
  }

  Finder exampleJa() => find.textContaining('語一を書く', findRichText: true);

  setUp(() => speech = RecordingSpeech());

  group('일본어 떠올리기', () {
    testWidgets('the front shows the meaning, not the Japanese', (
      tester,
    ) async {
      await open(tester, StudyMode.recall);

      expect(find.text('말 하나'), findsOneWidget);
      expect(find.text('말 하나를 쓴다.'), findsOneWidget);
      expect(find.text('語一'), findsNothing);
      expect(find.textContaining('ごいち'), findsNothing);
      expect(exampleJa(), findsNothing);
      expect(find.byTooltip('발음 듣기'), findsNothing);
    });

    testWidgets('일본어 보기 shows the word, its reading and the example', (
      tester,
    ) async {
      final (blocks, words) = await open(tester, StudyMode.recall);

      await tester.tap(find.text('일본어 보기'));
      await tester.pumpAndSettle();

      expect(find.text('語一'), findsOneWidget);
      expect(find.textContaining('ごいち'), findsOneWidget);
      expect(exampleJa(), findsOneWidget);

      await tester.tap(find.text('알고있음'));
      await tester.pumpAndSettle();
      final recall = await blocks.reviews.card(
        words[0].id,
        mode: StudyMode.recall,
      );
      expect(recall?.level, 4);
      expect(await blocks.reviews.card(words[0].id), isNull);
    });
  });

  group('객관식', () {
    testWidgets('four meanings to pick from, no self-graded buttons', (
      tester,
    ) async {
      final (_, words) = await open(tester, StudyMode.choice);

      expect(find.text('객관식'), findsOneWidget);
      expect(find.text('語一'), findsOneWidget);
      expect(find.byKey(ValueKey('option-${words[0].id}')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('option-'),
        ),
        findsNWidgets(4),
      );
      expect(find.text('알고있음'), findsNothing);
      expect(find.text('다시 학습'), findsNothing);
      expect(find.text('말 하나를 쓴다.'), findsNothing, reason: 'the answer');
    });

    testWidgets('a right pick is stored at once as 알고있음; 다음 moves on', (
      tester,
    ) async {
      final (blocks, words) = await open(tester, StudyMode.choice);

      await tester.tap(find.byKey(ValueKey('option-${words[0].id}')));
      await tester.pumpAndSettle();

      expect(find.text('맞았어요'), findsOneWidget);
      expect(find.text('語一'), findsOneWidget, reason: 'the card stays');
      final saved = await blocks.reviews.card(
        words[0].id,
        mode: StudyMode.choice,
      );
      expect(
        (saved?.level, saved?.dueAt),
        (4, testNow.add(const Duration(days: 21))),
      );

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('語二'), findsOneWidget);
      expect(find.text('맞았어요'), findsNothing);
    });

    testWidgets('a wrong pick is 다시 학습 and shows the right answer', (
      tester,
    ) async {
      final (blocks, words) = await open(tester, StudyMode.choice);
      final wrong = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('option-') &&
            (w.key! as ValueKey<String>).value != 'option-${words[0].id}',
      );

      await tester.tap(wrong.first);
      await tester.pumpAndSettle();

      expect(find.text('틀렸어요'), findsOneWidget);
      expect(find.text('정답'), findsOneWidget);
      final saved = await blocks.reviews.card(
        words[0].id,
        mode: StudyMode.choice,
      );
      expect((saved?.level, saved?.dueAt), (1, testNow));
      final logs = await blocks.reviews.logs(mode: StudyMode.choice);
      expect(logs.single.answer, Answer.retry);

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('語二'), findsOneWidget);
    });

    testWidgets('the last pick shows its result before 오늘 학습 끝', (
      tester,
    ) async {
      final (_, words) = await open(tester, StudyMode.choice);
      for (final w in words) {
        await tester.tap(find.byKey(ValueKey('option-${w.id}')));
        await tester.pumpAndSettle();
        expect(find.text('맞았어요'), findsOneWidget, reason: w.headword);
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      expect(find.text('오늘 학습 끝'), findsOneWidget);
    });
  });

  group('듣고 맞히기', () {
    const first = WordSpeech(
      headword: '語一',
      reading: 'ごいち',
      pos: PartOfSpeech.noun,
    );

    testWidgets('the word plays once by itself; nothing shows it', (
      tester,
    ) async {
      await open(tester, StudyMode.listening);

      expect(speech.requests, [first]);
      expect(find.text('듣고 맞히기'), findsOneWidget);
      expect(find.text('語一'), findsNothing);
      expect(find.textContaining('ごいち'), findsNothing);
      expect(exampleJa(), findsNothing);
      expect(find.text('알고있음'), findsNothing);
    });

    testWidgets('다시 듣기 plays the same sound again', (tester) async {
      await open(tester, StudyMode.listening);

      await tester.tap(find.byTooltip('다시 듣기'));
      await tester.pumpAndSettle();
      expect(speech.requests, [first, first]);
    });

    testWidgets('after a pick the word and its reading show; the next card '
        'plays by itself', (tester) async {
      final (blocks, words) = await open(tester, StudyMode.listening);

      await tester.tap(find.byKey(ValueKey('option-${words[0].id}')));
      await tester.pumpAndSettle();
      expect(find.text('맞았어요'), findsOneWidget);
      expect(find.text('語一'), findsOneWidget);
      expect(find.textContaining('ごいち'), findsOneWidget);
      final saved = await blocks.reviews.card(
        words[0].id,
        mode: StudyMode.listening,
      );
      expect(saved?.level, 4);
      expect(speech.requests, hasLength(1), reason: 'no replay on a pick');

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(speech.requests, hasLength(2));
      expect((speech.requests.last as WordSpeech).headword, '語二');
    });
  });

  group('예문 눌러 듣기', () {
    testWidgets('tapping the example asks for the same sound as its '
        'speaker', (tester) async {
      await open(tester, StudyMode.meaning);

      await tester.tap(find.byTooltip('예문 듣기'));
      await tester.pumpAndSettle();
      await tester.tap(exampleJa());
      await tester.pumpAndSettle();

      expect(speech.requests, hasLength(2));
      expect(speech.requests.first, isA<SentenceSpeech>());
      expect(speech.requests.last, speech.requests.first);
    });

    testWidgets('a word without an example has nothing to tap', (tester) async {
      await open(tester, StudyMode.meaning);
      await tester.tap(find.text('알고있음'));
      await tester.pumpAndSettle();

      expect(find.text('語二'), findsOneWidget);
      expect(find.byKey(const ValueKey('example-ja')), findsNothing);
      expect(speech.requests, isEmpty);
    });

    testWidgets('without speech, tapping the example does nothing', (
      tester,
    ) async {
      final silent = RecordingSpeech(isAvailable: false);
      await open(tester, StudyMode.meaning, using: silent);

      await tester.tap(exampleJa(), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(silent.requests, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
