// Hidden words in the textbook list and on the home shelf: hidden by
// default, 「숨긴 단어 n개 보기」 to open them and show one again, and hiding a
// word from the list. Synthetic sample pages only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/textbook_screen.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

LibraryService _library(TestBlocks blocks) =>
    LibraryService(library: blocks.library, clock: blocks.clock);

void main() {
  testWidgets('hidden words are left out until opened, and can be shown '
      'again', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final textbook = await blocks.seedPage('s010');
    final words = await blocks.library.words();
    final target = words[2];
    await _library(blocks).hideWords([target.id]);

    await tester.pumpWidget(
      screen(blocks, TextbookScreen(textbookId: textbook.id)),
    );
    await tester.pumpAndSettle();
    expect(find.text(words[0].headword), findsOneWidget);
    expect(find.text(target.headword), findsNothing);
    expect(find.text('${words.length - 1}'), findsOneWidget, reason: '단어 수');
    expect(find.text('${words.length - 1}개'), findsOneWidget, reason: 'DAY');

    final toggle = find.text(HideLabels.showHidden(1));
    await tester.scrollUntilVisible(toggle, 300);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text(target.headword), findsOneWidget);
    expect(find.text(HideLabels.collapseHidden), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, HideLabels.restore));
    await tester.pumpAndSettle();
    expect((await blocks.library.word(target.id))?.isHidden, isFalse);
    expect(find.text(HideLabels.restored(target.headword)), findsOneWidget);
    expect(find.textContaining('숨긴 단어'), findsNothing);
    await tester.scrollUntilVisible(find.text(target.headword), -300);
    expect(find.text(target.headword), findsOneWidget);
    expect(find.text('${words.length}개'), findsOneWidget);
  });

  testWidgets('a word can be hidden from the list, with 되돌리기', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final textbook = await blocks.seedPage('s010');
    final words = await blocks.library.words();
    final target = words[1];

    await tester.pumpWidget(
      screen(blocks, TextbookScreen(textbookId: textbook.id)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('숨긴 단어'), findsNothing);

    await tester.tap(find.byTooltip(HideLabels.hideWord(target.headword)));
    await tester.pumpAndSettle();
    expect(find.text(target.headword), findsNothing);
    expect((await blocks.library.word(target.id))?.isHidden, isTrue);
    expect(find.text(HideLabels.hidden(target.headword)), findsOneWidget);
    await tester.scrollUntilVisible(find.text(HideLabels.showHidden(1)), 300);
    expect(find.text(HideLabels.showHidden(1)), findsOneWidget);

    await tester.tap(find.text(HideLabels.undo));
    await tester.pumpAndSettle();
    expect((await blocks.library.word(target.id))?.isHidden, isFalse);
    expect(find.textContaining('숨긴 단어'), findsNothing);
  });

  testWidgets('the home shelf counts shown words and says how many are '
      'hidden', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s010');
    final words = await blocks.library.words();
    await _library(blocks).hideWords([
      for (final i in [0, 3, 5, 7]) words[i].id,
    ]);

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    final shown = words.length - 4;
    expect(shown, lessThan(10), reason: 'fewer than the daily goal');
    expect(
      find.text('DAY 01 · 단어 $shown개 · ${HideLabels.hiddenCount(4)}'),
      findsOneWidget,
    );
    expect(find.text('단어 $shown개'), findsOneWidget, reason: 'shelf total');
    expect(
      find.text('오늘 학습 시작 · $shown장'),
      findsOneWidget,
      reason: 'hidden words are not new words to study',
    );
  });
}
