// E8: the review screen for the word extractor's words — where each cell
// came from, how sure its pairing is, the photo piece behind it, candidates,
// the tray of unpaired fragments, sentence words with their sentence, and
// "높음 전체 승인" behind its switch.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

PhotoBox _box(double y) => PhotoBox(x: 0.10, y: y, width: 0.12, height: 0.02);

FieldEvidence _photo(
  double y, [
  PairConfidence? c,
  List<String> more = const [],
]) => FieldEvidence(
  source: FieldSource.photo,
  confidence: c,
  boxes: [_box(y)],
  candidates: more,
);

CapturedEntry _word({
  required String headword,
  required List<String> readings,
  required String meaning,
  required Map<EntryField, FieldEvidence> fields,
  WordOrigin origin = WordOrigin.wordList,
  Example? example,
  List<EntryIssue> issues = const [],
}) => CapturedEntry(
  headword: headword,
  readings: readings,
  pos: PartOfSpeech.noun,
  meaning: meaning,
  example: example,
  issues: issues,
  evidence: EntryEvidence(origin: origin, fields: fields),
);

Fragment _fragment(int id, String text, FragmentKind kind, double y) =>
    Fragment(
      id: id,
      text: text,
      kind: kind,
      x: 0.5,
      y: y,
      width: 0.1,
      height: 0.02,
      pass: kind == FragmentKind.hangul ? OcrPass.korean : OcrPass.japanese,
    );

/// 運動 high, 部屋 from the dictionary, 食べる low with candidates, 学校 from
/// a sentence; two unpaired fragments; 図書館 skipped as known.
CaptureDraft _draft() => CaptureDraft(
  entries: [
    _word(
      headword: '運動',
      readings: const ['うんどう'],
      meaning: '운동',
      fields: {
        EntryField.headword: _photo(0.10),
        EntryField.readings: _photo(0.10, PairConfidence.high),
        EntryField.meaning: _photo(0.10, PairConfidence.high),
      },
    ),
    _word(
      headword: '部屋',
      readings: const ['へや'],
      meaning: '방',
      fields: {
        EntryField.headword: _photo(0.20),
        EntryField.readings: _photo(0.20, PairConfidence.medium),
        EntryField.meaning: const FieldEvidence(
          source: FieldSource.dictionary,
          confidence: PairConfidence.medium,
          note: '사전 뜻: 한국어기초사전',
        ),
      },
      issues: const [EntryIssue.inferred(EntryField.meaning, note: '사전 뜻')],
    ),
    _word(
      headword: '食べる',
      readings: const ['たべる'],
      meaning: '먹다',
      fields: {
        EntryField.headword: _photo(0.30),
        EntryField.readings: _photo(0.30, PairConfidence.medium),
        EntryField.meaning: _photo(0.30, PairConfidence.low, const ['들다']),
      },
      issues: const [EntryIssue.suspect(EntryField.meaning, note: 'pair low')],
    ),
    _word(
      headword: '学校',
      readings: const ['がっこう'],
      meaning: '학교',
      origin: WordOrigin.sentence,
      example: const Example(ja: '学校まで走った。', ko: '학교까지 달렸다.'),
      fields: {
        EntryField.headword: _photo(0.40),
        EntryField.readings: const FieldEvidence(
          source: FieldSource.dictionary,
          confidence: PairConfidence.medium,
        ),
        EntryField.meaning: const FieldEvidence(
          source: FieldSource.dictionary,
          confidence: PairConfidence.medium,
        ),
      },
    ),
  ],
  unpaired: [
    _fragment(20, '산책', FragmentKind.hangul, 0.60),
    _fragment(21, '散歩', FragmentKind.kanjiWord, 0.70),
  ],
  skippedKnown: const ['図書館'],
);

/// The page as the two OCR passes read it (drawn when there is no photo).
OcrScan _scan() => OcrScan(
  japanese: OcrPage(
    lines: const [
      OcrLine(text: '運動', x: 0.10, y: 0.10, width: 0.12, height: 0.02),
      OcrLine(text: '散歩', x: 0.50, y: 0.70, width: 0.10, height: 0.02),
    ],
  ),
  korean: OcrPage(
    lines: const [
      OcrLine(text: '운동', x: 0.45, y: 0.10, width: 0.08, height: 0.02),
    ],
  ),
);

Future<void> _pump(WidgetTester tester, {bool approval = false}) async {
  usePhoneSize(tester);
  final blocks = TestBlocks();
  await tester.pumpWidget(
    screen(
      blocks,
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
  testWidgets('summary: the words skipped as known', (tester) async {
    await _pump(tester);

    expect(find.text('이미 있는 단어 1개 건너뜀'), findsOneWidget);
  });

  testWidgets('each cell names its source: 사진 or 사전', (tester) async {
    await _pump(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('source-0-meaning')),
        matching: find.text('사진'),
      ),
      findsOneWidget,
    );
    await _show(tester, find.byKey(const ValueKey('source-1-meaning')));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('source-1-meaning')),
        matching: find.text('사전'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('confidence in three steps, in words and for screen readers', (
    tester,
  ) async {
    await _pump(tester);
    final semantics = tester.ensureSemantics();

    expect(find.bySemanticsLabel('뜻 짝 신뢰도 높음'), findsOneWidget);
    expect(find.text('높음'), findsWidgets);
    await _show(tester, find.byKey(const ValueKey('confidence-2-meaning')));
    expect(find.bySemanticsLabel('뜻 짝 신뢰도 낮음'), findsOneWidget);
    expect(find.text('낮음'), findsWidgets);
    expect(find.text('중간'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('tapping a cell shows the piece of the page it came from', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('cell-0-meaning')));
    await tester.pumpAndSettle();

    expect(find.text('근거 조각'), findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-crop')), findsWidgets);
  });

  testWidgets('a candidate chip replaces the cell', (tester) async {
    await _pump(tester);
    final chip = find.byKey(const ValueKey('candidate-2-meaning-들다'));
    await _show(tester, chip);

    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('들다'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('candidate-2-meaning-먹다')),
      findsOneWidget,
    );
  });

  testWidgets('an unpaired fragment goes onto an entry\'s meaning cell', (
    tester,
  ) async {
    await _pump(tester);
    final chip = find.byKey(const ValueKey('fragment-20'));
    await _show(tester, chip);
    expect(find.text('짝 없는 조각 2'), findsOneWidget);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-field-meaning')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-entry-1')));
    await tester.pumpAndSettle();

    await _show(tester, find.byKey(const ValueKey('cell-1-meaning')));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cell-1-meaning')),
        matching: find.text('산책'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('fragment-20')), findsNothing);
    expect(find.text('짝 없는 조각 1'), findsOneWidget);
  });

  testWidgets('an unpaired fragment becomes a new entry', (tester) async {
    await _pump(tester);
    final chip = find.byKey(const ValueKey('fragment-21'));
    await _show(tester, chip);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-entry-from-fragment')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fragment-21')), findsNothing);
    await _show(tester, find.byKey(const ValueKey('cell-4-headword')));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cell-4-headword')),
        matching: find.text('散歩'),
      ),
      findsOneWidget,
    );
    expect(find.text('단어 5개 저장'), findsOneWidget);
  });

  testWidgets('a sentence word shows its sentence and translation', (
    tester,
  ) async {
    await _pump(tester);
    await _show(tester, find.text('学校まで走った。'));

    expect(find.text('学校まで走った。'), findsOneWidget);
    expect(find.text('학교까지 달렸다.'), findsOneWidget);
    expect(find.text('문장에서'), findsOneWidget);
  });

  testWidgets('"높음 전체 승인" is hidden while its switch is off', (tester) async {
    await _pump(tester);

    expect(find.text('높음 전체 승인'), findsNothing);
  });

  testWidgets('"높음 전체 승인" confirms only the high entries', (tester) async {
    await _pump(tester, approval: true);

    expect(find.text('확인됨'), findsNothing);
    await tester.tap(find.text('높음 전체 승인'));
    await tester.pumpAndSettle();

    expect(find.text('확인됨'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('entry-0')),
        matching: find.text('확인됨'),
      ),
      findsOneWidget,
    );
  });
}
