// 설정: the study options. Only the shared record and 전체 + 재생목록 are
// built; the other choices are not offered (no row, no notice).
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/settings/settings_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

void main() {
  Finder row(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ListTile));

  bool isSelected(WidgetTester tester, String title) => tester.any(
    find.descendant(
      of: row(title),
      // The chosen row carries a check on its right.
      matching: find.byIcon(CupertinoIcons.checkmark),
    ),
  );

  testWidgets('opens from home and shows the defaults', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('학습 기록'), findsOneWidget);
    expect(find.text('학습 범위'), findsOneWidget);
    expect(isSelected(tester, '재생목록끼리 공유'), isTrue);
    expect(isSelected(tester, '재생목록마다 따로'), isFalse);
    expect(isSelected(tester, '전체 복습 + 재생목록 골라 학습'), isTrue);
    expect(isSelected(tester, '항상 재생목록 하나씩'), isFalse);
    expect(find.textContaining('준비 중'), findsNothing);
  });

  testWidgets('screen readers hear which choice is on', (tester) async {
    usePhoneSize(tester);
    final semantics = tester.ensureSemantics();
    final blocks = TestBlocks();
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(row('재생목록끼리 공유')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    expect(
      tester.getSemantics(row('전체 복습 + 재생목록 골라 학습')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    semantics.dispose();
  });

  testWidgets('the options not built yet cannot be picked', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();

    // Not offered as rows, so nothing can store them.
    expect(row('재생목록마다 따로'), findsNothing);
    expect(row('항상 재생목록 하나씩'), findsNothing);
    expect(find.textContaining('재생목록마다 따로'), findsNothing);
    expect(await blocks.preferences.load(), const StudyPreferences());
  });

  testWidgets('a stored value shows as chosen', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.preferences.save(
      const StudyPreferences(recordMode: RecordMode.perPlaylist),
    );
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(isSelected(tester, '재생목록마다 따로'), isTrue);
    expect(isSelected(tester, '재생목록끼리 공유'), isFalse);
  });

  testWidgets('picking the shared record stores it', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.preferences.save(
      const StudyPreferences(recordMode: RecordMode.perPlaylist),
    );
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재생목록끼리 공유'));
    await tester.pumpAndSettle();
    expect((await blocks.preferences.load()).recordMode, RecordMode.shared);
    expect(isSelected(tester, '재생목록끼리 공유'), isTrue);
  });
}
