import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/voice_assets.dart';

import '../support/dictionary.dart' show MemoryAssetBundle;
import 'voice_assets_test.dart' show voiceBuild;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('voice_assets_stale_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<VoiceAssetsResult> prepare(
    Map<String, List<int>> files, {
    String model = 'model.vvm',
  }) => prepareVoiceAssets(
    bundle: MemoryAssetBundle(
      voiceBuild(files, edit: (json) => {...json, 'model_file': model}).assets,
    ),
    dir: dir,
    log: (_) {},
  );

  test('a new edition removes the files only the old one had', () async {
    await prepare({
      'old.vvm': List<int>.filled(400, 1),
      'dic/sys.dic': List<int>.filled(50, 2),
      'dic/old.def': List<int>.filled(10, 3),
    }, model: 'old.vvm');
    expect(File('${dir.path}/old.vvm').existsSync(), isTrue);

    final result = await prepare({
      'new.vvm': List<int>.filled(500, 4),
      'dic/sys.dic': List<int>.filled(50, 2),
    }, model: 'new.vvm');

    expect(result, isA<VoiceAssetsReady>());
    expect(File('${dir.path}/old.vvm').existsSync(), isFalse);
    expect(File('${dir.path}/dic/old.def').existsSync(), isFalse);
    expect(File('${dir.path}/new.vvm').readAsBytesSync(), hasLength(500));
    expect(File('${dir.path}/dic/sys.dic').readAsBytesSync(), hasLength(50));
  });

  test('the same edition again leaves every file in place', () async {
    final files = {
      'model.vvm': List<int>.filled(300, 5),
      'dic/sys.dic': List<int>.filled(50, 2),
    };
    await prepare(files);

    final again = await prepare(files);

    expect(again, isA<VoiceAssetsReady>());
    expect(File('${dir.path}/model.vvm').existsSync(), isTrue);
    expect(File('${dir.path}/dic/sys.dic').existsSync(), isTrue);
  });
}
