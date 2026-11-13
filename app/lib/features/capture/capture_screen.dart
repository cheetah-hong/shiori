import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/capture_controller.dart';
import 'package:shiori/features/capture/ocr_export.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori/shared/bottom_action_bar.dart';
import 'package:shiori/shared/dictionary_notice.dart';
import 'package:shiori/shared/ruled.dart';
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
              scan: next.scan,
              photo: next.photo,
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
                  '교재 한 쪽을 위에서 똑바로 찍어 주세요.',
                  style: context.text.bodyMedium?.copyWith(
                    color: t.text2,
                    height: 1.55,
                  ),
                ),
                const _DictionaryNoticeSlot(),
                if (state is CaptureFailed) ...[
                  const SizedBox(height: Space.lg),
                  _FailureNote(
                    message: state.message,
                    scan: state.scan,
                    onRetake: state.retake && !busy
                        ? () => unawaited(controller.pick(ImageOrigin.camera))
                        : null,
                  ),
                ],
                if (showSamples) ...[
                  SectionLabel(
                    '샘플 페이지로 해 보기',
                    trailing: Text(
                      '개발용',
                      style: TextStyle(
                        color: t.warn,
                        fontSize: TypeScale.small,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '미리 판독해 둔 교재 쪽으로 등록 흐름을 끝까지 볼 수 있어요. 배포판에는 없어요.',
                    style: context.text.bodySmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: Space.sm),
                  for (final s in [...devSamples, ...generalDevSamples])
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
      // Both ways in thumb reach: the camera is the main one.
      bottomNavigationBar: BottomActionBar(
        secondary: BarAction(
          label: '앨범에서 고르기',
          onPressed: busy
              ? null
              : () => unawaited(controller.pick(ImageOrigin.gallery)),
        ),
        primary: BarPrimaryButton(
          label: '카메라로 찍기',
          onPressed: busy
              ? null
              : () => unawaited(controller.pick(ImageOrigin.camera)),
        ),
      ),
    );
  }
}

/// The dictionary notice below the photo buttons, with the gap above it
/// only when it shows.
class _DictionaryNoticeSlot extends ConsumerWidget {
  const _DictionaryNoticeSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(dictionaryProblemProvider) == null) {
      return const SizedBox.shrink();
    }
    return const Padding(
      padding: EdgeInsets.only(top: Space.lg),
      child: DictionaryNotice(),
    );
  }
}

/// A development sample as a ruled row: its page number big, like a
/// calendar day, then what it is.
class _SampleTile extends StatelessWidget {
  const _SampleTile({required this.sample, required this.onTap});

  final DevSample sample;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RuledRow(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: _pageNumberWidth,
            child: Text(
              '${sample.page}',
              style: TextStyle(
                color: t.text,
                fontSize: TypeScale.display,
                fontWeight: FontWeight.w600,
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${sample.page}쪽 · ${sample.layout}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_forward, color: t.text3),
        ],
      ),
    );
  }
}

const double _pageNumberWidth = 64;

class _FailureNote extends StatelessWidget {
  const _FailureNote({required this.message, this.scan, this.onRetake});

  final String message;

  /// 다시 찍기 (the photo held no word).
  final VoidCallback? onRetake;

  /// The page's OCR passes, when it was read: the note offers their export.
  final OcrScan? scan;

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
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: t.risk,
              size: 20,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: t.risk,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  if (onRetake case final retake?) ...[
                    const SizedBox(height: Space.md),
                    OutlinedButton(
                      onPressed: retake,
                      child: const Text('다시 찍기'),
                    ),
                  ],
                  if (scan != null) ...[
                    const SizedBox(height: Space.sm),
                    OcrExportFailureButton(scan: scan),
                  ],
                ],
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
        color: t.bg.withValues(alpha: 0.86),
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: '$label에서 글자를 읽는 중',
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(Space.xl),
              decoration: BoxDecoration(
                color: t.bg,
                border: Border(
                  top: BorderSide(color: t.text, width: 4),
                  left: BorderSide(color: t.line),
                  right: BorderSide(color: t.line),
                  bottom: BorderSide(color: t.line),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(CupertinoIcons.viewfinder, color: t.accentText),
                  const SizedBox(height: Space.md),
                  Text(
                    '글자를 읽는 중',
                    style: context.text.titleMedium?.copyWith(
                      color: t.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '일본어와 한국어로 두 번 읽고 표를 정리해요',
                    style: TextStyle(color: t.text2, fontSize: TypeScale.small),
                  ),
                  const SizedBox(height: Space.lg),
                  LinearProgressIndicator(
                    color: t.accent,
                    backgroundColor: t.surfaceStrong,
                    minHeight: 2,
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
