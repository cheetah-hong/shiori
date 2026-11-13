import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/about/about_screen.dart';
import 'package:shiori/features/home/day_sheet.dart';
import 'package:shiori/features/home/home_bar.dart';
import 'package:shiori/features/home/home_load_error.dart';
import 'package:shiori/features/home/home_playlists.dart';
import 'package:shiori/features/home/mode_row.dart';
import 'package:shiori/features/home/today_plan.dart';
import 'package:shiori/features/home/week_strip.dart';
import 'package:shiori/features/settings/settings_screen.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori_core/shiori_core.dart';

/// 홈 as today's page of a tear-off calendar: the date and today's numbers
/// (전체), this week, the way of studying, the playlists, and 페이지 등록
/// with the study button fixed at the bottom.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(studySettingsProvider);
    final today = _studyDay(
      ref.watch(clockProvider).now(),
      settings.dayStartHour,
    );
    final summary = ref.watch(homeSummaryProvider);
    final preferences = ref.watch(studyPreferencesProvider).value;
    // Not through the study service: the sheet shows a storage failure
    // instead of failing to build.
    final size = StudyService.sizeOf(
      const AllWords(),
      preferences?.dailyGoal ?? DailyGoal.ten,
      settings,
    );
    // Riverpod retries a failed provider; while it does, the state is
    // "loading" but still carries the error.
    final loaded = summary.hasError ? null : summary.value;
    final plan = loaded == null ? null : TodayPlan.of(loaded, size);
    // Before the first page: no zeros and no warnings about ways that need
    // words.
    final noWords = loaded?.wordCount == 0;

    final Widget body;
    if (summary.hasError) {
      body = HomeLoadError(onRetry: () => retryStorage(ref));
    } else if (plan == null) {
      body = const SizedBox(height: _loadingHeight);
    } else if (plan.canStudy || plan.canStudyMore) {
      body = SheetMemo(plan: plan);
    } else {
      // Nothing to press: said plainly, not as a dimmed button.
      body = SheetNothing(noWords: plan.wordCount == 0);
    }

    final knownCount = loaded?.knownToday ?? 0;
    // Counted in the mode in use, named small below once known.
    final knownMode = ref.watch(studyModeProvider).value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _TopBar()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DaySheet(
                      today: today,
                      body: body,
                      known: knownCount > 0
                          ? KnownToday(
                              count: knownCount,
                              modeName: knownMode == null
                                  ? null
                                  : StudyModeLabels.name(knownMode),
                            )
                          : null,
                    ),
                    const WeekStrip(),
                    StudyOptions(
                      canPick:
                          ref.watch(playlistsProvider).value?.isNotEmpty ??
                          false,
                      noWords: noWords,
                    ),
                  ],
                ),
              ),
            ),
            const HomePlaylists(),
            const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
          ],
        ),
      ),
      bottomNavigationBar: HomeBar(plan: plan),
    );
  }
}

const double _loadingHeight = 96;

/// The study day [now] falls in (before the day-start hour it is still the
/// day before), so the sheet and the week strip agree.
DateTime _studyDay(DateTime now, int dayStartHour) =>
    dayStartHour >= 0 && dayStartHour < 24
    ? StudyCalendar(dayStartHour: dayStartHour).studyDayOf(now)
    : now;

/// The navigation bar: 「오늘」 in the middle, 설정 and 정보 on the right.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      child: Row(
        children: [
          // Balances the two buttons so the title sits in the middle.
          const SizedBox(width: _sideWidth),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                '오늘',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.text,
                  fontSize: TypeScale.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: _sideWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '설정',
                  icon: Icon(CupertinoIcons.gear, color: t.accentText),
                  onPressed: () =>
                      pushScreen<void>(context, const SettingsScreen()),
                ),
                IconButton(
                  tooltip: '정보',
                  icon: Icon(CupertinoIcons.info_circle, color: t.accentText),
                  onPressed: () =>
                      pushScreen<void>(context, const AboutScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two 48 pt icon buttons.
const double _sideWidth = 96;
