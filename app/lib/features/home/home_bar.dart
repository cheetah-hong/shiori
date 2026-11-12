import 'package:flutter/material.dart';
import 'package:shiori/features/capture/capture_screen.dart';
import 'package:shiori/features/home/today_plan.dart';
import 'package:shiori/features/study/restudy_labels.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori/shared/bottom_action_bar.dart';
import 'package:shiori/shared/navigation.dart';

/// 홈's bottom bar, in thumb reach: 페이지 등록 and the day's study button
/// (오늘 학습 시작, or 더 학습하기 when nothing is due). Before the first
/// page the main button is 첫 페이지 등록하기; with words but nothing to
/// study, 페이지 등록 alone.
class HomeBar extends StatelessWidget {
  const HomeBar({super.key, required this.plan});

  /// Null while today's numbers load or when they failed to.
  final TodayPlan? plan;

  @override
  Widget build(BuildContext context) => BottomActionBar(
    secondary: BarAction(
      label: '페이지 등록',
      icon: Icons.photo_camera_outlined,
      onPressed: () => _capture(context),
    ),
    primary: _primary(context),
  );

  static void _capture(BuildContext context) =>
      pushScreen<void>(context, const CaptureScreen());

  Widget? _primary(BuildContext context) {
    final p = plan;
    if (p == null) return null;
    if (p.canStudy) {
      return BarPrimaryButton(
        label: '오늘 학습 시작 · ${p.cards}장',
        icon: Icons.play_arrow_rounded,
        onPressed: () => pushScreen<void>(context, const StudyScreen()),
      );
    }
    if (p.canStudyMore) {
      return BarPrimaryButton(
        label: RestudyLabels.more,
        icon: Icons.replay_rounded,
        onPressed: () =>
            pushScreen<void>(context, const StudyScreen(more: true)),
      );
    }
    if (p.wordCount == 0) {
      return BarPrimaryButton(
        label: '첫 페이지 등록하기',
        icon: Icons.photo_camera_outlined,
        onPressed: () => _capture(context),
      );
    }
    return null;
  }
}
