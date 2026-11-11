// 재생목록: each word shows four small memory meters (뜻·일·듣·객), and
// 처음부터 다시 학습 / 모든 단어 처음부터 take every mode's cards. Made-up
// words.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/features/settings/settings_screen.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';
import '../support/study_modes.dart';

void main() {
  /// The meters of [word]'s row, left to right.
  List<int> levels(WidgetTester tester, Word word) => [
    for (final m in tester.widgetList<MemoryMeter>(
      find.descendant(
        of: find.byKey(ValueKey('word-${word.id}')),
        matching: find.byType(MemoryMeter),
      ),
    ))
      m.level,
  ];

  Future<(TestBlocks, List<Word>, String)> seeded() async {
    final blocks = TestBlocks();
    final words = await seedModeWords(blocks);
    final listId = (await blocks.library.playlists()).single.id;
    return (blocks, words, listId);
  }

  testWidgets('four meters per word: 뜻, 일, 듣, 객', (tester) async {
    usePhoneSize(tester);
    final (blocks, words, listId) = await seeded();
    await blocks.reviews.saveCard(
      waitingCard(words[0].id, StudyMode.meaning, 2),
    );
    await blocks.reviews.saveCard(
      waitingCard(words[0].id, StudyMode.choice, 4),
    );
    await blocks.reviews.saveCard(
      waitingCard(words[1].id, StudyMode.listening, 1),
    );
    await tester.pumpWidget(screen(blocks, PlaylistScreen(playlistId: listId)));
    await tester.pumpAndSettle();

    expect(levels(tester, words[0]), [2, 0, 0, 4]);
    expect(levels(tester, words[1]), [0, 0, 1, 0]);
    expect(levels(tester, words[2]), [0, 0, 0, 0]);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('word-${words[0].id}')),
        matching: find.bySemanticsLabel(
          '기억 단계: 뜻 맞히기 2단계, 일본어 떠올리기 새 단어, '
          '듣고 맞히기 새 단어, 객관식 4단계',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('처음부터 다시 학습 is offered for a word studied in any '
      'mode, and takes every mode', (tester) async {
    usePhoneSize(tester);
    final (blocks, words, listId) = await seeded();
    final w = words[1];
    await blocks.reviews.saveCard(waitingCard(w.id, StudyMode.recall, 3));
    await blocks.reviews.saveCard(waitingCard(w.id, StudyMode.choice, 2));
    await tester.pumpWidget(screen(blocks, PlaylistScreen(playlistId: listId)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('${w.headword} 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('처음부터 다시 학습'));
    await tester.pumpAndSettle();

    for (final mode in StudyMode.values) {
      expect(await blocks.reviews.card(w.id, mode: mode), isNull);
    }
    expect(levels(tester, w), [0, 0, 0, 0]);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(levels(tester, w), [0, 3, 0, 2]);
  });

  testWidgets('a word new in every mode has no 처음부터 item', (tester) async {
    usePhoneSize(tester);
    final (blocks, words, listId) = await seeded();
    await tester.pumpWidget(screen(blocks, PlaylistScreen(playlistId: listId)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('${words[0].headword} 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('처음부터 다시 학습'), findsNothing);
  });

  testWidgets('모든 단어 처음부터 counts words studied in any mode and '
      'takes every mode', (tester) async {
    usePhoneSize(tester);
    final (blocks, words, _) = await seeded();
    await blocks.reviews.saveCard(
      waitingCard(words[0].id, StudyMode.recall, 2),
    );
    await blocks.reviews.saveCard(
      waitingCard(words[0].id, StudyMode.listening, 2),
    );
    await blocks.reviews.saveCard(
      waitingCard(words[3].id, StudyMode.choice, 1),
    );
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('모든 단어 처음부터 다시 학습'));
    await tester.pumpAndSettle();
    expect(find.textContaining('학습한 단어 2개'), findsOneWidget);
    await tester.tap(find.text('처음부터'));
    await tester.pumpAndSettle();

    // The words made new, not the cards removed (3).
    expect(find.text('단어 2개를 새 단어로 돌렸어요'), findsOneWidget);
    for (final mode in StudyMode.values) {
      expect(await blocks.reviews.cards(mode: mode), isEmpty);
    }
  });
}
