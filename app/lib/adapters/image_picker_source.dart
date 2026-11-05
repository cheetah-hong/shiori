import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:shiori_core/shiori_core.dart';

/// First photo block: the system camera and photo album via image_picker.
/// Next block: a document scanner (edge detection, deskew), then page flattening.
final class ImagePickerSource implements ImageSource {
  ImagePickerSource({picker.ImagePicker? imagePicker})
    : _picker = imagePicker ?? picker.ImagePicker();

  final picker.ImagePicker _picker;

  @override
  Future<PageImage?> pick(ImageOrigin origin) async {
    try {
      final file = await _picker.pickImage(
        source: switch (origin) {
          ImageOrigin.camera => picker.ImageSource.camera,
          ImageOrigin.gallery => picker.ImageSource.gallery,
        },
        // Full resolution: small kanji need every pixel. Orientation is read
        // from EXIF on the native side.
        requestFullMetadata: false,
      );
      if (file == null) return null;
      return PageImage(
        file.path,
        label: origin == ImageOrigin.camera ? '방금 찍은 사진' : '앨범 사진',
      );
    } on PlatformException catch (e) {
      throw ImageSourceException(_message(origin, e), cause: e);
    }
  }

  /// image_picker copies each photo into the app's temporary folder; the page
  /// has been read by now, so the copy goes.
  @override
  Future<void> discard(PageImage image) async {
    try {
      await File(image.path).delete();
    } on FileSystemException catch (e) {
      // Already gone (the OS may purge temporary files): nothing to free.
      debugPrint('discard ${image.path}: ${e.message}');
    }
  }

  @visibleForTesting
  static String messageFor(ImageOrigin origin, PlatformException e) =>
      _message(origin, e);

  static String _message(ImageOrigin origin, PlatformException e) {
    if (e.code.contains('camera')) {
      return '이 기기에서는 카메라를 쓸 수 없어요. 앨범이나 샘플 페이지를 써 보세요.';
    }
    if (e.code.contains('access') || e.code.contains('denied')) {
      return origin == ImageOrigin.camera
          ? '카메라 권한이 필요해요. 설정에서 허용해 주세요.'
          : '사진 권한이 필요해요. 설정에서 허용해 주세요.';
    }
    return '사진을 가져오지 못했어요';
  }
}
