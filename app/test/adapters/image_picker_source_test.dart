import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:shiori/adapters/image_picker_source.dart';
import 'package:shiori_core/shiori_core.dart';

final class _FakePicker extends picker.ImagePicker {
  _FakePicker({this.file, this.error});

  final picker.XFile? file;
  final PlatformException? error;

  @override
  Future<picker.XFile?> pickImage({
    required picker.ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    picker.CameraDevice preferredCameraDevice = picker.CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    final e = error;
    if (e != null) throw e;
    return file;
  }
}

void main() {
  test('returns the picked photo, or null when cancelled', () async {
    final picked = await ImagePickerSource(
      imagePicker: _FakePicker(file: picker.XFile('/tmp/page.jpg')),
    ).pick(ImageOrigin.camera);
    expect(picked, const PageImage('/tmp/page.jpg', label: '방금 찍은 사진'));
    expect(
      await ImagePickerSource(
        imagePicker: _FakePicker(),
      ).pick(ImageOrigin.gallery),
      isNull,
    );
  });

  test('platform errors become Korean messages', () async {
    final source = ImagePickerSource(
      imagePicker: _FakePicker(
        error: PlatformException(code: 'no_available_camera'),
      ),
    );
    await expectLater(
      source.pick(ImageOrigin.camera),
      throwsA(
        isA<ImageSourceException>().having(
          (e) => e.message,
          'message',
          contains('카메라를 쓸 수 없어요'),
        ),
      ),
    );
    expect(
      ImagePickerSource.messageFor(
        ImageOrigin.gallery,
        PlatformException(code: 'photo_access_denied'),
      ),
      contains('사진 권한'),
    );
    expect(
      ImagePickerSource.messageFor(
        ImageOrigin.camera,
        PlatformException(code: 'camera_access_denied'),
      ),
      contains('카메라'),
    );
    expect(
      ImagePickerSource.messageFor(
        ImageOrigin.gallery,
        PlatformException(code: 'x'),
      ),
      '사진을 가져오지 못했어요',
    );
  });

  test(
    'discard deletes the temporary copy and tolerates a missing file',
    () async {
      final dir = await Directory.systemTemp.createTemp('shiori_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/page.jpg')..writeAsBytesSync([1, 2, 3]);
      final source = ImagePickerSource(imagePicker: _FakePicker());
      await source.discard(PageImage(file.path));
      expect(file.existsSync(), isFalse);
      await source.discard(PageImage(file.path)); // already gone: no throw
    },
  );
}
