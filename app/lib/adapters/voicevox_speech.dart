import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/adapters/audio_playback.dart';
import 'package:shiori/adapters/voice_assets.dart';
import 'package:shiori/adapters/voicevox_engine.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

/// Room for made sounds: a word is about 30 KB, a sentence about 150 KB.
const speechCacheBytes = 20 * 1024 * 1024;

/// Guesses the accent of a word the accent data does not have.
abstract interface class AccentEstimator {
  /// Null when it cannot.
  Future<int?> estimateAccent(WordSpeech word);
}

/// The on-device VOICEVOX block: the voice data is unpacked and the engine
/// opened on first use; sounds are made once and kept in the cache.
///
/// - Voice data missing or damaged: the engine is never opened; each request
///   fails with a [SpeechFailure] that says so.
/// - The engine does not open: the request fails, and the next one tries
///   again.
final class VoicevoxSpeech implements Speech, AccentEstimator {
  VoicevoxSpeech({
    required this.isAvailable,
    required Future<VoiceAssetsResult> Function() prepareAssets,
    required Future<VoicevoxOps> Function(VoiceAssetsReady assets) openEngine,
    required Future<SpeechCache> Function() cache,
    required AudioPlayback playback,
    void Function(String message) log = _log,
  }) : _prepareAssets = prepareAssets,
       _openEngine = openEngine,
       _cache = cache,
       _playback = playback,
       _logger = log;

  @override
  final bool isAvailable;

  final Future<VoiceAssetsResult> Function() _prepareAssets;
  final Future<VoicevoxOps> Function(VoiceAssetsReady assets) _openEngine;
  final Future<SpeechCache> Function() _cache;
  final AudioPlayback _playback;
  final void Function(String message) _logger;

  Future<VoiceAssetsResult>? _assets;
  Future<SpeechRenderer>? _renderer;

  /// Bumped by every [speak] and [stop]: a sound made for an older request
  /// is not played over a newer one (or after a stop).
  var _generation = 0;

  @override
  Future<void> speak(SpeechRequest request) async {
    final generation = ++_generation;
    await _stopQuietly();
    final renderer = await _rendererOrFail();
    final File file;
    try {
      file = await renderer.render(request);
    } on Object catch (error) {
      _logger('not made: $request: $error');
      throw SpeechFailure('소리를 만들지 못했어요', cause: error);
    }
    if (generation != _generation) return;
    try {
      await _playback.play(file);
    } on Object catch (error) {
      _logger('not played: $error');
      throw SpeechFailure('소리를 재생하지 못했어요', cause: error);
    }
  }

  @override
  Future<void> stop() {
    _generation++;
    return _playback.stop();
  }

  @override
  Future<int?> estimateAccent(WordSpeech word) async {
    try {
      final renderer = await _rendererOrFail();
      return await renderer.estimateAccent(word);
    } on Object catch (error) {
      _logger('no estimate for ${word.headword}: $error');
      return null;
    }
  }

  Future<void> _stopQuietly() async {
    try {
      await _playback.stop();
    } on Object catch (error) {
      _logger('stop: $error');
    }
  }

  /// The renderer, opening the engine once; a failed opening is forgotten
  /// so the next request tries again (unless the data itself is the
  /// problem, which a retry cannot fix).
  Future<SpeechRenderer> _rendererOrFail() async {
    final assets = await (_assets ??= _prepareAssets());
    switch (assets) {
      case VoiceAssetsUnavailable(:final kind, :final problem):
        if (kind == VoiceAssetsProblem.failed) _assets = null;
        throw SpeechFailure(switch (kind) {
          VoiceAssetsProblem.missing => '이 빌드에는 발음 데이터가 없어요',
          VoiceAssetsProblem.damaged => '발음 데이터가 손상됐어요. 앱을 다시 설치해 주세요',
          VoiceAssetsProblem.failed => '발음 데이터를 준비하지 못했어요. 저장 공간을 확인해 주세요',
        }, cause: problem);
      case final VoiceAssetsReady ready:
        final pending = _renderer ??= _open(ready);
        try {
          final renderer = await pending;
          // An engine whose isolate ended is opened again.
          if (renderer.ops case IsolateVoicevoxEngine(isAlive: false)) {
            if (identical(_renderer, pending)) _renderer = null;
            return _rendererOrFail();
          }
          return renderer;
        } on Object catch (error) {
          if (identical(_renderer, pending)) _renderer = null;
          // The unpacked files may have gone (the system clears the cache
          // folder when storage runs low): check them again next time.
          _assets = null;
          _logger('engine not opened: $error');
          throw SpeechFailure('발음 엔진을 열지 못했어요', cause: error);
        }
    }
  }

  Future<SpeechRenderer> _open(VoiceAssetsReady ready) async =>
      SpeechRenderer(ops: await _openEngine(ready), cache: await _cache());
}

/// The app's [VoicevoxSpeech]: voice data unpacked into the cache folder,
/// the engine through the C API, playback through the platform channel.
///
/// The cache folder, not the support folder: everything there can be made
/// again (from the assets, or by the engine), so it stays out of backups.
VoicevoxSpeech appVoicevoxSpeech() => VoicevoxSpeech(
  isAvailable: !kIsWeb && (Platform.isIOS || Platform.isAndroid),
  prepareAssets: () async => prepareVoiceAssets(
    bundle: rootBundle,
    dir: Directory('${(await getApplicationCacheDirectory()).path}/voice'),
    log: _log,
  ),
  openEngine: IsolateVoicevoxEngine.open,
  cache: () async => SpeechCache(
    dir: Directory('${(await getApplicationCacheDirectory()).path}/speech'),
    maxBytes: speechCacheBytes,
  ),
  playback: const ChannelAudioPlayback(),
);

void _log(String message) => debugPrint('[shiori] speech: $message');
