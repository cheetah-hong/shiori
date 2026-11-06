// The review screen's marks: headword candidates, cells that need a look, and
// guesses shown apart from cells that look wrong. Synthetic words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

CapturedEntry _word(
  String headword, {
  List<String> readings = const ['よみ'],
  String meaning = '뜻',
  List<EntryIssue> issues = const [],
  List<String> candidates = const [],
}) => CapturedEntry(
  headword: headword,
  readings: readings,
  pos: PartOfSpeech.noun,
  meaning: meaning,
  issues: issues,
  headwordCandidates: candidates,
  ocrHeadword: headword,
  evidence: EntryEvidence(
    origin: WordOrigin.wordList,
    fields: {
      EntryField.headword: FieldEvidence(
        source: FieldSource.photo,
        candidates: candidates,
      ),
    },
  ),
);

final _draft = CaptureDraft(
  entries: [
    _word(
      '',
      readings: const ['ひ'],
      issues: const [EntryIssue.missing(EntryField.headword)],
      candidates: const ['日', '火'],
    ),
    _word(
      '雨傘具',
      issues: const [
        EntryIssue.suspect(EntryField.headword, note: '사전 역조회 후보 2'),
      ],
    ),
    _word(
      '切符',
      issues: const [EntryIssue.inferred(EntryField.readings, note: '사전')],
    ),
    _word(
      '到着',
      meaning: '도착,',
      issues: const [
        EntryIssue.suspect(EntryField.meaning, note: '뜻 끝이 잘렸을 수 있음'),
      ],
    ),
  ],
);

/// A page with one automatic fix, an unread headword, a suspect meaning and a
/// word without flags.
CaptureDraft _page() => CaptureDraft(
  entries: [
    _word(
      '一日',
      issues: const [
        EntryIssue.corrected(EntryField.headword, note: 'ー日 → 一日'),
      ],
    ),
    _word(
      '',
      readings: const ['ひ'],
      issues: const [EntryIssue.missing(EntryField.headword)],
      candidates: const ['日', '火'],
    ),
    _word(
      '到着',
      meaning: '도착,',
      issues: const [
        EntryIssue.suspect(EntryField.meaning, note: '뜻 끝이 잘렸을 수 있음'),
      ],
    ),
    _word('晴れ', readings: const ['はれ'], meaning: '맑음'),
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
  testWidgets('D11 a headword candidate chip fills the headword and marks it '
      'fixed', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: _draft)));
    await tester.pumpAndSettle();
    expect(find.text('확인 필요 3'), findsWidgets);

    final chip = find.byKey(const ValueKey('candidate-0-headword-日'));
    expect(chip, findsOneWidget);
    expect(
      find.byKey(const ValueKey('candidate-0-headword-火')),
      findsOneWidget,
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cell-0-headword')),
        matching: find.text('日'),
      ),
      findsOneWidget,
    );
    expect(_mark(EntryField.headword, FieldStatus.corrected), findsOneWidget);
    expect(find.text('표제어 없음'), findsNothing);
    expect(find.text('확인 필요 2'), findsWidgets);
    expect(find.text('단어 4개 추가'), findsOneWidget);
  });

  testWidgets('a doubtful headword needs a look', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: _draft)));
    await tester.pumpAndSettle();
    expect(_mark(EntryField.headword, FieldStatus.suspect), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '확인 필요 3'));
    await tester.pumpAndSettle();
    expect(find.text('雨傘具'), findsOneWidget);
    expect(find.text('切符'), findsNothing, reason: 'a guess is not a problem');
  });

  testWidgets('a guess and a suspect cell look different', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: _draft)));
    await tester.pumpAndSettle();
    final guess = _mark(EntryField.readings, FieldStatus.inferred);
    final suspect = _mark(EntryField.meaning, FieldStatus.suspect);
    await tester.scrollUntilVisible(suspect, 200);
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

  testWidgets('고치기 without a change clears a suspect meaning', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: _page())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _mark(EntryField.meaning, FieldStatus.suspect),
      200,
    );
    expect(_mark(EntryField.meaning, FieldStatus.suspect), findsOneWidget);
    expect(find.text('확인 필요 2'), findsWidgets);

    final edit = find.descendant(
      of: find.byKey(const ValueKey('entry-2')),
      matching: find.byTooltip('고치기'),
    );
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '고치기'));
    await tester.pumpAndSettle();

    expect(_mark(EntryField.meaning, FieldStatus.suspect), findsNothing);
    expect(find.text('도착,'), findsOneWidget, reason: 'the value is kept');
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, '확인 필요 1'),
      -200,
    );
    expect(find.text('확인 필요 1'), findsWidgets);
  });

  testWidgets('a picked candidate does not count as an automatic fix', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: _page())));
    await tester.pumpAndSettle();
    expect(find.text('자동 보정 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('candidate-1-headword-日')));
    await tester.pumpAndSettle();

    expect(find.text('자동 보정 1'), findsOneWidget);
    expect(_mark(EntryField.headword, FieldStatus.corrected), findsNWidgets(2));
    expect(find.text('확인 필요 1'), findsWidgets);
  });

  testWidgets('no notice about columns: the page is not read in columns', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: _page())));
    await tester.pumpAndSettle();
    expect(find.textContaining('칸 위치'), findsNothing);
  });
}
