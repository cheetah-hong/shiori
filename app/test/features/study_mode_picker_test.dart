// 홈 (the 학습 방식 row and its menu) and 재생목록 (four chips): the counts,
// 오늘 n개 외움 and the study button follow the mode picked, which is
// remembered. A mode that cannot be studied says why instead of being
// picked. Made-up words.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

import '../support/harness.dart';
import '../support/study_modes.dart';

void main() {
  const labels = ['뜻 맞히기', '일본어 떠올리기', '듣고 맞히기', '객관식'];

  List<Override> withSpeech(Speech speech) => [
    speechProvider.overrideWithValue(speech),
    accentTableProvider.overrideWith((ref) async => AccentTable.empty),
  ];

  /// 홈's 학습 방식 row says [label] is the mode in use.
  void showsOnHome(String label) => expect(
    find.bySemanticsLabel('학습 방식, $label'),
    findsOneWidget,
    reason: label,
  );

  /// Opens 홈's 학습 방식 menu and picks [label].
  Future<void> pickOnHome(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^학습 방식')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('four modes in the menu, 뜻 맞히기 picked at first', (tester) async {
    final handle = tester.ensureSemantics();
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedModeWords(blocks);
    await tester.pumpWidget(app(blocks, extra: withSpeech(RecordingSpeech())));
    await tester.pumpAndSettle();

    showsOnHome('뜻 맞히기');
    await tester.tap(find.bySemanticsLabel(RegExp('^학습 방식')));
    await tester.pumpAndSettle();
    for (final label in labels) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    handle.dispose();
  });

  testWidgets('picking a mode shows its counts and is remembered', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await seedModeWords(blocks);
    for (final w in words.take(2)) {
      await blocks.reviews.saveCard(waitingCard(w.id, StudyMode.recall, 2));
    }
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    // The day sheet's memo: 새 단어 5 in 뜻 맞히기.
    expect(find.text('5개'), findsOneWidget);

    await pickOnHome(tester, '일본어 떠올리기');

    showsOnHome('일본어 떠올리기');
    expect(find.text('3개'), findsOneWidget, reason: '2 waiting in recall');
    expect((await blocks.preferences.load()).mode, StudyMode.recall);

    // A new start of the app keeps the mode.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    showsOnHome('일본어 떠올리기');
    expect(find.text('3개'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('오늘 n개 외움 counts the mode picked and names it', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await seedModeWords(blocks);
    await blocks.reviews.addLog(knownToday(words[0].id, StudyMode.meaning));
    await blocks.reviews.addLog(knownToday(words[1].id, StudyMode.choice));
    await blocks.reviews.addLog(knownToday(words[2].id, StudyMode.choice));
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    expect(find.text('오늘 1개 외움'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('known-today-mode'))).data,
      '뜻 맞히기',
    );

    await pickOnHome(tester, '객관식');
    expect(find.text('오늘 2개 외움'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('known-today-mode'))).data,
      '객관식',
    );

    await pickOnHome(tester, '일본어 떠올리기');
    expect(find.textContaining('개 외움'), findsNothing);
  });

  testWidgets('no speech: 듣고 맞히기 says why and is not picked', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedModeWords(blocks);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(blocks, extra: withSpeech(const SilentSpeech())),
    );
    await tester.pumpAndSettle();

    await pickOnHome(tester, '듣고 맞히기');

    expect(find.text('발음을 들을 수 없어 고를 수 없어요'), findsWidgets);
    showsOnHome('뜻 맞히기');
    expect((await blocks.preferences.load()).mode, StudyMode.meaning);
    handle.dispose();
  });

  testWidgets('fewer than four words: 객관식 and 듣고 맞히기 say why', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedModeWords(blocks, count: 3);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(blocks, extra: withSpeech(RecordingSpeech())));
    await tester.pumpAndSettle();

    for (final label in ['객관식', '듣고 맞히기']) {
      await pickOnHome(tester, label);
      expect(
        find.text('뜻이 서로 다른 단어가 4개 이상 있어야 해요'),
        findsWidgets,
        reason: label,
      );
      showsOnHome('뜻 맞히기');
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    handle.dispose();
  });

  testWidgets('a stored mode that cannot be studied now shows 뜻 맞히기', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedModeWords(blocks);
    await blocks.preferences.save(
      const StudyPreferences(mode: StudyMode.listening),
    );
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(blocks, extra: withSpeech(const SilentSpeech())),
    );
    await tester.pumpAndSettle();

    showsOnHome('뜻 맞히기');
    expect(
      (await blocks.preferences.load()).mode,
      StudyMode.listening,
      reason: 'the stored choice is kept for when speech is back',
    );
    handle.dispose();
  });

  testWidgets('the study screen says the mode', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedModeWords(blocks);
    await blocks.preferences.save(
      const StudyPreferences(mode: StudyMode.recall),
    );
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
    expect(find.text('일본어 떠올리기'), findsOneWidget);
  });

  testWidgets('the playlist screen has the same chips, the same mode', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await seedModeWords(blocks);
    final listId = (await blocks.library.playlists()).single.id;
    await blocks.reviews.saveCard(
      waitingCard(words[0].id, StudyMode.choice, 2),
    );
    await tester.pumpWidget(screen(blocks, PlaylistScreen(playlistId: listId)));
    await tester.pumpAndSettle();

    expect(modeChip(tester, '뜻 맞히기').selected, isTrue);
    await tester.tap(find.widgetWithText(ChoiceChip, '객관식'));
    await tester.pumpAndSettle();
    expect(modeChip(tester, '객관식').selected, isTrue);
    expect((await blocks.preferences.load()).mode, StudyMode.choice);
  });
}
