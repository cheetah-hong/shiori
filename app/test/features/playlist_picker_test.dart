// The playlist picker that opens from 「단어 N개 추가」 and 「다른 목록에 추가」.
// Made-up words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/playlists/playlist_picker.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

/// A button that opens the picker and keeps what it returned.
final class _Opener extends StatelessWidget {
  const _Opener({required this.onPicked, this.preview, this.except});

  final void Function(AddTarget?) onPicked;
  final AddPreview? preview;
  final String? except;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () async => onPicked(
          await showPlaylistPicker(
            context,
            preview: preview,
            exceptPlaylistId: except,
          ),
        ),
        child: const Text('열기'),
      ),
    ),
  );
}

void main() {
  final now = testNow;

  Future<Playlist> list(TestBlocks blocks, String id, int position) async {
    final p = Playlist(
      id: id,
      name: '목록 $id',
      createdAt: now.add(Duration(minutes: position)),
      position: position,
    );
    await blocks.library.savePlaylist(p);
    return p;
  }

  Future<void> addWord(
    TestBlocks blocks,
    String playlistId,
    String wordId,
    DateTime at,
  ) async {
    if (await blocks.library.word(wordId) == null) {
      await blocks.library.insertWords([
        Word(
          id: wordId,
          headword: '語$wordId',
          readings: const ['ご'],
          meaning: '말',
          createdAt: at,
        ),
      ]);
    }
    await blocks.library.addToPlaylist(playlistId, [wordId], at: at);
  }

  Future<AddTarget?> Function() open(
    WidgetTester tester,
    TestBlocks blocks, {
    AddPreview? preview,
    String? except,
  }) {
    AddTarget? picked;
    var done = false;
    return () async {
      await tester.pumpWidget(
        screen(
          blocks,
          _Opener(
            preview: preview,
            except: except,
            onPicked: (t) {
              picked = t;
              done = true;
            },
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      return done ? picked : null;
    };
  }

  testWidgets(
    'with no playlist yet the new-playlist form is open with 「내 단어장」',
    (tester) async {
      usePhoneSize(tester);
      final blocks = TestBlocks();
      AddTarget? picked;
      await tester.pumpWidget(
        screen(blocks, _Opener(onPicked: (t) => picked = t)),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      expect(find.text('어느 재생목록에 추가할까요?'), findsOneWidget);
      final field = find.widgetWithText(TextField, '재생목록 이름');
      expect(field, findsOneWidget);
      expect(
        tester.widget<TextField>(field).controller?.text,
        defaultPlaylistName,
      );
      await tester.tap(find.text('만들고 추가'));
      await tester.pumpAndSettle();

      expect(picked, isA<NewPlaylist>());
      expect((picked! as NewPlaylist).name, '내 단어장');
      expect(find.text('어느 재생목록에 추가할까요?'), findsNothing);
    },
  );

  testWidgets(
    'lists the playlists last added to first, with what each already holds',
    (tester) async {
      usePhoneSize(tester);
      final blocks = TestBlocks();
      final a = await list(blocks, 'a', 0);
      final b = await list(blocks, 'b', 1);
      final c = await list(blocks, 'c', 2);
      await addWord(blocks, a.id, 'w1', now);
      await addWord(blocks, a.id, 'w2', now);
      await addWord(blocks, b.id, 'w1', now.add(const Duration(hours: 1)));
      await open(
        tester,
        blocks,
        preview: AddPreview(
          libraryKeys: const {'語w1', '語w2'},
          alreadyIn: {a.id: 2, b.id: 1},
        ),
      )();

      final rows = [
        for (final id in ['b', 'a', 'c'])
          tester.getTopLeft(find.byKey(ValueKey('pick-$id'))).dy,
      ];
      expect(rows, orderedEquals([...rows]..sort()));
      expect(
        find.descendant(
          of: find.byKey(ValueKey('pick-${b.id}')),
          matching: find.text('단어 1개 · 이미 있음 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('pick-${a.id}')),
          matching: find.text('단어 2개 · 이미 있음 2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('pick-${c.id}')),
          matching: find.text('단어 0개'),
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, '재생목록 이름'),
        findsNothing,
        reason: 'the new-playlist form opens on demand when lists exist',
      );
    },
  );

  testWidgets('tapping a playlist picks it', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await list(blocks, 'a', 0);
    final b = await list(blocks, 'b', 1);
    AddTarget? picked;
    await tester.pumpWidget(
      screen(blocks, _Opener(onPicked: (t) => picked = t)),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('목록 b'));
    await tester.pumpAndSettle();
    expect(picked, isA<ExistingPlaylist>());
    expect((picked! as ExistingPlaylist).playlistId, b.id);
  });

  testWidgets(
    'a new playlist needs a name no other playlist has',
    (tester) async {
      usePhoneSize(tester);
      final blocks = TestBlocks();
      await blocks.library.savePlaylist(
        Playlist(id: 'x', name: '내 단어장', createdAt: now, position: 0),
      );
      AddTarget? picked;
      await tester.pumpWidget(
        screen(blocks, _Opener(onPicked: (t) => picked = t)),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('새 재생목록'));
      await tester.pumpAndSettle();

      final field = find.widgetWithText(TextField, '재생목록 이름');
      expect(
        tester.widget<TextField>(field).controller?.text,
        isEmpty,
        reason: '「내 단어장」 is taken',
      );
      FilledButton create() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '만들고 추가'),
      );
      expect(create().onPressed, isNull, reason: 'blank');

      await tester.enterText(field, ' 내 단어장 ');
      await tester.pump();
      expect(find.text('같은 이름의 재생목록이 있어요'), findsOneWidget);
      expect(create().onPressed, isNull);

      await tester.enterText(field, 'N4 동사');
      await tester.pump();
      expect(find.text('같은 이름의 재생목록이 있어요'), findsNothing);
      await tester.tap(find.text('만들고 추가'));
      await tester.pumpAndSettle();
      expect((picked! as NewPlaylist).name, 'N4 동사');
    },
  );

  testWidgets('the playlist the words come from is not offered', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final a = await list(blocks, 'a', 0);
    await list(blocks, 'b', 1);
    await open(tester, blocks, except: a.id)();
    expect(find.byKey(ValueKey('pick-${a.id}')), findsNothing);
    expect(find.byKey(const ValueKey('pick-b')), findsOneWidget);
  });

  testWidgets('closing the sheet picks nothing', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await list(blocks, 'a', 0);
    var called = false;
    AddTarget? picked = const NewPlaylist('placeholder');
    await tester.pumpWidget(
      screen(
        blocks,
        _Opener(
          onPicked: (t) {
            called = true;
            picked = t;
          },
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(picked, isNull);
  });
}
