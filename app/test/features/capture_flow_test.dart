import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/capture/review_filter.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/forwarding_library.dart';
import '../support/harness.dart';

final class _FailingRecognizer implements TextRecognizer {
  @override
  String get id => 'failing';

  @override
  Future<OcrScan> recognize(PageImage image) =>
      Future.error(const TextRecognitionException('글자를 읽지 못했습니다'));
}

final class _NoPhoto implements ImageSource {
  @override
  Future<PageImage?> pick(ImageOrigin origin) async => null;

  @override
  Future<void> discard(PageImage image) async {}
}

/// Hands out a fake photo and records what was discarded afterwards.
final class _FakeCamera implements ImageSource {
  final discarded = <String>[];

  @override
  Future<PageImage?> pick(ImageOrigin origin) async => const PageImage('s140');

  @override
  Future<void> discard(PageImage image) async => discarded.add(image.path);
}

/// A bug inside a block: throws an Error, not a recognition failure.
final class _BuggyRecognizer implements TextRecognizer {
  @override
  String get id => 'buggy';

  @override
  Future<OcrScan> recognize(PageImage image) => Future.error(StateError('bug'));
}

/// Storage that fails on writing words, like a full disk (or a bug: [error]).
final class _FailingLibrary extends ForwardingLibrary {
  _FailingLibrary({this.error = const FileSystemException('disk full')});

  final Object error;

  @override
  Future<void> insertWords(List<Word> words) => Future.error(error);
}

final class _BrokenCamera implements ImageSource {
  @override
  Future<PageImage?> pick(ImageOrigin origin) =>
      Future.error(const ImageSourceException('이 기기에서는 카메라를 쓸 수 없어요.'));

  @override
  Future<void> discard(PageImage image) async {}
}

Future<void> openSample(WidgetTester tester, String detail) async {
  await tester.tap(find.text('페이지 등록'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(detail).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(detail).first);
  await tester.pumpAndSettle();
}

/// Taps the add button and adds to the new playlist the picker offers (its
/// form is open when there is no playlist yet).
Future<void> addToNewPlaylist(WidgetTester tester, String button) async {
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  expect(find.text('어느 재생목록에 추가할까요?'), findsOneWidget);
  await tester.tap(find.text('만들고 추가'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'sample page 10: the review lists its words without page info, a fix '
    'clears a flag, adding to a new playlist fills the home screen',
    (tester) async {
      usePhoneSize(tester);
      final blocks = TestBlocks();
      await tester.pumpWidget(app(blocks));
      await tester.pumpAndSettle();
      expect(find.text('먼저 페이지를 등록해 주세요'), findsOneWidget);

      await openSample(tester, 'DAY 01 자연, 몸');

      expect(find.text('검토'), findsOneWidget);
      // No DAY, title or page is read from the page any more.
      expect(find.text('단어 11개'), findsOneWidget);
      expect(find.textContaining('DAY'), findsNothing);
      expect(find.text('쪽 정보 없음'), findsNothing);
      expect(find.text('단어 11개 추가'), findsOneWidget);

      // くち (its kanji was not read) is fixed in the editor.
      // The filter shows 전체 11 (every word), not only the flagged ones.
      expect(find.text('전체 11'), findsOneWidget);
      expect(
        tester.widget<ReviewFilter>(find.byType(ReviewFilter)).onlyFlagged,
        isFalse,
      );
      await tester.scrollUntilVisible(find.text('くち'), 200);
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('くち'),
            matching: find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('entry-'),
            ),
          ),
          matching: find.byTooltip('고치기'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '표제어'), '口');
      await tester.tap(find.text('고치기').last);
      await tester.pumpAndSettle();
      expect(find.text('口'), findsOneWidget);

      // No playlist yet: the picker opens on its new-playlist form, named
      // 「내 단어장」.
      await tester.tap(find.text('단어 11개 추가'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(TextField, '재생목록 이름'),
          matching: find.text('내 단어장'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('만들고 추가'));
      await tester.pumpAndSettle();

      expect(find.text("'내 단어장'에 단어 11개 추가"), findsOneWidget);
      expect(find.text('검토'), findsNothing, reason: 'back on the home screen');
      expect(find.text('내 단어장'), findsOneWidget);
      expect(
        find.text('10개 · 11개 중'),
        findsOneWidget,
        reason: '11 new words on the day sheet, 10 of them today',
      );
      final playlist = (await blocks.library.playlists()).single;
      expect(playlist.name, '내 단어장');
      final words = await blocks.library.words(playlistId: playlist.id);
      expect(words, hasLength(11));
      expect(words.map((w) => w.headword), contains('口'));
      // Added in the photo's order.
      expect(words.first.headword, '雨');
      expect(words.last.headword, 'ちょっと');

      // The add message must not follow the learner onto the study buttons.
      await tester.tap(find.textContaining('오늘 학습 시작'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('the example-page sample opens with its words', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 20 여행·교통');

    expect(find.text('검토'), findsOneWidget);
    expect(find.text('乗り換える'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-heading')), findsOneWidget);
  });

  testWidgets('excluding an entry lowers the add count', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 21 쇼핑');
    expect(find.text('단어 5개 추가'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'저장$')).first);
    await tester.pumpAndSettle();
    expect(find.text('단어 4개 추가'), findsOneWidget);
  });

  testWidgets('a recognizer failure is explained on the capture screen', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks()..sampleRecognizer = _FailingRecognizer();
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 01 자연, 몸');
    expect(find.text('글자를 읽지 못했습니다'), findsOneWidget);
    expect(find.text('검토'), findsNothing);
  });

  testWidgets('cancelling the album changes nothing; a camera error is shown', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(
      app(blocks, extra: [imageSourceProvider.overrideWithValue(_NoPhoto())]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('앨범에서 고르기'));
    await tester.pumpAndSettle();
    expect(find.text('검토'), findsNothing);

    await tester.pumpWidget(
      app(
        TestBlocks(),
        extra: [imageSourceProvider.overrideWithValue(_BrokenCamera())],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카메라로 찍기'));
    await tester.pumpAndSettle();
    expect(find.text('이 기기에서는 카메라를 쓸 수 없어요.'), findsOneWidget);
  });

  testWidgets('adding into a new playlist from the picker', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s010');
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 20 여행·교통');

    await tester.tap(find.textContaining(RegExp(r'^단어 \d+개 추가$')));
    await tester.pumpAndSettle();
    expect(find.text('어느 재생목록에 추가할까요?'), findsOneWidget);
    expect(find.text('JLPT 단어장'), findsOneWidget);
    expect(
      find.text('만들고 추가'),
      findsNothing,
      reason: 'with a playlist to pick, the form starts closed',
    );

    await tester.tap(find.text('새 재생목록'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '재생목록 이름'), 'N4 단어장');
    await tester.pump();
    await tester.tap(find.text('만들고 추가'));
    await tester.pumpAndSettle();

    final playlists = await blocks.library.playlists();
    expect(playlists.map((p) => p.name), ['JLPT 단어장', 'N4 단어장']);
    final added = await blocks.library.words(playlistId: playlists.last.id);
    expect(added, isNotEmpty);
    expect(added.map((w) => w.headword), contains('乗り換える'));
    expect(find.text("'N4 단어장'에 단어 ${added.length}개 추가"), findsOneWidget);
  });

  testWidgets(
    'a photo is read with the device recognizer, then its temp file is freed',
    (tester) async {
      usePhoneSize(tester);
      final camera = _FakeCamera();
      await tester.pumpWidget(
        app(
          TestBlocks(),
          extra: [
            imageSourceProvider.overrideWithValue(camera),
            textRecognizerProvider.overrideWithValue(fixtureFileRecognizer),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('페이지 등록'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('카메라로 찍기'));
      await tester.pumpAndSettle();
      expect(find.text('검토'), findsOneWidget);
      expect(find.text('乗り換える'), findsOneWidget);
      expect(camera.discarded, ['s140']);
    },
  );

  testWidgets(
    'a bug in a block is reported and does not freeze the reading overlay',
    (tester) async {
      usePhoneSize(tester);
      final blocks = TestBlocks()..sampleRecognizer = _BuggyRecognizer();
      await tester.pumpWidget(app(blocks));
      await tester.pumpAndSettle();
      await openSample(tester, 'DAY 01 자연, 몸');
      expect(tester.takeException(), isStateError);
      expect(find.text('단어를 정리하다가 문제가 생겼어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('글자를 읽는 중'), findsNothing);
    },
  );

  testWidgets('a storage failure on adding is shown and the button comes '
      'back', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks(library: _FailingLibrary());
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 21 쇼핑');
    await addToNewPlaylist(tester, '단어 5개 추가');
    expect(find.text('저장하지 못했어요. 다시 시도해 주세요'), findsOneWidget);
    expect(
      find.text('검토'),
      findsOneWidget,
      reason: 'still on the review screen',
    );
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('단어 5개 추가'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
    expect(
      await blocks.library.playlists(),
      isEmpty,
      reason: 'the new playlist is undone with the words',
    );
  });

  testWidgets('clearing the meaning in the editor flags it again', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(TestBlocks()));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 21 쇼핑');
    expect(find.text('뜻 없음'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('entry-0')),
        matching: find.byTooltip('고치기'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '뜻'), '');
    await tester.tap(find.text('고치기').last);
    await tester.pumpAndSettle();
    expect(find.text('뜻 없음'), findsOneWidget);
  });

  testWidgets('a bug while adding is reported and the button comes back', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      app(TestBlocks(library: _FailingLibrary(error: StateError('bug')))),
    );
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 21 쇼핑');
    await addToNewPlaylist(tester, '단어 5개 추가');
    expect(tester.takeException(), isStateError);
    expect(find.text('저장하지 못했어요. 다시 시도해 주세요'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('단어 5개 추가'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });
}
