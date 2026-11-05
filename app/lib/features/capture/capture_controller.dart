import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';

sealed class CaptureState {
  const CaptureState();
}

final class CaptureIdle extends CaptureState {
  const CaptureIdle();
}

final class CaptureReading extends CaptureState {
  const CaptureReading(this.image);

  final PageImage image;
}

final class CaptureReady extends CaptureState {
  const CaptureReady({
    required this.draft,
    required this.image,
    required this.recognizerId,
  });

  final CaptureDraft draft;
  final PageImage image;
  final String recognizerId;
}

final class CaptureFailed extends CaptureState {
  const CaptureFailed(this.message);

  final String message;
}

/// Photo (or sample) → `TextRecognizer` block → `CapturePipeline` → review
/// draft.
final class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() => const CaptureIdle();

  Future<void> pick(ImageOrigin origin) async {
    try {
      final source = ref.read(imageSourceProvider);
      final image = await source.pick(origin);
      if (image == null || !ref.mounted) return; // cancelled
      try {
        await _read(image, ref.read(textRecognizerProvider));
      } finally {
        await source.discard(image);
      }
    } on ImageSourceException catch (e) {
      if (ref.mounted) state = CaptureFailed(e.message);
    }
  }

  Future<void> sample(DevSample sample) =>
      _read(sample.image, ref.read(sampleRecognizerProvider));

  /// Back to idle once the review screen has taken the draft.
  void reset() => state = const CaptureIdle();

  Future<void> _read(PageImage image, TextRecognizer recognizer) async {
    state = CaptureReading(image);
    try {
      final scan = await recognizer.recognize(image);
      final draft = await ref.read(capturePipelineProvider).fromScan(scan);
      if (!ref.mounted) return;
      state = draft.entries.isEmpty
          ? const CaptureFailed(
              '이 사진에서 단어를 찾지 못했어요. 페이지 전체가 똑바로 나오게 다시 찍어 주세요.',
            )
          : CaptureReady(
              draft: draft,
              image: image,
              recognizerId: recognizer.id,
            );
    } on TextRecognitionException catch (e) {
      if (ref.mounted) state = CaptureFailed(e.message);
    } on Exception catch (e, stack) {
      _unexpected(e, stack);
    } on Error catch (e, stack) {
      // A bug in a template or corrector block. Report it like any uncaught
      // error, but do not leave the reading overlay on screen forever.
      _unexpected(e, stack);
    }
  }

  void _unexpected(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'capture'),
    );
    if (ref.mounted) {
      state = const CaptureFailed('단어를 정리하다가 문제가 생겼어요. 다시 시도해 주세요.');
    }
  }
}

final captureControllerProvider =
    NotifierProvider.autoDispose<CaptureController, CaptureState>(
      CaptureController.new,
    );
