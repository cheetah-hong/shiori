// C9: a page read with the row template, now with evidence, on the review
// screen: each cell's source and pairing confidence, the piece of the page
// behind it, "높음 전체 승인" for the high entries only and "높음 N" in the
// summary — and everything the template review already did (word numbers,
// headword candidates, editing a cell, "확인 필요" and the cell marks) still
// works. Invented words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

PhotoBox _box(double x, double y) =>
    PhotoBox(x: x, y: y, width: 0.06, height: 0.02);

FieldEvidence _photo(double x, double y, [PairConfidence? c]) => FieldEvidence(
  source: FieldSource.photo,
  confidence: c,
  boxes: [_box(x, y)],
);

CapturedEntry _row(
  String no,
  String headword, {
  List<String> readings = const ['よみ'],
  String meaning = '뜻',
  List<EntryIssue> issues = const [],
  List<String> candidates = const [],
  required Map<EntryField, FieldEvidence> fields,
}) => CapturedEntry(
  no: no,
  headword: headword,
  readings: readings,
  pos: PartOfSpeech.noun,
  meaning: meaning,
  issues: issues,
  headwordCandidates: candidates,
  ocrHeadword: headword,
  evidence: EntryEvidence(origin: WordOrigin.wordList, fields: fields),
);

/// 雨 high on both cells, 雪 with a medium meaning, an unread headword with
/// candidates, 到着 with a meaning that looks cut (low).
CaptureDraft _draft() => CaptureDraft(
  templateId: 'vocab.list',
  meta: const PageMeta(day: 1, title: '날씨', page: 10),
  route: chooseRoute(
    const TemplateFit(
      entries: 4,
      numberedRows: 4,
      duplicateNumbers: 0,
      missingMeanings: 0,
      missingReadings: 0,
      missingHeadwords: 1,
      numberOrder: 1,
      columnsMeasured: true,
    ),
  ),
  entries: [
    _row(
      '0001',
      '雨',
      readings: const ['あめ'],
      meaning: '비',
      fields: {
        EntryField.headword: _photo(0.10, 0.10),
        EntryField.readings: _photo(0.20, 0.10, PairConfidence.high),
        EntryField.meaning: _photo(0.40, 0.10, PairConfidence.high),
      },
    ),
    _row(
      '0002',
      '雪',
      readings: const ['ゆき'],
      meaning: '하양',
      fields: {
        EntryField.headword: _photo(0.10, 0.15),
        EntryField.readings: _photo(0.20, 0.15, PairConfidence.high),
        EntryField.meaning: _photo(0.40, 0.15, PairConfidence.medium),
      },
    ),
    _row(
      '0003',
      '',
      readings: const ['ひ'],
      meaning: '해',
      issues: const [EntryIssue.missing(EntryField.headword)],
      candidates: const ['日', '火'],
      fields: {
        EntryField.headword: const FieldEvidence(source: FieldSource.photo),
        EntryField.readings: _photo(0.20, 0.20, PairConfidence.medium),
        EntryField.meaning: _photo(0.40, 0.20, PairConfidence.medium),
      },
    ),
    _row(
      '0004',
      '到着',
      readings: const ['とうちゃく'],
      meaning: '도착,',
      issues: const [
        EntryIssue.suspect(EntryField.meaning, note: '뜻 끝이 잘렸을 수 있음'),
      ],
      fields: {
        EntryField.headword: _photo(0.10, 0.25),
        EntryField.readings: _photo(0.20, 0.25, PairConfidence.high),
        EntryField.meaning: _photo(0.40, 0.25, PairConfidence.low),
      },
    ),
  ],
);

/// The page as the two OCR passes read it (drawn when there is no photo).
OcrScan _scan() => OcrScan(
  japanese: OcrPage(
    lines: const [
      OcrLine(text: '0001 雨 あめ', x: 0.05, y: 0.10, width: 0.25, height: 0.02),
    ],
  ),
  korean: OcrPage(
    lines: const [
      OcrLine(text: '비', x: 0.40, y: 0.10, width: 0.06, height: 0.02),
    ],
  ),
);

Future<void> _pump(WidgetTester tester, {bool approval = true}) async {
  usePhoneSize(tester);
  await tester.pumpWidget(
    screen(
      TestBlocks(),
      ReviewScreen(draft: _draft(), scan: _scan()),
      extra: [highConfidenceApprovalProvider.overrideWithValue(approval)],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('each cell names its source and its pairing confidence', (
    tester,
  ) async {
    await _pump(tester);
    final semantics = tester.ensureSemantics();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('source-0-readings')),
        matching: find.text('사진'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('confidence-0-meaning')),
        matching: find.text('높음'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('뜻 짝 신뢰도 높음'), findsOneWidget);
    await _show(tester, find.byKey(const ValueKey('confidence-1-meaning')));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('confidence-1-meaning')),
        matching: find.text('중간'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('tapping a cell\'s evidence shows the piece of the page', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('cell-0-meaning')));
    await tester.pumpAndSettle();

    expect(find.text('근거 조각'), findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-crop')), findsWidgets);
  });

  testWidgets('the summary counts the high entries', (tester) async {
    await _pump(tester);

    expect(find.text('높음 1'), findsOneWidget);
  });

  testWidgets('"높음 전체 승인" confirms only the high entries', (tester) async {
    await _pump(tester);

    expect(find.text('확인됨'), findsNothing);
    await tester.tap(find.text('높음 전체 승인'));
    await tester.pumpAndSettle();

    expect(find.text('확인됨'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('entry-0001-0')),
        matching: find.text('확인됨'),
      ),
      findsOneWidget,
    );
    expect(find.text('높음 1'), findsOneWidget, reason: 'the count stays');
  });

  testWidgets('"높음 전체 승인" stays behind its switch', (tester) async {
    await _pump(tester, approval: false);

    expect(find.text('높음 전체 승인'), findsNothing);
  });

  testWidgets('what the template review did still works: numbers, flags, '
      'marks', (tester) async {
    await _pump(tester);

    expect(find.text('0001'), findsOneWidget);
    expect(find.text('0002'), findsOneWidget);
    expect(find.text('확인 필요 2'), findsWidgets);
    await _show(tester, find.text('도착,'));
    expect(find.byKey(const ValueKey('mark-meaning-suspect')), findsOneWidget);
    expect(find.text('확인 필요'), findsWidgets);
  });

  testWidgets('an unread headword still offers its candidates', (tester) async {
    await _pump(tester);
    final chip = find.widgetWithText(ActionChip, '日');
    await _show(tester, chip);

    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, '日'), findsNothing);
    expect(find.text('日'), findsOneWidget);
    expect(find.text('확인 필요 1'), findsWidgets);
  });

  testWidgets('tapping the word still opens the editor; 고치기 keeps the '
      'value and clears the flag', (tester) async {
    await _pump(tester);
    await _show(tester, find.text('도착,'));

    await tester.tap(find.text('도착,'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '고치기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mark-meaning-suspect')), findsNothing);
    expect(find.text('도착,'), findsOneWidget);
    expect(find.text('확인 필요 1'), findsWidgets);
  });
}
