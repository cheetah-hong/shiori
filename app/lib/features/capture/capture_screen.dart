import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/capture_controller.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// 등록: choose a photo (or a development sample) and read it.
class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(captureControllerProvider, (previous, next) {
      if (next is CaptureReady) {
        ref.read(captureControllerProvider.notifier).reset();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReviewScreen(
              draft: next.draft,
              sourceLabel: next.image.label,
              recognizerId: next.recognizerId,
            ),
          ),
        );
      }
    });
    final state = ref.watch(captureControllerProvider);
    final controller = ref.read(captureControllerProvider.notifier);
    final busy = state is CaptureReading;
    final showSamples = ref.watch(devSamplesEnabledProvider);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: const Text('페이지 등록')),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                Space.section,
              ),
              children: [
                Text(
                  '단어장 한 쪽을 위에서 똑바로 찍어 주세요.\n목록형(N5·N4)과 예문이 있는 항목형(N3)을 알아서 구분합니다.',
                  style: context.text.bodyMedium?.copyWith(
                    color: t.ink2,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: Space.xl),
                Row(
                  children: [
                    Expanded(
                      child: _SourceTile(
                        icon: Icons.photo_camera_outlined,
                        title: '카메라로 찍기',
                        subtitle: '지금 펼친 쪽',
                        primary: true,
                        onTap: busy
                            ? null
                            : () => unawaited(
                                controller.pick(ImageOrigin.camera),
                              ),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: _SourceTile(
                        icon: Icons.photo_library_outlined,
                        title: '앨범에서 고르기',
                        subtitle: '찍어 둔 사진',
                        onTap: busy
                            ? null
                            : () => unawaited(
                                controller.pick(ImageOrigin.gallery),
                              ),
                      ),
                    ),
                  ],
                ),
                if (state is CaptureFailed) ...[
                  const SizedBox(height: Space.lg),
                  _FailureNote(message: state.message),
                ],
                if (showSamples) ...[
                  SectionLabel(
                    '샘플 페이지로 해 보기',
                    trailing: Pill(
                      '개발용',
                      background: t.warnBg,
                      foreground: t.warn,
                      icon: Icons.science_outlined,
                    ),
                  ),
                  Text(
                    '미리 판독해 둔 교재 쪽으로 등록 흐름을 끝까지 볼 수 있어요. 배포판에는 들어가지 않습니다.',
                    style: context.text.bodySmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: Space.md),
                  for (final s in devSamples)
                    _SampleTile(
                      sample: s,
                      onTap: busy
                          ? null
                          : () => unawaited(controller.sample(s)),
                    ),
                ],
              ],
            ),
            if (state is CaptureReading)
              _ReadingOverlay(label: state.image.label ?? '사진'),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = primary ? t.ink : t.sheet;
    final fg = primary ? t.sheet : t.ink;
    return PressScale(
      enabled: onTap != null,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.lg,
              Space.lg,
              Space.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary ? t.marker : t.paper2,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: primary ? t.markerInk : t.ink,
                  ),
                ),
                const SizedBox(height: Space.xl),
                Text(
                  title,
                  style: context.text.titleMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(
                    color: primary ? t.sheet.withValues(alpha: 0.75) : t.ink3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({required this.sample, required this.onTap});

  final DevSample sample;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Material(
        color: t.sheet,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.tile),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    '${sample.page}',
                    style: context.text.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sample.detail,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${sample.page}쪽 · ${sample.layout}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: t.ink3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureNote extends StatelessWidget {
  const _FailureNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: t.riskBg,
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: t.risk, size: 20),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: t.risk,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingOverlay extends StatelessWidget {
  const _ReadingOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Positioned.fill(
      child: ColoredBox(
        color: t.paper.withValues(alpha: 0.86),
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: '$label에서 글자를 읽는 중',
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(Space.xl),
              decoration: BoxDecoration(
                color: t.ink,
                borderRadius: BorderRadius.circular(Radii.card),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.highlight_outlined, color: t.marker),
                  const SizedBox(height: Space.md),
                  Text(
                    '글자를 읽는 중',
                    style: context.text.titleMedium?.copyWith(
                      color: t.sheet,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '일본어와 한국어로 두 번 읽고 표를 정리해요',
                    style: TextStyle(
                      color: t.sheet.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.chip),
                    child: LinearProgressIndicator(
                      color: t.marker,
                      backgroundColor: t.sheet.withValues(alpha: 0.15),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
