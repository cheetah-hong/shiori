import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/voice_assets.dart';

import '../support/dictionary.dart' show MemoryAssetBundle;

/// A voice edition of [files] (path → content), gzipped as the build tool does.
({Map<String, List<int>> assets, String edition}) voiceBuild(
  Map<String, List<int>> files, {
  Map<String, Object?> Function(Map<String, Object?> json)? edit,
}) {
  final assets = <String, List<int>>{};
  final entries = <Map<String, Object?>>[];
  var n = 0;
  for (final MapEntry(key: path, value: content) in files.entries) {
    final gzName = 'f${n++}.gz';
    final gz = gzip.encode(content);
    assets['$voiceAssetDir/$gzName'] = gz;
    entries.add({
      'path': path,
      'gzip': gzName,
      'gzip_bytes': gz.length,
      'bytes': content.length,
      'sha256': sha256.convert(content).toString(),
    });
  }
  var json = <String, Object?>{
    'variant': 'test-voice',
    'built_on': '2026-11-06',
    'core_version': '0.17.1',
    'model_file': 'model.vvm',
    'dictionary_dir': 'dic',
    'style_id': 10003,
    'credit': 'VOICEVOX Nemo',
    'files': entries,
    'sources': <Object?>[],
  };
  if (edit != null) json = edit(json);
  final edition = jsonEncode(json);
  assets[voiceEditionAsset] = utf8.encode(edition);
  return (assets: assets, edition: edition);
}

void main() {
  late Directory dir;
  final logs = <String>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('voice_assets_test');
    logs.clear();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  final files = {
    'model.vvm': List<int>.generate(3000, (i) => i % 251),
    'dic/sys.dic': utf8.encode('dictionary words'),
    'dic/matrix.bin': List<int>.filled(500, 7),
  };

  Future<VoiceAssetsResult> prepare(Map<String, List<int>> assets) =>
      prepareVoiceAssets(
        bundle: MemoryAssetBundle(assets),
        dir: dir,
        log: logs.add,
      );

  test(
    'unpacks every file, checks it and gives the model and dictionary',
    () async {
      final build = voiceBuild(files);
      final result = await prepare(build.assets);
      final ready = result as VoiceAssetsReady;
      expect(ready.modelPath, '${ready.dir.path}/model.vvm');
      expect(ready.dictionaryPath, '${ready.dir.path}/dic');
      expect(ready.edition.styleId, 10003);
      expect(ready.edition.credit, 'VOICEVOX Nemo');
      for (final MapEntry(key: path, value: content) in files.entries) {
        expect(File('${ready.dir.path}/$path').readAsBytesSync(), content);
      }
    },
  );

  test('a second run with the same edition does not unpack again', () async {
    final build = voiceBuild(files);
    final bundle = MemoryAssetBundle(build.assets);
    await prepareVoiceAssets(bundle: bundle, dir: dir, log: logs.add);
    bundle.loads.clear();
    final again = await prepareVoiceAssets(
      bundle: bundle,
      dir: dir,
      log: logs.add,
    );
    expect(again, isA<VoiceAssetsReady>());
    expect(bundle.loads.where((k) => k.endsWith('.gz')), isEmpty);
  });

  test(
    'a build without the voice edition is missing, nothing written',
    () async {
      final result = await prepare({});
      expect(result, isA<VoiceAssetsUnavailable>());
      expect(
        (result as VoiceAssetsUnavailable).kind,
        VoiceAssetsProblem.missing,
      );
      expect(dir.listSync(recursive: true).whereType<File>(), isEmpty);
    },
  );

  test(
    'content that does not match its sha256 is damaged, nothing kept',
    () async {
      final build = voiceBuild(files);
      final assets = Map.of(build.assets);
      // Same size, other bytes: only the sha256 can tell.
      final key = '$voiceAssetDir/f1.gz';
      assets[key] = gzip.encode(utf8.encode('dictionary wordz'));
      final edition = jsonDecode(build.edition) as Map<String, Object?>;
      final entry = (edition['files']! as List)[1] as Map<String, Object?>;
      entry['gzip_bytes'] = assets[key]!.length;
      assets[voiceEditionAsset] = utf8.encode(jsonEncode(edition));
      final result = await prepare(assets);
      expect(
        (result as VoiceAssetsUnavailable).kind,
        VoiceAssetsProblem.damaged,
      );
      expect(
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => !f.path.endsWith('.part')),
        isEmpty,
      );
    },
  );

  test('a gzip of another size than the edition says is damaged', () async {
    final build = voiceBuild(files);
    final assets = Map.of(build.assets);
    assets['$voiceAssetDir/f0.gz'] = [...assets['$voiceAssetDir/f0.gz']!, 0];
    final result = await prepare(assets);
    expect((result as VoiceAssetsUnavailable).kind, VoiceAssetsProblem.damaged);
  });

  test('a listed gzip missing from the build is damaged', () async {
    final build = voiceBuild(files);
    final assets = Map.of(build.assets)..remove('$voiceAssetDir/f2.gz');
    final result = await prepare(assets);
    expect((result as VoiceAssetsUnavailable).kind, VoiceAssetsProblem.damaged);
  });

  test('a path that leaves the voice folder is refused', () async {
    for (final bad in ['../escape.bin', '/abs/file', 'dic/../../x', '']) {
      final build = voiceBuild({bad: utf8.encode('x'), ...files});
      final result = await prepare(build.assets);
      expect(result, isA<VoiceAssetsUnavailable>(), reason: bad);
      expect(
        (result as VoiceAssetsUnavailable).kind,
        VoiceAssetsProblem.damaged,
        reason: bad,
      );
    }
    expect(File('${dir.parent.path}/escape.bin').existsSync(), isFalse);
  });

  test('a gzip name with a folder in it is refused', () async {
    final build = voiceBuild(
      files,
      edit: (json) {
        ((json['files']! as List).first as Map<String, Object?>)['gzip'] =
            '../dict/x.gz';
        return json;
      },
    );
    final result = await prepare(build.assets);
    expect((result as VoiceAssetsUnavailable).kind, VoiceAssetsProblem.damaged);
  });

  test('an edition without the model or the dictionary is damaged', () async {
    final noModel = voiceBuild({'dic/sys.dic': utf8.encode('d')});
    expect(
      ((await prepare(noModel.assets)) as VoiceAssetsUnavailable).kind,
      VoiceAssetsProblem.damaged,
    );
    final noStyle = voiceBuild(
      files,
      edit: (json) => {...json}..remove('style_id'),
    );
    expect(
      ((await prepare(noStyle.assets)) as VoiceAssetsUnavailable).kind,
      VoiceAssetsProblem.damaged,
    );
  });

  test('an unpacked file changed on disk is unpacked again', () async {
    final build = voiceBuild(files);
    final ready = (await prepare(build.assets)) as VoiceAssetsReady;
    File('${ready.dir.path}/dic/sys.dic').writeAsStringSync('short');
    final again = (await prepare(build.assets)) as VoiceAssetsReady;
    expect(
      File('${again.dir.path}/dic/sys.dic').readAsBytesSync(),
      files['dic/sys.dic'],
    );
  });
}
