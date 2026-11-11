// X5: on the study screen a word with no page example shows the sentence of
// its dictionary entry, and the example button speaks that sentence through
// the example path.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

import '../support/harness.dart';

final class _FakeSpeech implements Speech {
  final requests = <SpeechRequest>[];

  @override
  bool get isAvailable => true;

  @override
  Future<void> speak(SpeechRequest request) async => requests.add(request);

  @override
  Future<void> stop() async {}
}

/// One sentence per entry: the headword followed by の例文です。, in English.
final class _Examples implements ExampleSentences {
  _Examples(this.headwords);

  final Map<int, String> headwords;

  @override
  Future<List<StoredExample>> lookup(Iterable<int> entryIds) async => [
    for (final id in entryIds)
      if (headwords[id] case final h?)
        StoredExample(
          entryId: id,
          reading: '',
          sentenceId: id,
          ja: '$hの例文です。',
          en: 'An example of $h.',
        ),
  ];
}

void main() {
  testWidgets('the card shows the filled sentence and speaks it', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s140');
    // A dictionary entry for every word of the page.
    final vocab =
        ((jsonDecode(File(syntheticAnswers).readAsStringSync()) as Map)['pages']
                    as List)
                .cast<Map<String, Object?>>()
                .singleWhere((p) => p['fixture'] == 's140')['vocab']!
            as List;
    final words = [
      for (final (i, v) in vocab.cast<Map<String, Object?>>().indexed)
        LexiconWord(
          id: 9500000 + i,
          kanji: [v['headword']! as String],
          readings: [for (final r in v['readings']! as List) r as String],
        ),
    ];
    final speech = _FakeSpeech();
    await tester.pumpWidget(
      app(
        blocks,
        extra: [
          studySettingsProvider.overrideWithValue(
            const StudySettings(dailyGoal: 3),
          ),
          speechProvider.overrideWithValue(speech),
          accentTableProvider.overrideWith((ref) async => AccentTable.empty),
          lexiconProvider.overrideWithValue(InMemoryLexicon(words)),
          exampleSentencesProvider.overrideWithValue(
            _Examples({for (final w in words) w.id: w.kanji.single}),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 학습 시작 · 3장'));
    await tester.pumpAndSettle();

    expect(find.text('예문: Tatoeba · 영어 번역'), findsOneWidget);
    await tester.tap(find.byTooltip('예문 듣기'));
    await tester.pumpAndSettle();
    final request = speech.requests.single as SentenceSpeech;
    expect(request.text, '${request.word.headword}の例文です。');
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == request.text,
      ),
      findsOneWidget,
    );
    expect(
      find.text('An example of ${request.word.headword}.'),
      findsOneWidget,
    );
  });
}
