import 'dart:async';
import 'dart:io';

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
    this.scan,
    this.photo,
  });

  final CaptureDraft draft;
  final PageImage image;
  final String recognizerId;

  /// The OCR passes (the review screen draws them when there is no photo).
  final OcrScan? scan;

  /// The photo's bytes, kept for the evidence view after its file is gone.
  final Uint8List? photo;
}

final class CaptureFailed extends CaptureState {
  const CaptureFailed(this.message);

  final String message;
}

/// Reads a page photo's bytes for the review screen's evidence view; null
/// when it cannot be read (the view then draws the OCR text instead).
typedef PhotoReader = Future<Uint8List?> Function(PageImage image);

/// Photos above this size are not kept for the evidence view (memory).
const int maxKeptPhotoBytes = 24 * 1024 * 1024;

/// Reads synchronously: a few megabytes once per page, while the reading
/// overlay is up, and it completes in widget tests (no real I/O).
Future<Uint8List?> _readPhotoFile(PageImage image) async {
  try {
    final file = File(image.path);
    if (!file.existsSync() || file.lengthSync() > maxKeptPhotoBytes) {
      return null;
    }
    return file.readAsBytesSync();
  } on FileSystemException catch (e) {
    debugPrint('photo for the evidence view: ${e.message}');
    return null;
  }
}

/// How the capture keeps the photo for the review screen. Tests override it.
final photoReaderProvider = Provider<PhotoReader>((ref) => _readPhotoFile);

/// Photo (or sample) → `TextRecognizer` block → word extractor → review
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
        await _read(
          image,
          ref.read(textRecognizerProvider),
          keepPhoto: ref.read(photoReaderProvider),
        );
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

  /// The bundled dictionaries start opening with the app (`main.dart`). A
  /// page waits for them so the extractor is built on them even for the
  /// first page; they never fail (without data they are empty blocks).
  Future<void> _dictionariesOpened() => Future.wait<void>([
    ref.read(bundledDictionaryProvider.future).then((_) {}, onError: _ignore),
    ref.read(bundledGlossaryProvider.future).then((_) {}, onError: _ignore),
  ]);

  static void _ignore(Object _) {}

  /// The headwords the learner hid (이미 알아요), for the extractor to skip.
  /// Other library words stay on the review: which playlist they go to is
  /// picked after it, and a word already there is skipped then.
  Future<Set<String>> _knownHeadwords() async {
    final library = ref.read(libraryRepositoryProvider);
    if (library is! HiddenWordRepository) return const {};
    return {
      for (final w in await (library as HiddenWordRepository).hiddenWords())
        w.headword,
    };
  }

  Future<void> _read(
    PageImage image,
    TextRecognizer recognizer, {
    PhotoReader? keepPhoto,
  }) async {
    state = CaptureReading(image);
    try {
      final scan = await recognizer.recognize(image);
      if (!ref.mounted) return;
      final photo = keepPhoto == null ? null : await keepPhoto(image);
      if (!ref.mounted) return;
      await _dictionariesOpened();
      if (!ref.mounted) return;
      final known = await _knownHeadwords();
      if (!ref.mounted) return;
      final draft = await pageDraft(
        ref.read(generalExtractorProvider),
        scan,
        knownHeadwords: known,
      );
      if (!ref.mounted) return;
      state = draft.entries.isEmpty && draft.skippedKnown.isEmpty
          ? const CaptureFailed(
              '이 사진에서 단어를 찾지 못했어요. 페이지 전체가 똑바로 나오게 다시 찍어 주세요.',
            )
          : CaptureReady(
              draft: draft,
              image: image,
              recognizerId: recognizer.id,
              scan: scan,
              photo: photo,
            );
    } on TextRecognitionException catch (e) {
      if (ref.mounted) state = CaptureFailed(e.message);
    } on Exception catch (e, stack) {
      _unexpected(e, stack);
    } on Error catch (e, stack) {
      // A bug in a block. Report it like any uncaught
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
