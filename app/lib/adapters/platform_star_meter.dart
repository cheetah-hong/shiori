import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:shiori/adapters/platform_text_recognizer.dart';
import 'package:shiori_core/shiori_core.dart';

/// ★ check on the photo through the OCR channel (`measureStars`, Android).
///
/// Sends the cells and the ★ colour; the channel decodes a small copy of the
/// photo in the frame `recognize` returned (EXIF rotation, then [turned]) and
/// answers `{"ratios": [...], "ms": n}`, one red-pixel share per cell.
///
/// Measures nothing (null) when the channel cannot: iOS answers
/// `notImplemented` (Vision with its star pass needs no check), the photo is
/// gone, or the answer is malformed. The reason goes to the log.
final class PlatformStarMeter implements StarMeter {
  const PlatformStarMeter({
    MethodChannel channel = PlatformTextRecognizer.defaultChannel,
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  String get id => 'channel';

  @override
  Future<StarMeasurement?> measure(
    PageImage image, {
    required List<StarCell> cells,
    required StarColor color,
    int turned = 0,
  }) async {
    try {
      final payload = await _channel.invokeMethod<String>('measureStars', {
        'path': image.path,
        'cells': [
          for (final c in cells)
            {'x': c.x, 'y': c.y, 'w': c.width, 'h': c.height},
        ],
        'color': color.toJson(),
        'turned': turned,
      });
      return _parse(payload);
    } on MissingPluginException catch (e) {
      _log('no measureStars on this platform', e);
    } on PlatformException catch (e) {
      _log('measureStars failed: ${e.code} ${e.message ?? ''}', e);
    } on FormatException catch (e) {
      _log('measureStars answer is malformed', e);
    }
    return null;
  }

  static StarMeasurement _parse(String? payload) {
    if (payload == null || payload.isEmpty) {
      throw const FormatException('empty answer');
    }
    final json = jsonDecode(payload);
    if (json case {
      'ratios': final List<Object?> ratios,
    } when ratios.every((r) => r is num && r.isFinite)) {
      final ms = json['ms'];
      return StarMeasurement([
        for (final r in ratios) (r! as num).toDouble(),
      ], elapsed: Duration(milliseconds: ms is num ? ms.round() : 0));
    }
    throw FormatException('no "ratios" list of numbers', payload);
  }

  static void _log(String message, Object error) =>
      developer.log(message, name: 'shiori.stars', error: error);
}
