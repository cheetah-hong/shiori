// U2: what VoiceOver reads. Every button has a name; Japanese is read in
// Japanese; a study card reads its front once and announces what a reveal
// opens; a mode that cannot be picked says why; 「되돌리기」 stays while
// VoiceOver is on; reduced motion from iOS reaches the app. Made-up words.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/design.dart';
import '../support/harness.dart';
import '../support/study_modes.dart';

/// The root of the app's semantics tree.
SemanticsNode _root(WidgetTester tester) =>
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;

/// Every node that can be pressed has a label or tooltip.
void _buttonsNamed(WidgetTester tester, String where) {
  final root = _root(tester);
  final unnamed = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final pressable =
        data.flagsCollection.isButton || data.hasAction(SemanticsAction.tap);
    if (pressable &&
        !node.isMergedIntoParent &&
        data.label.trim().isEmpty &&
        data.tooltip.trim().isEmpty &&
        data.value.trim().isEmpty) {
      unnamed.add('$node');
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  expect(unnamed, isEmpty, reason: where);
}

/// The semantics nodes whose label contains [text].
List<SemanticsNode> _nodesWith(WidgetTester tester, String text) {
  final found = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().label.contains(text)) found.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(_root(tester));
  return found;
}

bool _readInJapanese(SemanticsNode node) => node
    .getSemanticsData()
    .attributedLabel
    .attributes
    .any((a) => a is LocaleStringAttribute && a.locale.languageCode == 'ja');

void main() {
  for (final screen in designScreens) {
    testWidgets('$screen: every button has a name', (tester) async {
      final handle = tester.ensureSemantics();
      await openDesignScreen(tester, screen);
      _buttonsNamed(tester, screen.name);
      handle.dispose();
    });
  }

  testWidgets('a study card reads its headword once, in Japanese', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openDesignScreen(
      tester,
      designScreens.firstWhere((s) => s.name == 'study meaning'),
    );
    final headword = _nodesWith(tester, '語一');
    expect(headword, isNotEmpty);
    for (final node in headword) {
      final label = node.getSemanticsData().label;
      expect('語一'.allMatches(label).length, 1, reason: 'read once: "$label"');
    }
    expect(headword.any(_readInJapanese), isTrue);
    handle.dispose();
  });

  testWidgets('a playlist reads its headwords in Japanese', (tester) async {
    final handle = tester.ensureSemantics();
    await openDesignScreen(
      tester,
      designScreens.firstWhere((s) => s.name == 'playlist'),
    );
    final headword = _nodesWith(tester, '語二');
    expect(headword, isNotEmpty);
    expect(headword.any(_readInJapanese), isTrue);
    handle.dispose();
  });

  testWidgets('뜻 보기 announces the meaning it opens', (tester) async {
    final handle = tester.ensureSemantics();
    await openDesignScreen(
      tester,
      designScreens.firstWhere((s) => s.name == 'study meaning'),
    );
    expect(_nodesWith(tester, '말 하나'), isEmpty);
    await tapDesignText(tester, '뜻 보기');
    final meaning = _nodesWith(tester, '말 하나');
    expect(meaning, isNotEmpty);
    expect(
      meaning.any((n) => n.getSemanticsData().flagsCollection.isLiveRegion),
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('a mode that cannot be picked says why', (tester) async {
    final handle = tester.ensureSemantics();
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await seedModeWords(blocks, count: 2);
    await tester.pumpWidget(app(blocks, extra: designBlocks()));
    await tester.pumpAndSettle();
    final choice = _nodesWith(tester, StudyModeLabels.name(StudyMode.choice));
    expect(choice, isNotEmpty);
    expect(
      choice.any(
        (n) => n.getSemanticsData().hint == StudyModeLabels.tooFewWords,
      ),
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('되돌리기 stays while VoiceOver is on', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await openDesignScreen(
      tester,
      designScreens.firstWhere((s) => s.name == 'playlist'),
    );
    await tester.tap(find.byTooltip('語一 숨기기 (이미 알아요)'));
    await tester.pumpAndSettle();
    expect(find.text('되돌리기'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('되돌리기'), findsOneWidget);
  });

  testWidgets('iOS 「동작 줄이기」 turns the app\'s animations off', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await openDesignScreen(tester, designScreens.first);
    final context = tester.element(find.text('오늘').first);
    expect(Motion.reduced(context), isTrue);
    expect(Motion.of(context, Motion.card), Duration.zero);
  });

  testWidgets('without it the animations keep their length', (tester) async {
    await openDesignScreen(tester, designScreens.first);
    final context = tester.element(find.text('오늘').first);
    expect(Motion.reduced(context), isFalse);
    expect(Motion.of(context, Motion.card), Motion.card);
  });
}
