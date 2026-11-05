// The review screen's marks: dictionary candidates, "사전에 없음", and guesses
// shown apart from cells that look wrong. Synthetic words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

CapturedEntry _word(
  String no,
  String headword, {
  List<String> readings = const ['よみ'],
  String meaning = '뜻',
  List<EntryIssue> issues = const [],
  List<String> candidates = const [],
}) => CapturedEntry(
  no: no,
  headword: headword,
  readings: readings,
  pos: PartOfSpeech.noun,
  meaning: meaning,
  important: false,
  issues: issues,
  headwordCandidates: candidates,
  ocrHeadword: headword,
);

final _draft = CaptureDraft(
  templateId: 'vocab.list',
  meta: const PageMeta(day: 1, title: '자연', page: 10),
  entries: [
    _word(
      '0002',
      '',
      readings: const ['ひ'],
      issues: const [EntryIssue.missing(EntryField.headword)],
      candidates: const ['日', '火'],
    ),
    _word(
      '0003',
      '雨傘具',
      issues: const [EntryIssue.unverified(EntryField.headword)],
    ),
    _word(
      '0004',
      '切符',
      issues: const [EntryIssue.inferred(EntryField.pos, note: '품사 추정: 명')],
    ),
    _word(
      '0005',
      '到着',
      meaning: '도착,',
      issues: const [
        EntryIssue.suspect(EntryField.meaning, note: '뜻 끝이 잘렸을 수 있음'),
      ],
    ),
  ],
);

Finder _mark(EntryField field, FieldStatus status) =>
    find.byKey(ValueKey('mark-${field.name}-${status.name}'));

Color? _colorOf(WidgetTester tester, Finder mark) {
  final text = tester.widget<Text>(
    find.descendant(of: mark, matching: find.byType(Text)).first,
  );
  return text.style?.color;
}

void main() {
  testWidgets('a candidate chip fills the headword and marks it fixed', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: _draft)));
    await tester.pumpAndSettle();
    expect(find.text('확인 필요 3'), findsWidgets);

    final chip = find.widgetWithText(ActionChip, '日');
    expect(chip, findsOneWidget);
    expect(find.widgetWithText(ActionChip, '火'), findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('日'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '火'), findsNothing);
    expect(_mark(EntryField.headword, FieldStatus.corrected), findsOneWidget);
    expect(find.text('표제어 없음 · 눌러서 입력'), findsNothing);
    expect(find.text('확인 필요 2'), findsWidgets);
    expect(find.text('단어 4개 저장'), findsOneWidget);
  });

  testWidgets('a word not in the dictionary needs a look', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: _draft)));
    await tester.pumpAndSettle();
    final mark = _mark(EntryField.headword, FieldStatus.unverified);
    expect(mark, findsOneWidget);
    expect(
      find.descendant(of: mark, matching: find.text('사전에 없음')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '확인 필요 3'));
    await tester.pumpAndSettle();
    expect(find.text('雨傘具'), findsOneWidget);
    expect(find.text('切符'), findsNothing, reason: 'a guess is not a problem');
  });

  testWidgets('a guess and a suspect cell look different', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: _draft)));
    await tester.pumpAndSettle();
    final guess = _mark(EntryField.pos, FieldStatus.inferred);
    final suspect = _mark(EntryField.meaning, FieldStatus.suspect);
    expect(guess, findsOneWidget);
    expect(suspect, findsOneWidget);
    expect(
      find.descendant(of: guess, matching: find.text('추정')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: suspect, matching: find.text('의심')),
      findsOneWidget,
    );
    final t = ShioriTokens.light;
    expect(_colorOf(tester, guess), isNot(_colorOf(tester, suspect)));
    expect(_colorOf(tester, suspect), isNot(t.risk), reason: 'not the red pen');
  });
}
