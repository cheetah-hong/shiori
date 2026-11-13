// V11: "판독 기록 내보내기" also where a photo gave no review screen. When the
// page was read but no word came out of it, or the extractor stopped with an
// error, the failure note offers the same export as the review screen: both
// OCR passes in the recorded-fixture format (`<name>.ja.json`,
// `<name>.ko.json`), never the photo, only in builds that are not release
// builds. When the page could not be read there is nothing to export.
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/capture/ocr_export.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

const String _noWords =
    '이 사진에서 단어를 찾지 못했어요. 페이지 전체가 화면에 들어오게, 밝은 곳에서 똑바로 찍어 주세요.';
const String _extractorFailed = '단어를 정리하다가 문제가 생겼어요. 다시 시도해 주세요.';
const String _export = '판독 기록 내보내기';

final class _Camera implements ImageSource {
  @override
  Future<PageImage?> pick(ImageOrigin origin) async =>
      const PageImage('page.jpg');

  @override
  Future<void> discard(PageImage image) async {}
}

/// A page with Korean on it and nothing Japanese: read, but no word.
const OcrScan _koreanOnly = OcrScan(
  japanese: OcrPage(lines: [], engine: 'test', languages: ['ja-JP', 'ko-KR']),
  korean: _korean,
);

/// A page with a kanji on it: the extractor looks it up.
const OcrScan _withKanji = OcrScan(
  japanese: OcrPage(
    lines: [OcrLine(text: '雪', x: 0.1, y: 0.3, width: 0.03, height: 0.03)],
    engine: 'test',
    languages: ['ja-JP', 'ko-KR'],
  ),
  korean: _korean,
);

const OcrPage _korean = OcrPage(
  lines: [OcrLine(text: '안녕하세요', x: 0.1, y: 0.1, width: 0.2, height: 0.02)],
  engine: 'test',
  languages: ['ko-KR', 'ja-JP'],
);

final class _Recognizer implements TextRecognizer {
  _Recognizer(this.result);

  final Future<OcrScan> Function() result;

  @override
  String get id => 'test';

  @override
  Future<OcrScan> recognize(PageImage image) => result();
}

/// A lexicon with a bug in it: the extractor stops on its first lookup.
final class _BuggyLexicon implements Lexicon {
  @override
  Future<Map<String, List<LexiconEntry>>> lookup(Iterable<String> forms) =>
      Future.error(StateError('bug'));
}

Future<List<ExportFile>> _capture(
  WidgetTester tester, {
  required TextRecognizer recognizer,
  bool exportEnabled = true,
  bool buggyExtractor = false,
}) async {
  usePhoneSize(tester);
  final shared = <ExportFile>[];
  await tester.pumpWidget(
    app(
      TestBlocks(),
      extra: [
        imageSourceProvider.overrideWithValue(_Camera()),
        textRecognizerProvider.overrideWithValue(recognizer),
        ocrExportProvider.overrideWithValue(
          OcrExport(
            enabled: exportEnabled,
            share: (files) async => shared.addAll(files),
          ),
        ),
        if (buggyExtractor)
          generalExtractorProvider.overrideWithValue(
            GeneralExtractor(lexicon: _BuggyLexicon()),
          ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('페이지 등록'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('카메라로 찍기'));
  await tester.pumpAndSettle();
  return shared;
}

/// The two files read back as [scan]'s lines.
Future<void> _sameAs(
  WidgetTester tester,
  List<ExportFile> files,
  OcrScan scan,
) async {
  expect(files, hasLength(2));
  final byName = {for (final f in files) f.name: f.text};
  final ja = byName.keys.singleWhere((n) => n.endsWith('.ja.json'));
  final name = ja.substring(0, ja.length - '.ja.json'.length);
  expect(byName.keys.toSet(), {'$name.ja.json', '$name.ko.json'});
  final again = (await tester.runAsync(
    () => FixtureTextRecognizer(
      (n) async => byName[n]!,
    ).recognize(PageImage(name)),
  ))!;
  for (final (a, b) in [
    (scan.japanese, again.japanese),
    (scan.korean, again.korean),
  ]) {
    expect(b.lines, hasLength(a.lines.length));
    for (final (i, l) in a.lines.indexed) {
      final m = b.lines[i];
      expect(
        (m.text, m.confidence, m.x, m.y, m.width, m.height),
        (l.text, l.confidence, l.x, l.y, l.width, l.height),
      );
    }
  }
  for (final f in files) {
    expect(f.name, endsWith('.json'));
  }
}

void main() {
  testWidgets('no word on a page that was read: the failure note exports '
      'both passes', (tester) async {
    final shared = await _capture(
      tester,
      recognizer: _Recognizer(() async => _koreanOnly),
    );
    expect(find.text(_noWords), findsOneWidget);
    expect(find.text(_export), findsOneWidget);

    await tester.tap(find.text(_export));
    await tester.pump();
    await _sameAs(tester, shared, _koreanOnly);
  });

  testWidgets('the extractor stopped with an error after the page was read: '
      'the failure note exports both passes', (tester) async {
    final shared = await _capture(
      tester,
      recognizer: _Recognizer(() async => _withKanji),
      buggyExtractor: true,
    );
    expect(tester.takeException(), isStateError);
    expect(find.text(_extractorFailed), findsOneWidget);
    expect(find.text(_export), findsOneWidget);

    await tester.tap(find.text(_export));
    await tester.pump();
    await _sameAs(tester, shared, _withKanji);
  });

  testWidgets('the page could not be read: nothing to export', (tester) async {
    await _capture(
      tester,
      recognizer: _Recognizer(
        () => Future.error(const TextRecognitionException('읽지 못했어요')),
      ),
    );
    expect(find.text('읽지 못했어요'), findsOneWidget);
    expect(find.text(_export), findsNothing);
  });

  testWidgets('a release build: no export on the failure note', (tester) async {
    await _capture(
      tester,
      recognizer: _Recognizer(() async => _koreanOnly),
      exportEnabled: false,
    );
    expect(find.text(_noWords), findsOneWidget);
    expect(find.text(_export), findsNothing);
  });

  testWidgets('a share sheet that fails says so', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      app(
        TestBlocks(),
        extra: [
          imageSourceProvider.overrideWithValue(_Camera()),
          textRecognizerProvider.overrideWithValue(
            _Recognizer(() async => _koreanOnly),
          ),
          ocrExportProvider.overrideWithValue(
            OcrExport(
              enabled: true,
              share: (files) async => throw Exception('no share sheet'),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카메라로 찍기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_export));
    await tester.pumpAndSettle();
    expect(find.text('판독 기록을 내보내지 못했어요'), findsOneWidget);
  });
}
