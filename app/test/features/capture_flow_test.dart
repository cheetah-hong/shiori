import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/capture/entry_tile.dart';
import 'package:shiori_core/shiori_core.dart';

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
final class _FailingLibrary implements LibraryRepository {
  _FailingLibrary({this.error = const FileSystemException('disk full')});

  final Object error;
  final _inner = InMemoryLibraryRepository();

  @override
  Future<void> saveWords(List<Word> words) => Future.error(error);

  @override
  Future<List<Textbook>> textbooks() => _inner.textbooks();

  @override
  Future<Textbook?> textbook(String id) => _inner.textbook(id);

  @override
  Future<void> saveTextbook(Textbook textbook) => _inner.saveTextbook(textbook);

  @override
  Future<List<TextbookDay>> days(String textbookId) => _inner.days(textbookId);

  @override
  Future<void> saveDay(TextbookDay day) => _inner.saveDay(day);

  @override
  Future<List<Word>> words({String? textbookId, int? day}) =>
      _inner.words(textbookId: textbookId, day: day);

  @override
  Future<Word?> word(String id) => _inner.word(id);
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

void main() {
  testWidgets(
    'sample page 10: review flags the unread headwords, a fix clears it, save fills the home screen',
    (tester) async {
      usePhoneSize(tester);
      final blocks = TestBlocks();
      await tester.pumpWidget(app(blocks));
      await tester.pumpAndSettle();
      expect(find.text('먼저 교재 페이지를 등록해 주세요'), findsOneWidget);

      await openSample(tester, 'DAY 01 자연, 몸');

      expect(find.text('검토'), findsOneWidget);
      expect(find.text('DAY 01 자연, 몸 · 10쪽'), findsOneWidget);
      expect(find.text('확인 필요 2'), findsWidgets);
      expect(find.text('표제어 없음 · 눌러서 입력'), findsNWidgets(2));
      expect(
        find.text('단어 10개 저장'),
        findsOneWidget,
        reason: 'two rows have no headword yet',
      );
      expect(find.text('표제어가 빈 단어 2개는 저장하지 않아요'), findsOneWidget);

      // Fix 0002 (日) in the editor.
      await tester.tap(find.text('표제어 없음 · 눌러서 입력').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '표제어'), '日');
      await tester.tap(find.text('고치기').last);
      await tester.pumpAndSettle();
      expect(find.text('표제어 없음 · 눌러서 입력'), findsOneWidget);
      expect(find.text('표제어가 빈 단어 1개는 저장하지 않아요'), findsOneWidget);

      await tester.tap(find.text('단어 11개 저장'));
      await tester.pumpAndSettle();

      expect(find.text('단어 11개를 저장했어요'), findsOneWidget);
      expect(find.text('JLPT 단어장'), findsOneWidget);
      expect(find.text('DAY 01 · 단어 11개'), findsOneWidget);
      expect(
        find.text('11'),
        findsOneWidget,
        reason: '11 new words on the today card',
      );
      final words = await blocks.library.words();
      expect(words.map((w) => w.headword), contains('日'));
      expect(words.every((w) => w.page == 10 && w.day == 1), isTrue);

      // The save message must not follow the learner onto the study buttons.
      await tester.tap(find.textContaining('오늘 학습 시작'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('entry-layout sample keeps its examples', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 20 여행·교통');

    expect(find.text('DAY 20 여행·교통 · 140쪽'), findsOneWidget);
    expect(find.text('次の駅で急行に乗り換えてください。'), findsOneWidget);
    expect(find.byType(EntryTile), findsWidgets);
  });

  testWidgets('excluding an entry lowers the save count', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 21 쇼핑');
    expect(find.text('단어 5개 저장'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'저장$')).first);
    await tester.pumpAndSettle();
    expect(find.text('단어 4개 저장'), findsOneWidget);
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

  testWidgets('saving into a new textbook from the picker', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.seedPage('s010');
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 20 여행·교통');

    await tester.tap(find.text('저장할 교재'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '교재 이름'), 'N4 단어장');
    await tester.tap(find.text('새 교재로 저장'));
    await tester.pumpAndSettle();
    expect(find.text('새 교재 · N4 단어장'), findsOneWidget);

    await tester.tap(find.textContaining('저장').last);
    await tester.pumpAndSettle();
    expect((await blocks.library.textbooks()).map((t) => t.title), [
      'JLPT 단어장',
      'N4 단어장',
    ]);
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
      expect(find.text('DAY 20 여행·교통 · 140쪽'), findsOneWidget);
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

  testWidgets('a storage failure on save is shown and the button comes back', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks(library: _FailingLibrary());
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 21 쇼핑');
    await tester.tap(find.text('단어 5개 저장'));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 못했어요. 다시 시도해 주세요'), findsOneWidget);
    expect(
      find.text('검토'),
      findsOneWidget,
      reason: 'still on the review screen',
    );
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('단어 5개 저장'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('clearing the meaning in the editor flags it again', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(TestBlocks()));
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 21 쇼핑');
    expect(find.text('뜻 없음'), findsNothing);
    await tester.tap(find.text('値段'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '뜻'), '');
    await tester.tap(find.text('고치기').last);
    await tester.pumpAndSettle();
    expect(find.text('뜻 없음'), findsOneWidget);
  });

  testWidgets('a bug while saving is reported and the button comes back', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      app(TestBlocks(library: _FailingLibrary(error: StateError('bug')))),
    );
    await tester.pumpAndSettle();
    await openSample(tester, 'DAY 21 쇼핑');
    await tester.tap(find.text('단어 5개 저장'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isStateError);
    expect(find.text('저장하지 못했어요. 다시 시도해 주세요'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('단어 5개 저장'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });
}
