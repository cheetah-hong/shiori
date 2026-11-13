import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/bottom_action_bar.dart';
import 'package:shiori/shared/keep_words.dart';
import 'package:shiori/shared/large_text.dart';

/// One page of the guide: words only, set as a page of the tear-off
/// calendar (an ink strip over a large title).
final class _Page {
  const _Page(this.title, this.body);

  final String title;
  final String body;
}

const _pages = [
  _Page(
    '교재 한 쪽을 찍으면\n단어장이 돼요',
    '사진 속 일본어 단어와 읽기·뜻·예문을 찾아 정리해요. '
        '확인이 필요한 칸은 따로 표시해요.',
  ),
  _Page(
    '재생목록에 담아\n원하는 만큼 묶어요',
    '같은 단어는 한 번만 저장되고, 어느 재생목록에서 공부해도 학습 기록이 이어져요.',
  ),
  _Page(
    '네 가지 방식으로\n매일 조금씩',
    '알고 있으면 30분·3일·7일·21일 뒤에 다시 나와요. '
        '홈에는 오늘 학습할 만큼만 나와요.',
  ),
];

/// The first-run guide: three pages, 건너뛰기 at any time. It asks for no
/// permission; the camera is asked for when the learner first takes a photo.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone, this.onDecks});

  /// Called once, on 건너뛰기 or 시작하기.
  final VoidCallback onDone;

  /// Called once instead of [onDone] on the last page's 기본 단어장으로 시작;
  /// without it the page does not offer that.
  final VoidCallback? onDecks;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  var _index = 0;
  var _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  void _toDecks(VoidCallback onDecks) {
    if (_done) return;
    _done = true;
    onDecks();
  }

  void _next() {
    if (_index == _pages.length - 1) return _finish();
    final duration = Motion.of(context, Motion.ui);
    if (duration == Duration.zero) {
      _controller.jumpToPage(_index + 1);
    } else {
      unawaited(
        _controller.nextPage(duration: duration, curve: Motion.easeOut),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, Space.xs, Space.sm, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('건너뛰기'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _PageBody(
                  page: _pages[i],
                  number: i + 1,
                  position: '${_pages.length}장 중 ${i + 1}장',
                ),
              ),
            ),
          ],
        ),
      ),
      // The page dots and 다음 stay fixed below a hairline: the text above
      // scrolls on its own and never runs under them.
      bottomNavigationBar: BottomActionBar(
        top: _Dots(count: _pages.length, index: _index),
        secondary: switch (widget.onDecks) {
          final onDecks? when last => BarAction(
            label: '기본 단어장으로 시작',
            onPressed: () => _toDecks(onDecks),
          ),
          _ => null,
        },
        primary: BarPrimaryButton(
          label: last ? '시작하기' : '다음',
          onPressed: _next,
        ),
      ),
    );
  }
}

/// Which page is showing (VoiceOver reads 「3장 중 1장」 on the page).
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: Motion.of(context, Motion.ui),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? t.accent : t.line,
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.page,
    required this.number,
    required this.position,
  });

  final _Page page;

  /// The page's number, set large as the day sheet's date.
  final int number;
  final String position;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: position,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: _stripWidth, color: t.text),
                const SizedBox(height: Space.md),
                ExcludeSemantics(
                  child: CappedText(
                    max: TextCaps.display,
                    child: Text(
                      '$number',
                      style: TextStyle(
                        color: t.text,
                        fontSize: TypeScale.page,
                        height: 0.92,
                        fontWeight: Weights.display,
                        letterSpacing: -3.8,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.lg),
                Semantics(
                  header: true,
                  child: CappedText(
                    max: TextCaps.chrome,
                    child: KeepWordsText(
                      page.title,
                      style: context.text.headlineLarge?.copyWith(
                        color: t.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                Text(
                  page.body,
                  style: context.text.bodyLarge?.copyWith(
                    color: t.text2,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: Space.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The ink strip over each page's title, as the day sheet's binding.
const double _stripWidth = 4;
