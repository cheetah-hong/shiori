// 재생목록 편집: making, renaming, deleting and ordering playlists.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/playlists/playlists_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  Future<void> seedLists(TestBlocks blocks, List<String> names) async {
    for (final (i, name) in names.indexed) {
      await blocks.library.savePlaylist(
        Playlist(id: 'p$i', name: name, createdAt: testNow, position: i),
      );
    }
  }

  Future<List<String>> names(TestBlocks blocks) async => [
    for (final p in await blocks.library.playlists()) p.name,
  ];

  testWidgets('a new playlist from the app bar goes last', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedLists(blocks, ['A']);
    await tester.pumpWidget(screen(blocks, const PlaylistsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('재생목록 편집'), findsOneWidget);

    await tester.tap(find.byTooltip('새 재생목록'));
    await tester.pumpAndSettle();
    expect(find.text('새 재생목록'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('playlist-name')), 'B');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '만들기'));
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
    expect(await names(blocks), ['A', 'B']);
  });

  testWidgets('a taken or blank name cannot be made', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedLists(blocks, ['A']);
    await tester.pumpWidget(screen(blocks, const PlaylistsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('새 재생목록'));
    await tester.pumpAndSettle();
    TextButton make() =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, '만들기'));
    await tester.enterText(find.byKey(const ValueKey('playlist-name')), ' ');
    await tester.pump();
    expect(make().onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('playlist-name')), 'a');
    await tester.pump();
    expect(find.text('같은 이름의 재생목록이 있어요'), findsOneWidget);
    expect(make().onPressed, isNull);
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();
    expect(await names(blocks), ['A']);
  });

  testWidgets('renaming and deleting from a row\'s menu', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedLists(blocks, ['A', 'B']);
    await tester.pumpWidget(screen(blocks, const PlaylistsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('A 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이름 바꾸기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('playlist-name')), 'A2');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();
    expect(await names(blocks), ['A2', 'B']);

    await tester.tap(find.byTooltip('B 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('재생목록을 삭제할까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    expect(await names(blocks), ['A2']);
    expect(find.text('B'), findsNothing);
  });

  testWidgets('moving a playlist down and up from its menu', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedLists(blocks, ['A', 'B', 'C']);
    await tester.pumpWidget(screen(blocks, const PlaylistsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('A 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아래로 옮기기'));
    await tester.pumpAndSettle();
    expect(await names(blocks), ['B', 'A', 'C']);

    await tester.tap(find.byTooltip('C 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('위로 옮기기'));
    await tester.pumpAndSettle();
    expect(await names(blocks), ['B', 'C', 'A']);
    expect(
      tester.getTopLeft(find.text('C')).dy,
      lessThan(tester.getTopLeft(find.text('A')).dy),
    );
  });

  testWidgets('the first row cannot move up, the last cannot move down', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedLists(blocks, ['A', 'B']);
    await tester.pumpWidget(screen(blocks, const PlaylistsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('A 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('위로 옮기기'), findsNothing);
    expect(find.text('아래로 옮기기'), findsOneWidget);
  });
}
