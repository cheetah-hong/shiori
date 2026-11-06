// D4: when a bundled dictionary does not open (damaged or failed), the
// capture, review and 정보 screens say so and offer 「다시 시도」; the study
// screen goes on as usual. A build without the assets says nothing there.
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori/features/about/about_screen.dart';
import 'package:shiori/features/capture/capture_screen.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori/shared/dictionary_notice.dart';

import '../support/dictionary.dart';
import '../support/glossary.dart';
import '../support/harness.dart';

const _damaged = BundledDictionary.unavailable(
  'UnpackedAssetMismatch: sqliteSha256',
  problemKind: DictionaryProblem.damaged,
);
const _failed = BundledGlossary.unavailable(
  'FileSystemException: no space left',
  problemKind: DictionaryProblem.failed,
);

Future<void> _openCapture(WidgetTester tester, TestBlocks blocks) async {
  await tester.pumpWidget(app(blocks));
  await tester.pumpAndSettle();
  await tester.tap(find.text('페이지 등록'));
  await tester.pumpAndSettle();
  expect(find.byType(CaptureScreen), findsOneWidget);
}

void main() {
  testWidgets('capture: a damaged dictionary — the notice and 「다시 시도」', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks()..dictionary = _damaged;
    await _openCapture(tester, blocks);
    expect(find.text(DictionaryNoticeText.title), findsOneWidget);
    expect(find.text(DictionaryNoticeText.damaged), findsOneWidget);
    expect(find.text(DictionaryNoticeText.failed), findsNothing);
    expect(find.text(DictionaryNoticeText.retry), findsOneWidget);
    // The page can still be read.
    expect(find.text('카메라로 찍기'), findsOneWidget);
  });

  testWidgets('capture: a glossary that failed to unpack — the other wording', (
    tester,
  ) async {
    usePhoneSize(tester);
    final opened = BundledDictionary.opened(openMiniJmdict(), testEdition);
    addTearDown(opened.close);
    final blocks = TestBlocks()
      ..dictionary = opened
      ..glossary = _failed;
    await _openCapture(tester, blocks);
    expect(find.text(DictionaryNoticeText.title), findsOneWidget);
    expect(find.text(DictionaryNoticeText.failed), findsOneWidget);
    expect(find.text(DictionaryNoticeText.damaged), findsNothing);
  });

  testWidgets('damaged wins over failed when both are wrong', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks()
      ..dictionary = _damaged
      ..glossary = _failed;
    await _openCapture(tester, blocks);
    expect(find.text(DictionaryNoticeText.damaged), findsOneWidget);
    expect(find.text(DictionaryNoticeText.failed), findsNothing);
  });

  testWidgets('a build without the assets shows no notice', (tester) async {
    usePhoneSize(tester);
    await _openCapture(tester, TestBlocks());
    expect(find.text(DictionaryNoticeText.title), findsNothing);
    expect(find.text(DictionaryNoticeText.retry), findsNothing);
  });

  testWidgets('both open: no notice', (tester) async {
    usePhoneSize(tester);
    final dictionary = BundledDictionary.opened(openMiniJmdict(), testEdition);
    addTearDown(dictionary.close);
    final glossary = BundledGlossary.opened(
      openMiniKrdict(),
      testGlossaryEdition,
    );
    addTearDown(glossary.close);
    final blocks = TestBlocks()
      ..dictionary = dictionary
      ..glossary = glossary;
    await _openCapture(tester, blocks);
    expect(find.text(DictionaryNoticeText.title), findsNothing);
  });

  testWidgets('「다시 시도」 opens the dictionaries again; when they open the '
      'notice goes and the app says so', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks()..dictionary = _damaged;
    await _openCapture(tester, blocks);
    expect(find.text(DictionaryNoticeText.title), findsOneWidget);

    final opened = BundledDictionary.opened(openMiniJmdict(), testEdition);
    addTearDown(opened.close);
    blocks.dictionary = opened;
    await tester.tap(find.text(DictionaryNoticeText.retry));
    await tester.pumpAndSettle();
    expect(find.text(DictionaryNoticeText.title), findsNothing);
    expect(find.text(DictionaryNoticeText.opened), findsOneWidget);
  });

  testWidgets('「다시 시도」 that fails again keeps the notice', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks()..dictionary = _damaged;
    await _openCapture(tester, blocks);
    await tester.tap(find.text(DictionaryNoticeText.retry));
    await tester.pumpAndSettle();
    expect(find.text(DictionaryNoticeText.title), findsOneWidget);
    expect(find.text(DictionaryNoticeText.retry), findsOneWidget);
    expect(find.text(DictionaryNoticeText.opened), findsNothing);
  });

  testWidgets('review: a page read without the dictionary says so, with '
      '「다시 시도」, and its words are listed', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks()..dictionary = _damaged;
    await _openCapture(tester, blocks);
    await tester.ensureVisible(find.text('DAY 01 자연, 몸').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAY 01 자연, 몸').first);
    await tester.pumpAndSettle();

    expect(find.text('검토'), findsOneWidget);
    expect(find.text(DictionaryNoticeText.reviewSummary), findsOneWidget);
    expect(find.text(DictionaryNoticeText.retry), findsOneWidget);
    expect(find.textContaining(RegExp(r'^단어 \d+개 추가$')), findsOneWidget);
  });

  testWidgets('review: no notice with the dictionaries open', (tester) async {
    usePhoneSize(tester);
    final dictionary = BundledDictionary.opened(openMiniJmdict(), testEdition);
    addTearDown(dictionary.close);
    final blocks = TestBlocks()..dictionary = dictionary;
    await _openCapture(tester, blocks);
    await tester.ensureVisible(find.text('DAY 01 자연, 몸').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAY 01 자연, 몸').first);
    await tester.pumpAndSettle();
    expect(find.text('검토'), findsOneWidget);
    expect(find.text(DictionaryNoticeText.reviewSummary), findsNothing);
  });

  testWidgets('study goes on as usual with a damaged dictionary', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks()
      ..dictionary = _damaged
      ..glossary = _failed;
    await blocks.seedPage('s140');
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
    expect(find.byType(StudyScreen), findsOneWidget);
    expect(find.text('뜻 보기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('정보: a damaged dictionary is not called missing, and can be '
      'opened again', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks()..dictionary = _damaged;
    await tester.pumpWidget(screen(blocks, const AboutScreen()));
    await tester.pumpAndSettle();
    expect(find.text(DictionaryNoticeText.damaged), findsOneWidget);
    expect(find.text(DictionaryNoticeText.retry), findsWidgets);
    expect(find.textContaining('사전 데이터가 들어 있지 않아요'), findsNothing);

    final opened = BundledDictionary.opened(openMiniJmdict(), testEdition);
    addTearDown(opened.close);
    blocks.dictionary = opened;
    await tester.tap(find.text(DictionaryNoticeText.retry).first);
    await tester.pumpAndSettle();
    expect(find.text(DictionaryNoticeText.damaged), findsNothing);
    expect(
      find.textContaining('This application uses the JMdict dictionary files'),
      findsOneWidget,
    );
  });
}
