import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori_core/shiori_core.dart';

import 'harness.dart';

/// Records what the cards ask to read aloud.
final class RecordingSpeech implements Speech {
  RecordingSpeech({this.isAvailable = true});

  @override
  final bool isAvailable;

  final requests = <SpeechRequest>[];

  @override
  Future<void> speak(SpeechRequest request) async => requests.add(request);

  @override
  Future<void> stop() async {}
}

/// Five made-up words with meanings apart, the first with an example, in
/// playlist 「모음」, oldest first. Returns them in that order.
Future<List<Word>> seedModeWords(TestBlocks blocks, {int count = 5}) async {
  const all = [
    ('語一', 'ごいち', '말 하나', PartOfSpeech.noun),
    ('語二', 'ごに', '말 둘', PartOfSpeech.noun),
    ('語三', 'ごさん', '말 셋', PartOfSpeech.noun),
    ('語四', 'ごよん', '말 넷', PartOfSpeech.verb),
    ('語五', 'ごご', '말 다섯', PartOfSpeech.verb),
  ];
  final service = LibraryService(library: blocks.library, clock: blocks.clock);
  final result = await service.addDraft(
    CaptureDraft(
      entries: [
        for (final (i, (head, reading, meaning, pos))
            in all.take(count).indexed)
          CapturedEntry(
            headword: head,
            readings: [reading],
            pos: pos,
            meaning: meaning,
            example: i == 0
                ? const Example(ja: '語一を書く。', ko: '말 하나를 쓴다.')
                : null,
          ),
      ],
    ),
    to: const NewPlaylist('모음'),
  );
  return blocks.library.words(playlistId: result.playlist.id);
}

/// The mode chip labelled [label] (홈 or 재생목록).
ChoiceChip modeChip(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label).first);

/// A card of [wordId] in [mode] whose review time has not come.
ReviewCard waitingCard(String wordId, StudyMode mode, int level) => ReviewCard(
  wordId: wordId,
  level: level,
  dueAt: testNow.add(Duration(days: level)),
  lastReviewedAt: testNow.subtract(const Duration(days: 1)),
  reviewCount: 1,
  mode: mode,
);

/// One 알고있음 press today in [mode].
ReviewLog knownToday(String wordId, StudyMode mode) => ReviewLog(
  wordId: wordId,
  answer: Answer.known,
  at: testNow.subtract(const Duration(minutes: 10)),
  levelBefore: 0,
  levelAfter: 4,
  retriesInSession: 0,
  mode: mode,
);
