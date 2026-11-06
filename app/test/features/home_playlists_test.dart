// The home screen's playlists: order, counts, opening one, the edit screen.
// Synthetic sample words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/features/playlists/playlists_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  testWidgets('no playlist yet: the empty home says what to do', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(TestBlocks()));
    await tester.pumpAndSettle();
    expect(find.text('재생목록'), findsOneWidget);
    expect(find.text('페이지를 등록하고 재생목록에 단어를 모아 보세요'), findsOneWidget);
    expect(find.text('먼저 페이지를 등록해 주세요'), findsOneWidget);
    expect(find.textContaining('교재'), findsNothing);
  });

  testWidgets('playlists in their order with shown and hidden counts', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final nature = await blocks.seedPage('s010', name: '자연');
    final travel = await blocks.seedPage('s140', name: '여행');
    final natureWords = await blocks.library.words(playlistId: nature.id);
    final travelCount = (await blocks.library.words(
      playlistId: travel.id,
    )).length;
    await LibraryService(
      library: blocks.library,
      clock: blocks.clock,
    ).hideWords([natureWords.first.id]);
    await LibraryService(
      library: blocks.library,
      clock: blocks.clock,
    ).reorderPlaylists([travel.id, nature.id]);

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('여행')).dy,
      lessThan(tester.getTopLeft(find.text('자연')).dy),
    );
    expect(
      find.text('단어 ${natureWords.length - 1}개 · 숨김 1개'),
      findsOneWidget,
    );
    expect(find.text('단어 $travelCount개'), findsOneWidget);
  });

  testWidgets('a word in two playlists counts in both, once in 전체', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final first = await blocks.seedPage('s140', name: '여행');
    final second = await blocks.seedPage('s140', name: '복습용');
    final count = (await blocks.library.words(playlistId: first.id)).length;
    expect((await blocks.library.words(playlistId: second.id)).length, count);

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    expect(find.text('단어 $count개'), findsNWidgets(2));
    expect(find.text('$count'), findsOneWidget, reason: 'new words, once');
  });

  testWidgets('tapping a playlist opens it; 편집 opens the edit screen', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final travel = await blocks.seedPage('s140', name: '여행');

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await tester.tap(find.text('여행'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PlaylistScreen>(find.byType(PlaylistScreen)).playlistId,
      travel.id,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('편집'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistsScreen), findsOneWidget);
  });
}
