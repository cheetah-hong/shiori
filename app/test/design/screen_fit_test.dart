// F1–F2: the main screens on the iPhones the app supports (SE 4.7″ up to
// 17 Pro Max), at the default text size, twice it and about the largest
// accessibility size: no layout error, the main action on screen or
// reachable by scrolling, and nothing covering or cutting the study card,
// the bars, the sheets or the day sheet. Made-up words only.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/study/card_parts.dart';
import 'package:shiori/shared/bottom_action_bar.dart';
import 'package:shiori/shared/keep_words.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/design.dart';
import '../support/screen_fit.dart';

/// The main action of each screen, or null where there is none.
const _mainAction = {
  'home empty': '첫 페이지 등록하기',
  'home': '오늘 학습 시작',
  'capture': '카메라로 찍기',
  'review': '개 추가',
  'study meaning': '알고있음',
  'study recall': '알고있음',
  'study listening': '말 둘',
  'study choice': '말 둘',
  'playlist': '이 목록 학습',
};

const _headword = ValueKey('card-headword');

Future<void> _expectReachable(WidgetTester tester, String text) async {
  final finder = find.textContaining(text);
  expect(finder, findsWidgets, reason: text);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  expect(finder.first.hitTestable(), findsOneWidget, reason: text);
}

/// The study card is one sheet that the screen scrolls, not a box that
/// scrolls inside itself; the headword is whole on screen and under no
/// button.
Future<void> _expectCardWhole(WidgetTester tester, Size size) async {
  expect(
    find.descendant(
      of: find.byType(CardFrame),
      matching: find.byType(Scrollable),
    ),
    findsNothing,
  );
  final head = find.byKey(_headword);
  expect(head, findsOneWidget);
  await tester.ensureVisible(head);
  await tester.pumpAndSettle();
  final rect = tester.getRect(head);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
  for (final button in anyButton.evaluate()) {
    final r = tester.getRect(find.byWidget(button.widget));
    expect(overlaps(rect, r), isFalse, reason: 'headword under a button');
  }
}

void main() {
  for (final MapEntry(key: device, value: size) in fitSizes.entries) {
    for (final scale in fitScales) {
      group('$device ×$scale', () {
        for (final screen in designScreens) {
          testWidgets('${screen.name}: lays out, main action reachable', (
            tester,
          ) async {
            useFit(tester, size, scale);
            await openFitScreen(tester, screen);
            expect(tester.takeException(), isNull);
            if (_mainAction[screen.name] case final action?) {
              await _expectReachable(tester, action);
            }
            expect(tester.takeException(), isNull);
          });
        }

        for (final mode in StudyMode.values) {
          testWidgets('study ${mode.name}, turned', (tester) async {
            useFit(tester, size, scale);
            await openFitScreen(tester, designScreen('study ${mode.name}'));
            await turnStudyCard(tester, mode);
            expect(tester.takeException(), isNull);
            await _expectReachable(
              tester,
              mode == StudyMode.meaning || mode == StudyMode.recall
                  ? '알고있음'
                  : '다음',
            );
          });
        }

        testWidgets('오늘 학습 끝', (tester) async {
          useFit(tester, size, scale);
          await openFitScreen(tester, designScreen('study meaning'));
          for (var i = 0; i < 5; i++) {
            await tapDesignText(tester, '알고있음');
          }
          expect(find.text('오늘 학습 끝'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _expectReachable(tester, '확인');
        });
      });
    }

    group('$device ×3.1', () {
      testWidgets('W1 the study card is whole: meaning, front and back', (
        tester,
      ) async {
        useFit(tester, size, 3.1);
        await openFitScreen(tester, designScreen('study meaning'));
        await _expectCardWhole(tester, size);
        await turnStudyCard(tester, StudyMode.meaning);
        await _expectCardWhole(tester, size);
      });

      testWidgets('W1 the study card is whole: recall back', (tester) async {
        useFit(tester, size, 3.1);
        await openFitScreen(tester, designScreen('study recall'));
        await turnStudyCard(tester, StudyMode.recall);
        await _expectCardWhole(tester, size);
      });

      testWidgets('W1 the study card is whole: choice, front and back', (
        tester,
      ) async {
        useFit(tester, size, 3.1);
        await openFitScreen(tester, designScreen('study choice'));
        await _expectCardWhole(tester, size);
        await turnStudyCard(tester, StudyMode.choice);
        await _expectCardWhole(tester, size);
      });

      testWidgets('W1 the study card is whole: listening back', (tester) async {
        useFit(tester, size, 3.1);
        await openFitScreen(tester, designScreen('study listening'));
        await turnStudyCard(tester, StudyMode.listening);
        await _expectCardWhole(tester, size);
      });

      testWidgets('W3 새 재생목록: the title clear of the name field', (
        tester,
      ) async {
        useFit(tester, size, 3.1);
        await openFitScreen(tester, designScreen('playlists edit'));
        await tester.tap(find.byTooltip('새 재생목록'));
        await tester.pumpAndSettle();
        final field = tester.getRect(find.byType(EditableText));
        final titles = find.text('새 재생목록');
        expect(titles, findsWidgets);
        for (final title in titles.evaluate()) {
          final r = tester.getRect(find.byWidget(title.widget));
          expect(overlaps(r, field), isFalse);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('W4 고치기 with the keyboard up: the head clear of the fields', (
        tester,
      ) async {
        useFit(tester, size, 3.1);
        await openFitScreen(tester, designScreen('review'));
        // At this size the first word is below the head: scroll it in.
        final edit = find.byTooltip('고치기');
        for (var i = 0; i < 20 && edit.evaluate().isEmpty; i++) {
          await tester.drag(
            find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .first,
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(edit.first);
        await tester.pumpAndSettle();
        await tester.tap(edit.first);
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding(bottom: 300 * 3);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final fields = [
          for (final f in find.byType(EditableText).evaluate())
            tester.getRect(find.byWidget(f.widget)),
        ];
        expect(fields, isNotEmpty);
        for (final head in find.text('고치기').evaluate()) {
          final r = tester.getRect(find.byWidget(head.widget));
          for (final f in fields) {
            expect(overlaps(r, f), isFalse);
          }
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('W5 학습 방식: the choices span the screen', (tester) async {
        useFit(tester, size, 3.1);
        await openFitScreen(tester, designScreen('home'));
        await tapDesignText(tester, '뜻 맞히기');
        final item = find.text('일본어 떠올리기');
        expect(item.hitTestable(), findsOneWidget);
        final itemBox = find.ancestor(
          of: item,
          matching: find.byType(CupertinoActionSheetAction),
        );
        expect(
          tester.getSize(itemBox).width,
          greaterThanOrEqualTo(size.width * 0.6),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('W7 the day numeral stays the largest on the day sheet', (
        tester,
      ) async {
        useFit(tester, size, 3.1);
        await openFitScreen(tester, designScreen('home'));
        final numeral = tester.getSize(
          find.byKey(const ValueKey('day-numeral')),
        );
        final weekday = tester.getSize(
          find.byKey(const ValueKey('day-weekday')),
        );
        expect(numeral.height, greaterThan(weekday.height * 1.3));
      });
    });
  }

  group('SE ×3.1: W2 the bottom bar leaves the screen to the page', () {
    const size = Size(375, 667);
    for (final name in ['home', 'capture', 'playlist', 'review']) {
      testWidgets(name, (tester) async {
        useFit(tester, size, 3.1);
        await openFitScreen(tester, designScreen(name));
        final bar = tester.getSize(find.byType(BottomActionBar));
        expect(bar.height, lessThanOrEqualTo(size.height * 0.25));
      });
    }
  });

  testWidgets('F2 SE, default text: 오늘 학습 시작 on the first screen', (
    tester,
  ) async {
    const size = Size(375, 667);
    useFit(tester, size, 1);
    await openFitScreen(tester, designScreen('home'));
    final rect = tester.getRect(find.textContaining('오늘 학습 시작'));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(size.height));
    expect(find.textContaining('오늘 학습 시작').hitTestable(), findsOneWidget);
  });

  group('W6 headings break between words only', () {
    const title = '교재 한 쪽을 찍으면';

    test('keepWords joins the letters of each word', () {
      expect(keepWords('한국어 뜻'), '한⁠국⁠어 뜻');
      expect(keepWords('가\n나다'), '가\n나⁠다');
      expect(keepWords(''), '');
    });

    testWidgets('a narrow heading wraps at the spaces', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 110,
              child: KeepWordsText(title, style: TextStyle(fontSize: 20)),
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final shown = paragraph.text.toPlainText(includeSemanticsLabels: false);
      final lines = <String>[];
      var line = StringBuffer();
      double? top;
      for (var i = 0; i < shown.length; i++) {
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: i, extentOffset: i + 1),
        );
        if (boxes.isEmpty) continue;
        if (top != null && boxes.first.top > top + 1) {
          lines.add(line.toString());
          line = StringBuffer();
        }
        top = boxes.first.top;
        line.write(shown[i]);
      }
      lines.add(line.toString());
      final words = [for (final l in lines) l.replaceAll('⁠', '').trim()];
      expect(words, ['교재 한', '쪽을', '찍으면']);
    });

    testWidgets('it is found and read as the words it shows', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: KeepWordsText(title))),
      );
      expect(find.text(title), findsOneWidget);
      expect(find.bySemanticsLabel(title), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('screen and section headings use it', (tester) async {
      useFit(tester, const Size(375, 667), 1);
      await openFitScreen(tester, designScreen('settings'));
      expect(find.widgetWithText(KeepWordsText, '학습 세션'), findsOneWidget);
    });
  });
}
