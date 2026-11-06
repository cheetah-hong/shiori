// D11: the review screen's head without page info (no DAY, title or page is
// read from the page) and adding into a new playlist. Made-up words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

CapturedEntry _word(String headword, String reading, String meaning) =>
    CapturedEntry(
      headword: headword,
      readings: [reading],
      pos: PartOfSpeech.noun,
      meaning: meaning,
      evidence: const EntryEvidence(
        origin: WordOrigin.wordList,
        fields: {EntryField.headword: FieldEvidence(source: FieldSource.photo)},
      ),
    );

final _draft = CaptureDraft(
  recognitionTime: const Duration(milliseconds: 1200),
  entries: [
    _word('雨', 'あめ', '비'),
    _word('雪', 'ゆき', '눈'),
    _word('風', 'かぜ', '바람'),
  ],
);

void main() {
  testWidgets('the head counts the words and names the source and the time', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      screen(TestBlocks(), ReviewScreen(draft: _draft, sourceLabel: '샘플 10쪽')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-heading')), findsOneWidget);
    expect(find.text('단어 3개'), findsOneWidget);
    expect(find.text('샘플 10쪽 · 판독 1.2초'), findsOneWidget);
    expect(find.textContaining('DAY'), findsNothing);
    expect(find.text('쪽 정보 없음'), findsNothing);
    expect(find.text('쪽 정보'), findsNothing);
    expect(find.textContaining('범용 추출'), findsNothing);
    expect(find.textContaining('칸 위치'), findsNothing);
  });

  testWidgets('with no playlist yet the words go to a new 「내 단어장」, in '
      'the photo\'s order', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(screen(blocks, ReviewScreen(draft: _draft)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('단어 3개 추가'));
    await tester.pumpAndSettle();
    expect(find.text('어느 재생목록에 추가할까요?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(TextField, '재생목록 이름'),
        matching: find.text('내 단어장'),
      ),
      findsOneWidget,
      reason: 'the new-playlist form is open with the default name',
    );
    await tester.tap(find.text('만들고 추가'));
    // The screen is the only route here: the add spinner stays, so pump a
    // few frames instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("'내 단어장'에 단어 3개 추가"), findsOneWidget);

    final playlist = (await blocks.library.playlists()).single;
    expect(playlist.name, '내 단어장');
    final words = await blocks.library.words(playlistId: playlist.id);
    expect(words.map((w) => w.headword), ['雨', '雪', '風']);
  });
}
