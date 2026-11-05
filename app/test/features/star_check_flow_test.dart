// The capture flow runs the ★ check after ML Kit and hands the result to the
// review screen; a Vision page or a failing check leaves the page as read.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/platform_star_meter.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/capture/capture_controller.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

/// The synthetic pages in the ML Kit shape (`m011`, `m140`), kept in core.
const _mlKitDir = '../packages/core/test/fixtures/synthetic_mlkit';

final _mlKitRecognizer = FixtureTextRecognizer(
  (name) => SynchronousFuture(File('$_mlKitDir/$name').readAsStringSync()),
);

final class _Camera implements ImageSource {
  _Camera(this.page);

  final String page;
  final discarded = <String>[];

  @override
  Future<PageImage?> pick(ImageOrigin origin) async => PageImage(page);

  @override
  Future<void> discard(PageImage image) async => discarded.add(image.path);
}

/// Shares 0.01 for the cells of [starred] numbers; or throws [error].
final class _Meter implements StarMeter {
  _Meter(this.starred, {this.error});

  final Set<String> starred;
  final Object? error;
  final calls = <(PageImage, List<StarCell>, int)>[];

  @override
  String get id => 'fake';

  @override
  Future<StarMeasurement?> measure(
    PageImage image, {
    required List<StarCell> cells,
    required StarColor color,
    int turned = 0,
  }) async {
    calls.add((image, cells, turned));
    if (error case final e?) throw e;
    return StarMeasurement([
      for (final c in cells) starred.contains(c.no) ? 0.01 : 0.0,
    ]);
  }
}

/// Never answers: a channel stuck on a big photo.
final class _StuckMeter implements StarMeter {
  @override
  String get id => 'stuck';

  @override
  Future<StarMeasurement?> measure(
    PageImage image, {
    required List<StarCell> cells,
    required StarColor color,
    int turned = 0,
  }) => Completer<StarMeasurement?>().future;
}

Future<CaptureState> _capture({
  required String page,
  required TextRecognizer recognizer,
  required StarMeter meter,
}) async {
  final camera = _Camera(page);
  final c = ProviderContainer.test(
    overrides: [
      imageSourceProvider.overrideWithValue(camera),
      textRecognizerProvider.overrideWithValue(recognizer),
      starMeterProvider.overrideWithValue(meter),
      capturePipelineProvider.overrideWithValue(CapturePipeline.standard()),
    ],
  );
  c.listen(captureControllerProvider, (_, _) {});
  await c.read(captureControllerProvider.notifier).pick(ImageOrigin.camera);
  expect(camera.discarded, [page], reason: 'the photo is still freed');
  return c.read(captureControllerProvider);
}

CaptureDraft _ready(CaptureState state) {
  expect(state, isA<CaptureReady>());
  return (state as CaptureReady).draft;
}

CapturedEntry _entry(CaptureDraft d, String no) =>
    d.entries.firstWhere((e) => e.no == no);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the ★ check is a block slot; the channel block comes first', () {
    final c = ProviderContainer.test();
    expect(c.read(starMeterProvider), isA<PlatformStarMeter>());
  });

  test(
    'ML Kit page: the ★ found on the photo reaches the review draft',
    () async {
      final meter = _Meter({'0013'});
      final draft = _ready(
        await _capture(
          page: 'm011',
          recognizer: _mlKitRecognizer,
          meter: meter,
        ),
      );
      expect(meter.calls, hasLength(1));
      expect(meter.calls.single.$1, const PageImage('m011'));
      expect(meter.calls.single.$3, 0);
      final e = _entry(draft, '0013');
      expect(e.important, isTrue);
      expect(e.statusOf(EntryField.important), FieldStatus.inferred);
      expect(_entry(draft, '0014').important, isFalse);
    },
  );

  test('ML Kit entry page: nothing to measure (no call)', () async {
    final meter = _Meter({'1215'});
    final draft = _ready(
      await _capture(page: 'm140', recognizer: _mlKitRecognizer, meter: meter),
    );
    expect(meter.calls, isEmpty);
    expect(_entry(draft, '1215').important, isFalse);
  });

  test('Vision page: the photo is not measured (no call)', () async {
    final meter = _Meter({'0013'});
    final draft = _ready(
      await _capture(
        page: 's011',
        recognizer: fixtureFileRecognizer,
        meter: meter,
      ),
    );
    expect(meter.calls, isEmpty);
    expect(_entry(draft, '0013').important, isFalse);
  });

  test('a failing check still completes the capture, ★ unchanged', () async {
    for (final error in [
      const FileSystemException('gone'),
      PlatformException(code: 'bad_image'),
      StateError('bug in the block'),
    ]) {
      final meter = _Meter({'0013'}, error: error);
      final draft = _ready(
        await _capture(
          page: 'm011',
          recognizer: _mlKitRecognizer,
          meter: meter,
        ),
      );
      expect(meter.calls, hasLength(1), reason: '$error');
      expect(_entry(draft, '0013').important, isFalse, reason: '$error');
    }
  });

  test(
    'a check that never answers is given up; the capture completes',
    () async {
      // Waits for the real limit (a few seconds).
      final draft = _ready(
        await _capture(
          page: 'm011',
          recognizer: _mlKitRecognizer,
          meter: _StuckMeter(),
        ),
      );
      expect(_entry(draft, '0013').important, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
