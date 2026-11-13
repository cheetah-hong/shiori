// U6: every empty state says what is missing and offers the next step; a
// state that only informs is plain text, not a dimmed button. Made-up and
// synthetic sample words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/features/playlists/playlists_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

/// [text] is shown, and not as (part of) a button.
void _plainText(String text) {
  expect(find.text(text), findsOneWidget);
  expect(
    find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ),
    findsNothing,
    reason: '「$text」 is a message, not a button',
  );
}

/// The button (filled, outlined or text) labelled [label].
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

final class _NoWordCamera implements ImageSource {
  int picks = 0;

  @override
  Future<PageImage?> pick(ImageOrigin origin) async {
    picks++;
    return const PageImage('page.jpg');
  }

  @override
  Future<void> discard(PageImage image) async {}
}

final class _KoreanOnly implements TextRecognizer {
  @override
  String get id => 'test';

  @override
  Future<OcrScan> recognize(PageImage image) async => const OcrScan(
    japanese: OcrPage(lines: [], engine: 'test', languages: ['ja-JP']),
    korean: OcrPage(
      lines: [OcrLine(text: '안녕하세요', x: 0.1, y: 0.1, width: 0.2, height: 0.02)],
      engine: 'test',
      languages: ['ko-KR'],
    ),
  );
}

void main() {
  testWidgets('홈, no word yet: a message and 「첫 페이지 등록하기」', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(TestBlocks()));
    await tester.pumpAndSettle();

    _plainText('먼저 페이지를 등록해 주세요');
    expect(find.text('페이지를 등록하고 재생목록에 단어를 모아 보세요'), findsOneWidget);
    await tester.ensureVisible(_button('첫 페이지 등록하기'));
    await tester.tap(_button('첫 페이지 등록하기'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '페이지 등록'), findsOneWidget);
  });

  testWidgets('홈, nothing to study today: a message, not a dimmed button', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s140');
    final words = await blocks.library.words(playlistId: list.id);
    await LibraryService(
      library: blocks.library,
      clock: blocks.clock,
    ).hideWords([for (final w in words) w.id]);
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    _plainText('지금은 복습할 단어가 없어요');
    expect(find.text('복습할 때가 되면 숫자가 올라와요'), findsOneWidget);
  });

  testWidgets('a photo with no word: what to try and 「다시 찍기」', (tester) async {
    usePhoneSize(tester);
    final camera = _NoWordCamera();
    await tester.pumpWidget(
      app(
        TestBlocks(),
        extra: [
          imageSourceProvider.overrideWithValue(camera),
          textRecognizerProvider.overrideWithValue(_KoreanOnly()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카메라로 찍기'));
    await tester.pumpAndSettle();

    expect(
      find.text('이 사진에서 단어를 찾지 못했어요. 페이지 전체가 화면에 들어오게, 밝은 곳에서 똑바로 찍어 주세요.'),
      findsOneWidget,
    );
    expect(camera.picks, 1);
    await tester.tap(_button('다시 찍기'));
    await tester.pumpAndSettle();
    expect(camera.picks, 2, reason: '다시 찍기 opens the camera again');
  });

  testWidgets('a playlist with no word: how words get in, 「단어 추가」', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.library.savePlaylist(
      Playlist(id: 'e', name: '빈 목록', createdAt: testNow, position: 0),
    );
    await tester.pumpWidget(
      screen(blocks, const PlaylistScreen(playlistId: 'e')),
    );
    await tester.pumpAndSettle();

    expect(find.text('이 목록에는 아직 단어가 없어요'), findsOneWidget);
    expect(find.text('페이지를 등록할 때 이 재생목록을 고르면 단어가 들어와요.'), findsOneWidget);
    await tester.tap(_button('단어 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진으로'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '페이지 등록'), findsOneWidget);
  });

  testWidgets('재생목록 편집 with no playlist: 「새 재생목록」 button', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), const PlaylistsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('재생목록이 없어요'), findsOneWidget);
    expect(find.text('페이지를 등록하면서 만들거나, 여기서 먼저 만들 수 있어요.'), findsOneWidget);
    await tester.tap(_button('새 재생목록'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is AlertDialog), findsOneWidget);
  });

  testWidgets('a playlist with nothing to study: a message, not a button', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final list = await blocks.seedPage('s140');
    final words = await blocks.library.words(playlistId: list.id);
    await LibraryService(
      library: blocks.library,
      clock: blocks.clock,
    ).hideWords([for (final w in words) w.id]);
    await tester.pumpWidget(
      screen(blocks, PlaylistScreen(playlistId: list.id)),
    );
    await tester.pumpAndSettle();

    _plainText('지금은 학습할 카드가 없어요');
  });

  testWidgets('a load failure on 재생목록 편집 says so and offers 다시 불러오기', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      screen(
        TestBlocks(),
        const PlaylistsScreen(),
        extra: [
          playlistsProvider.overrideWith(
            (ref) => Future.error(Exception('db')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('재생목록을 불러오지 못했어요'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(_button('다시 불러오기'), findsOneWidget);
  });
}
