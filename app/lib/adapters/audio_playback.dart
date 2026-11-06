import 'dart:io';

import 'package:flutter/services.dart';

/// Plays a sound file made by the pronunciation block.
abstract interface class AudioPlayback {
  /// Stops what plays, then plays [file] from the start. Completes when it
  /// has started; throws when it cannot.
  Future<void> play(File file);

  Future<void> stop();
}

/// [AudioPlayback] through the platform channel `shiori/audio`
/// (ios/Runner/AudioChannel.swift, android …/AudioChannel.kt). The platform
/// side plays only files inside the app's cache folder.
final class ChannelAudioPlayback implements AudioPlayback {
  const ChannelAudioPlayback([
    this._channel = const MethodChannel('shiori/audio'),
  ]);

  final MethodChannel _channel;

  @override
  Future<void> play(File file) =>
      _channel.invokeMethod<void>('play', {'path': file.path});

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');
}
