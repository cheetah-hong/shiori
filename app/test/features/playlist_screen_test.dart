// The playlist screen: its words in order, studying only them, taking a word
// out (and undoing it), adding it to another list, renaming and deleting the
// playlist. Synthetic sample words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  testWidgets('lists the words in the playlist\'s order with their level', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s010');
    final words = await blocks.library.words(playlistId: list.id);
    await blocks.reviews.saveCard(
      ReviewCard(
        wordId: words.first.id,
        level: 4,
        dueAt: testNow.add(const Duration(days: 21)),
        lastReviewedAt: testNow,
      ),
    );

    await tester.pumpWidget(screen(blocks, PlaylistScreen(playlistId: list.id)));
    await tester.pumpAndSettle();

    expect(find.text('JLPT 단어장'), findsOneWidget);
    expect(find.text(words.first.headword), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(words[0].headword)).dy,
      lessThan(tester.getTopLeft(find.text(words[1].headword)).dy),
    );
    expect(
      find.byWidgetPredicate((w) => w is MemoryMeter && w.level == 4),
      findsOneWidget,
    );
    expect(find.textContaining('DAY'), findsNothing);
  });

  testWidgets('「이 목록 학습」 studies this playlist only', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s010', name: '자연');
    final travel = await blocks.seedPage('s140', name: '여행');
    final first = (await blocks.library.words(playlistId: travel.id)).first;

    await tester.pumpWidget(
      screen(blocks, PlaylistScreen(playlistId: travel.id)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 목록 학습'));
    await tester.pumpAndSettle();

    expect(find.text(first.headword), findsWidgets);
    final count = (await blocks.library.words(playlistId: travel.id)).length;
    expect(find.text('0 / $count'), findsOneWidget);
  });

  testWidgets('taking a word out, and undoing it', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s010');
    final words = await blocks.library.words(playlistId: list.id);
    final second = words[1];

    await tester.pumpWidget(screen(blocks, PlaylistScreen(playlistId: list.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('${second.headword} 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 목록에서 빼기'));
    await tester.pumpAndSettle();

    expect(find.text('「${second.headword}」 뺐어요'), findsOneWidget);
    expect(
      (await blocks.library.words(playlistId: list.id)).map((w) => w.id),
      isNot(contains(second.id)),
    );
    expect(await blocks.library.word(second.id), isNotNull);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(
      (await blocks.library.words(playlistId: list.id)).map((w) => w.id),
      [for (final w in words) w.id],
    );
  });

  testWidgets('adding a word to another playlist links the same word', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s010', name: '자연');
    final other = await blocks.seedPage('s140', name: '여행');
    final word = (await blocks.library.words(playlistId: list.id)).first;

    await tester.pumpWidget(screen(blocks, PlaylistScreen(playlistId: list.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('${word.headword} 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다른 목록에 추가'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('pick-${list.id}')), findsNothing);
    await tester.tap(find.byKey(ValueKey('pick-${other.id}')));
    await tester.pumpAndSettle();

    expect(find.text("'여행'에 단어 1개 추가"), findsOneWidget);
    expect(
      (await blocks.library.words(playlistId: other.id)).last.id,
      word.id,
    );
    expect(await blocks.library.playlistsOf([word.id]), {
      word.id: {list.id, other.id},
    });

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('${word.headword} 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다른 목록에 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('pick-${other.id}')));
    await tester.pumpAndSettle();
    expect(find.text("'여행'에 이미 있어요"), findsOneWidget);
  });

  testWidgets('renaming the playlist, refusing a name another one has', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s010', name: '자연');
    await blocks.seedPage('s140', name: '여행');

    await tester.pumpWidget(screen(blocks, PlaylistScreen(playlistId: list.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('재생목록 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이름 바꾸기'));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextField, '재생목록 이름');
    await tester.enterText(field, '여행');
    await tester.pump();
    expect(find.text('같은 이름의 재생목록이 있어요'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, '저장')).onPressed,
      isNull,
    );
    await tester.enterText(field, '자연·몸');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('자연·몸'), findsOneWidget);
    expect((await blocks.library.playlist(list.id))?.name, '자연·몸');
  });

  testWidgets('deleting the playlist keeps its words and goes home', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s010', name: '자연');
    final words = await blocks.library.words(playlistId: list.id);
    await blocks.reviews.saveCard(
      ReviewCard(
        wordId: words.first.id,
        level: 3,
        dueAt: testNow.add(const Duration(days: 7)),
        lastReviewedAt: testNow,
      ),
    );

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await tester.tap(find.text('자연'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistScreen), findsOneWidget);

    await tester.tap(find.byTooltip('재생목록 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('재생목록을 삭제할까요?'), findsOneWidget);
    expect(
      find.text('단어 ${words.length}개가 이 목록에서 빠져요. 단어와 학습 기록은 남아요.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistScreen), findsNothing);
    expect(find.byType(ShioriApp), findsOneWidget);
    expect(find.text('페이지를 등록하고 재생목록에 단어를 모아 보세요'), findsOneWidget);
    expect(await blocks.library.playlist(list.id), isNull);
    expect(await blocks.library.word(words.first.id), isNotNull);
    expect((await blocks.reviews.card(words.first.id))?.level, 3);
  });

  testWidgets('cancelling the delete keeps the playlist', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s010');
    await tester.pumpWidget(screen(blocks, PlaylistScreen(playlistId: list.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('재생목록 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();
    expect(await blocks.library.playlist(list.id), isNotNull);
    expect(find.byType(PlaylistScreen), findsOneWidget);
  });

  testWidgets('an empty playlist says so', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.library.savePlaylist(
      Playlist(id: 'e', name: '빈 목록', createdAt: testNow, position: 0),
    );
    await tester.pumpWidget(screen(blocks, const PlaylistScreen(playlistId: 'e')));
    await tester.pumpAndSettle();
    expect(find.text('이 목록에는 아직 단어가 없어요'), findsOneWidget);
  });
}
