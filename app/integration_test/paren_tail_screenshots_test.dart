// Bracketed readings with an ending or an honorific, a page of two rows and
// the failure note's export on a simulator, with the real dictionaries.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/paren_tail_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. Needs app/assets/dict/. The pages
// are the synthetic g40 and g41 (tools/synthetic/make_general_pages.py)
// and an invented page with no Japanese, handed in as a camera photo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

final class _Camera implements ImageSource {
  @override
  Future<PageImage?> pick(ImageOrigin origin) async =>
      const PageImage('page.jpg');

  @override
  Future<void> discard(PageImage image) async {}
}

final class _Recognizer implements TextRecognizer {
  _Recognizer(this.scan);

  final OcrScan scan;

  @override
  String get id => 'synthetic';

  @override
  Future<OcrScan> recognize(PageImage image) async => scan;
}

/// A lexicon with a bug in it: the extractor stops on its first lookup.
final class _BuggyLexicon implements Lexicon {
  @override
  Future<Map<String, List<LexiconEntry>>> lookup(Iterable<String> forms) =>
      Future.error(StateError('bug'));
}

OcrScan _scan(List<OcrLine> ja, List<OcrLine> ko) => OcrScan(
  japanese: OcrPage(lines: ja, engine: 'synthetic', languages: const ['ja']),
  korean: OcrPage(lines: ko, engine: 'synthetic', languages: const ['ko']),
);

const List<OcrLine> _noJapanese = [];
const List<OcrLine> _koreanOnly = [
  OcrLine(text: '오늘은 날씨가 맑습니다', x: 0.1, y: 0.2, width: 0.5, height: 0.03),
];

const List<OcrLine> _g40Ja = [
  OcrLine(
    text: '□ 親切(しんせつ)だ',
    x: 0.15,
    y: 0.1092,
    width: 0.2035,
    height: 0.019,
    confidence: 0.5,
  ),
  OcrLine(
    text: 'DMPs',
    x: 0.552,
    y: 0.1122,
    width: 0.042,
    height: 0.0135,
    confidence: 0.3,
  ),
  OcrLine(
    text: '□ 有名(ゆうめい)だ',
    x: 0.15,
    y: 0.1553,
    width: 0.2035,
    height: 0.019,
    confidence: 0.3,
  ),
  OcrLine(
    text: '弓彐彐',
    x: 0.5496,
    y: 0.1583,
    width: 0.042,
    height: 0.0135,
    confidence: 0.3,
  ),
  OcrLine(
    text: '□ 新(あたら)しい',
    x: 0.15,
    y: 0.2,
    width: 0.185,
    height: 0.019,
    confidence: 0.5,
  ),
  OcrLine(
    text: '□ 練習(れんしゅう)する',
    x: 0.15,
    y: 0.2454,
    width: 0.2405,
    height: 0.019,
    confidence: 0.5,
  ),
  OcrLine(
    text: '叉冂叉',
    x: 0.5508,
    y: 0.2484,
    width: 0.042,
    height: 0.0135,
    confidence: 0.3,
  ),
  OcrLine(
    text: '□ お茶(ちゃ)',
    x: 0.15,
    y: 0.2904,
    width: 0.148,
    height: 0.019,
    confidence: 0.5,
  ),
  OcrLine(
    text: '冂',
    x: 0.5517,
    y: 0.2934,
    width: 0.0105,
    height: 0.0135,
    confidence: 0.3,
  ),
  OcrLine(
    text: '□ ご飯(はん)',
    x: 0.15,
    y: 0.3349,
    width: 0.148,
    height: 0.019,
    confidence: 1.0,
  ),
  OcrLine(
    text: '丫',
    x: 0.5496,
    y: 0.3379,
    width: 0.0105,
    height: 0.0135,
    confidence: 0.3,
  ),
  OcrLine(
    text: '□ 走(はし)る',
    x: 0.15,
    y: 0.3806,
    width: 0.148,
    height: 0.019,
    confidence: 0.5,
  ),
  OcrLine(
    text: 'OYX',
    x: 0.5516,
    y: 0.3836,
    width: 0.0315,
    height: 0.0135,
    confidence: 0.3,
  ),
  OcrLine(
    text: '□ 学校(がっこう)',
    x: 0.15,
    y: 0.4251,
    width: 0.185,
    height: 0.019,
    confidence: 1.0,
  ),
  OcrLine(
    text: '朝、公園（こうえん）で弁当を作ります。',
    x: 0.15,
    y: 0.49,
    width: 0.3268,
    height: 0.019,
    confidence: 1.0,
  ),
];

const List<OcrLine> _g40Ko = [
  OcrLine(
    text: '단어',
    x: 0.16,
    y: 0.06,
    width: 0.021,
    height: 0.018,
    confidence: 1.0,
  ),
  OcrLine(
    text: '2Dz2PA',
    x: 0.15,
    y: 0.1092,
    width: 0.2035,
    height: 0.019,
    confidence: 0.3,
  ),
  OcrLine(
    text: '친절하다',
    x: 0.552,
    y: 0.1122,
    width: 0.042,
    height: 0.0135,
    confidence: 1.0,
  ),
  OcrLine(
    text: '미바(Ah)',
    x: 0.15,
    y: 0.1553,
    width: 0.2035,
    height: 0.019,
    confidence: 0.5,
  ),
  OcrLine(
    text: '유명하다',
    x: 0.5496,
    y: 0.1583,
    width: 0.042,
    height: 0.0135,
    confidence: 1.0,
  ),
  OcrLine(
    text: 'KJLyb3',
    x: 0.15,
    y: 0.2,
    width: 0.185,
    height: 0.019,
    confidence: 0.3,
  ),
  OcrLine(
    text: '새롭다',
    x: 0.5506,
    y: 0.203,
    width: 0.0315,
    height: 0.0135,
    confidence: 1.0,
  ),
  OcrLine(
    text: 'K0kaFV',
    x: 0.15,
    y: 0.2454,
    width: 0.2405,
    height: 0.019,
    confidence: 0.5,
  ),
  OcrLine(
    text: '연습하다',
    x: 0.5508,
    y: 0.2484,
    width: 0.042,
    height: 0.0135,
    confidence: 0.5,
  ),
  OcrLine(
    text: 'asxV5b',
    x: 0.15,
    y: 0.2904,
    width: 0.148,
    height: 0.019,
    confidence: 0.5,
  ),
  OcrLine(
    text: '차',
    x: 0.5517,
    y: 0.2934,
    width: 0.0105,
    height: 0.0135,
    confidence: 0.5,
  ),
  OcrLine(
    text: '5n7',
    x: 0.15,
    y: 0.3349,
    width: 0.148,
    height: 0.019,
    confidence: 0.3,
  ),
  OcrLine(
    text: '밥',
    x: 0.5496,
    y: 0.3379,
    width: 0.0105,
    height: 0.0135,
    confidence: 1.0,
  ),
  OcrLine(
    text: 'yzT3',
    x: 0.15,
    y: 0.3806,
    width: 0.148,
    height: 0.019,
    confidence: 0.3,
  ),
  OcrLine(
    text: '달리다',
    x: 0.5516,
    y: 0.3836,
    width: 0.0315,
    height: 0.0135,
    confidence: 1.0,
  ),
  OcrLine(
    text: 'Wb34',
    x: 0.15,
    y: 0.4251,
    width: 0.185,
    height: 0.019,
    confidence: 0.5,
  ),
  OcrLine(
    text: '학교',
    x: 0.551,
    y: 0.4281,
    width: 0.021,
    height: 0.0135,
    confidence: 0.5,
  ),
  OcrLine(
    text: 'znK',
    x: 0.15,
    y: 0.49,
    width: 0.3268,
    height: 0.019,
    confidence: 0.5,
  ),
];

const List<OcrLine> _g41Ja = [
  OcrLine(
    text: 'ロ親切（しんせつ）だ',
    x: 0.082,
    y: 0.145,
    width: 0.284,
    height: 0.217,
    confidence: 0.5,
  ),
  OcrLine(
    text: 'ロ有名（ゆうめい）だ',
    x: 0.083,
    y: 0.563,
    width: 0.324,
    height: 0.213,
    confidence: 0.3,
  ),
];

const List<OcrLine> _g41Ko = [
  OcrLine(
    text: '미x1t(Sht)',
    x: 0.082,
    y: 0.145,
    width: 0.284,
    height: 0.217,
    confidence: 0.5,
  ),
  OcrLine(
    text: '친절하다',
    x: 0.684,
    y: 0.171,
    width: 0.15,
    height: 0.192,
    confidence: 0.5,
  ),
  OcrLine(
    text: '0바오(~h)))te',
    x: 0.083,
    y: 0.563,
    width: 0.324,
    height: 0.213,
    confidence: 0.5,
  ),
  OcrLine(
    text: '유명하다 !',
    x: 0.683,
    y: 0.585,
    width: 0.183,
    height: 0.189,
    confidence: 0.5,
  ),
];
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps until [finder] shows up (unpacking takes a few seconds).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  /// The index of the review card that shows [headword].
  int entryIndex(String headword) {
    final card = find.ancestor(
      of: find.text(headword),
      matching: find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('entry-'),
      ),
    );
    final key = card.evaluate().single.widget.key! as ValueKey<String>;
    return int.parse(key.value.substring('entry-'.length));
  }

  /// The app with [scan] as the camera's photo, the dictionaries unpacked.
  Future<void> photograph(
    WidgetTester tester,
    OcrScan scan, {
    List<Override> extra = const [],
  }) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          imageSourceProvider.overrideWithValue(_Camera()),
          textRecognizerProvider.overrideWithValue(_Recognizer(scan)),
          ...extra,
        ],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('JMdict 날짜'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카메라로 찍기'));
    await tester.pumpAndSettle();
  }

  testWidgets('no word on a page that was read: the export on the failure '
      'note', (tester) async {
    await photograph(tester, _scan(_noJapanese, _koreanOnly));
    await waitFor(tester, find.text('판독 기록 내보내기'));
    expect(find.textContaining('단어를 찾지 못했어요'), findsOneWidget);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('110_capture_no_words_export');
  });

  testWidgets('the extractor stopped: the export on the failure note', (
    tester,
  ) async {
    await photograph(
      tester,
      _scan(_g41Ja, _g41Ko),
      extra: [
        generalExtractorProvider.overrideWithValue(
          GeneralExtractor(lexicon: _BuggyLexicon()),
        ),
      ],
    );
    expect(tester.takeException(), isStateError);
    await waitFor(tester, find.text('판독 기록 내보내기'));
    expect(find.textContaining('단어를 정리하다가'), findsOneWidget);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('111_capture_extractor_error_export');
  });

  testWidgets('two rows cut out of a word list: both words', (tester) async {
    await photograph(tester, _scan(_g41Ja, _g41Ko));
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));
    expect(find.text('親切だ'), findsOneWidget);
    expect(find.text('有名だ'), findsOneWidget);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('112_review_two_rows');

    final i = entryIndex('有名だ');
    await tester.tap(find.byKey(ValueKey('cell-$i-readings')));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('근거 조각'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('113_evidence_lowest_reading');
  });

  testWidgets('a word box with endings and honorifics', (tester) async {
    await photograph(tester, _scan(_g40Ja, _g40Ko));
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));
    expect(find.text('親切だ'), findsOneWidget);
    final honorific = find.text('お茶');
    await tester.scrollUntilVisible(honorific, 200);
    await Scrollable.ensureVisible(tester.element(honorific), alignment: 0.3);
    await tester.pumpAndSettle();
    expect(find.text('練習'), findsOneWidget);
    await binding.takeScreenshot('114_review_endings_honorifics');
  });
}
