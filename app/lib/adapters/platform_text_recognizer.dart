import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shiori_core/shiori_core.dart';

/// Device OCR block: Apple Vision on iOS (ios/Runner/OcrChannel.swift),
/// ML Kit on Android (android/.../OcrChannel.kt).
///
/// Both channels answer `recognize(path)` with `{"ja": OcrPage, "ko": OcrPage}` JSON,
/// the same shape the research probe recorded.
final class PlatformTextRecognizer implements TextRecognizer {
  const PlatformTextRecognizer({MethodChannel channel = defaultChannel})
    : _channel = channel;

  static const MethodChannel defaultChannel = MethodChannel('shiori/ocr');

  final MethodChannel _channel;

  @override
  String get id =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'apple-vision' : 'mlkit';

  @override
  Future<OcrScan> recognize(PageImage image) async {
    try {
      final payload = await _channel.invokeMethod<String>('recognize', {
        'path': image.path,
      });
      if (payload == null || payload.isEmpty) {
        throw const TextRecognitionException('글자 인식 결과가 비어 있습니다');
      }
      final json = jsonDecode(payload);
      if (json is! Map) {
        throw const FormatException('OCR payload must be a JSON object');
      }
      return OcrScan.fromJson(json.cast<String, Object?>());
    } on PlatformException catch (e) {
      throw TextRecognitionException(_message(e), cause: e);
    } on MissingPluginException catch (e) {
      throw TextRecognitionException('이 기기에서는 글자 인식을 쓸 수 없습니다', cause: e);
    } on FormatException catch (e) {
      throw TextRecognitionException('글자 인식 결과의 형식이 올바르지 않습니다', cause: e);
    }
  }

  static String _message(PlatformException e) => switch (e.code) {
    'bad_image' => '사진을 열 수 없습니다',
    'bad_args' => '사진 경로가 전달되지 않았습니다',
    _ => '글자를 읽지 못했습니다',
  };
}
