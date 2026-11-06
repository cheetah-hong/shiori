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

void main() {
  testWidgets('the study card asks the speech block for its word, once', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s140');
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
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 학습 시작 · 3장'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('발음 듣기'));
    await tester.pumpAndSettle();
    expect(speech.requests, hasLength(1));
    final word = speech.requests.single as WordSpeech;
    expect(find.text(word.headword), findsOneWidget);
    expect(word.isEstimated, isTrue);
  });

  testWidgets('without speech the study card has no speaker buttons', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s140');
    await tester.pumpWidget(
      app(
        blocks,
        extra: [
          speechProvider.overrideWithValue(const SilentSpeech()),
          accentTableProvider.overrideWith((ref) async => AccentTable.empty),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('발음 듣기'), findsNothing);
    expect(find.byTooltip('예문 듣기'), findsNothing);
  });
}
