// F3: what made the screens look machine-made stays out — Android ripples,
// an icon on every worded button, a mixed Material icon set and Material
// menus, heavy type everywhere, screens explaining themselves, 「A · B」
// strings, a streak line, labels on every covered line, a tinted icon
// circle, badges on cells that need nothing, sketched onboarding pictures,
// three controls at a row's end, the tear line at every list's end and a
// dashboard of numbers over a playlist. Made-up words only.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/card_parts.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori/shared/sheet.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/design.dart';
import '../support/screen_fit.dart';

const _phone = Size(390, 844);

/// Every non-comment line of the Dart files under [dirs] matching [pattern],
/// as `path:line`, except in [except].
List<String> _sourceLines(
  List<String> dirs,
  RegExp pattern, {
  Set<String> except = const {},
}) {
  final hits = <String>[];
  for (final dir in dirs) {
    for (final file in Directory(dir).listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (except.contains(file.path)) continue;
      for (final (i, line) in file.readAsLinesSync().indexed) {
        if (line.trimLeft().startsWith('//')) continue;
        if (pattern.hasMatch(line)) hits.add('${file.path}:${i + 1}');
      }
    }
  }
  return hits;
}

/// Buttons that show words and also an icon.
List<String> _wordedButtonsWithIcons(WidgetTester tester) => [
  for (final button
      in find.byWidgetPredicate((w) => w is ButtonStyleButton).evaluate())
    if (find
            .descendant(
              of: find.byWidget(button.widget),
              matching: find.byType(Text),
            )
            .evaluate()
            .isNotEmpty &&
        find
            .descendant(
              of: find.byWidget(button.widget),
              matching: find.byType(Icon),
            )
            .evaluate()
            .isNotEmpty)
      find
          .descendant(
            of: find.byWidget(button.widget),
            matching: find.byType(Text),
          )
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .join(),
];

void main() {
  test('S12 no Material ripple: presses do not splash', () {
    for (final b in Brightness.values) {
      expect(buildTheme(b).splashFactory, same(NoSplash.splashFactory));
    }
  });

  group('S1 worded buttons carry no icon', () {
    for (final name in ['home', 'home empty', 'capture', 'review']) {
      testWidgets(name, (tester) async {
        useFit(tester, _phone, 1);
        await openFitScreen(tester, designScreen(name));
        expect(_wordedButtonsWithIcons(tester), isEmpty);
      });
    }

    testWidgets('a study card, both sides, and 오늘 학습 끝', (tester) async {
      useFit(tester, _phone, 1);
      await openFitScreen(tester, designScreen('study meaning'));
      expect(_wordedButtonsWithIcons(tester), isEmpty);
      await turnStudyCard(tester, StudyMode.meaning);
      expect(_wordedButtonsWithIcons(tester), isEmpty);
      for (var i = 0; i < 5; i++) {
        await tapDesignText(tester, '알고있음');
      }
      expect(find.text('오늘 학습 끝'), findsOneWidget);
      expect(_wordedButtonsWithIcons(tester), isEmpty);
    });
  });

  group('source', () {
    const screens = ['lib/features', 'lib/shared'];

    test('S2 one icon set: no Material icons on the screens', () {
      expect(_sourceLines(screens, RegExp(r'\bIcons\.')), isEmpty);
    });

    test('S11 no Material menus or dialogs', () {
      expect(
        _sourceLines(
          screens,
          RegExp(r'\bPopupMenuButton\b|\bMenuAnchor\b|\bAlertDialog\('),
        ),
        isEmpty,
      );
    });

    test('S3 three weights, sizes from the type scale', () {
      expect(
        _sourceLines([
          'lib',
        ], RegExp(r'FontWeight\.w(100|200|300|500|800|900)\b')),
        isEmpty,
      );
      expect(
        _sourceLines(
          ['lib'],
          RegExp(r'fontSize:\s*[0-9]'),
          except: {'lib/app/theme.dart'},
        ),
        isEmpty,
      );
    });

    test('S4 S15 no 「드려요」, no 「준비 중」 notices, one polite register', () {
      expect(_sourceLines(screens, RegExp(r"'[^']*(드려요|준비 중)[^']*'")), isEmpty);
      expect(
        _sourceLines([
          'lib/features/home',
          'lib/features/study',
          'lib/features/capture',
          'lib/features/playlists',
          'lib/features/settings',
          'lib/features/onboarding',
          'lib/shared',
        ], RegExp(r"니다[.']")),
        isEmpty,
      );
    });

    test('S10 no sketched onboarding pictures', () {
      expect(
        File('lib/features/onboarding/onboarding_art.dart').existsSync(),
        isFalse,
      );
      expect(
        _sourceLines(['lib'], RegExp(r'\b(PageArt|PlaylistArt|ModesArt)\b')),
        isEmpty,
      );
    });
  });

  testWidgets('S4 S5 S6 홈: no plan sentence, no 「A · B」, no streak', (
    tester,
  ) async {
    useFit(tester, _phone, 1);
    await openFitScreen(tester, designScreen('home'));
    expect(find.textContaining('— 오늘'), findsNothing);
    expect(find.textContaining('장을 먼저'), findsNothing);
    expect(find.textContaining('연속'), findsNothing);
    final dotted = [
      for (final e in find.textContaining(' · ').evaluate())
        (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText(),
    ].where((s) => !(s ?? '').startsWith('오늘 학습 시작 · '));
    expect(dotted, isEmpty);
  });

  testWidgets('S5 the study header names the way, without 「오늘 학습 · 」', (
    tester,
  ) async {
    useFit(tester, _phone, 1);
    await openFitScreen(tester, designScreen('study recall'));
    expect(find.textContaining('오늘 학습 · '), findsNothing);
    expect(find.text('일본어 떠올리기'), findsOneWidget);
  });

  testWidgets('S5 검토: the reading time without 「 · 」', (tester) async {
    useFit(tester, _phone, 1);
    await openFitScreen(tester, designScreen('review'));
    expect(find.textContaining('판독'), findsWidgets);
    expect(find.textContaining('· 판독'), findsNothing);
  });

  testWidgets('S7 covered lines show no 「가림」 label; screen readers get it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    useFit(tester, _phone, 1);
    await openFitScreen(tester, designScreen('study meaning'));
    expect(find.textContaining('가림'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('뜻 가림')), findsWidgets);
    final tag = tester.widget<Text>(find.text('새 단어'));
    expect(tag.style?.color, ShioriTokens.light.text3);
    semantics.dispose();
  });

  testWidgets('S8 듣고 맞히기: a 다시 듣기 button, no tinted circle', (tester) async {
    useFit(tester, _phone, 1);
    await openFitScreen(tester, designScreen('study listening'));
    final circles = find.descendant(
      of: find.byType(CardFrame),
      matching: find.byWidgetPredicate(
        (w) =>
            (w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle) ||
            (w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle) ||
            w is CircleAvatar,
      ),
    );
    expect(circles, findsNothing);
    expect(find.byTooltip('다시 듣기'), findsOneWidget);
    expect(find.text('다시 듣기'), findsOneWidget);
  });

  testWidgets('S9 검토: cells that need nothing carry no badge', (tester) async {
    useFit(tester, _phone, 1);
    await openFitScreen(tester, designScreen('review'));
    expect(find.text('사진'), findsNothing);
    expect(find.text('높음'), findsNothing);
    expect(find.textContaining('확인 필요'), findsWidgets);
  });

  testWidgets('S13 S14 S16 a playlist: hide in the menu, no tear line, '
      'no number dashboard', (tester) async {
    useFit(tester, _phone, 1);
    await openFitScreen(tester, designScreen('playlist'));
    expect(find.byType(TearLine), findsNothing);
    expect(find.byType(SheetMemoRow), findsNothing);
    expect(find.byTooltip(HideLabels.hideWord('語一')), findsNothing);
    await tester.tap(find.byTooltip('語一 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text(HideLabels.button), findsOneWidget);
  });

  testWidgets('S14 재생목록 편집 ends without a tear line', (tester) async {
    useFit(tester, _phone, 1);
    await openFitScreen(tester, designScreen('playlists edit'));
    expect(find.byType(TearLine), findsNothing);
  });

  testWidgets('S10 the first-run guide is words only', (tester) async {
    useFit(tester, _phone, 1);
    await openFitScreen(tester, designScreen('home'));
    // Reached from 정보 → 사용 안내 다시 보기.
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    await tapDesignText(tester, '사용 안내 다시 보기');
    expect(find.text('건너뛰기'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('찍으면'), findsOneWidget);
  });
}
