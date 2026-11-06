import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:shiori/adapters/voice_assets.dart';
import 'package:shiori/adapters/voicevox_ffi.dart';
import 'package:voicevox_block/voicevox_block.dart';

/// [VoicevoxOps] on a background isolate that owns the engine: the calls
/// take a few hundred milliseconds and must not block the screen. Requests
/// are answered in order. When the isolate ends, every waiting and later
/// request fails (the caller opens a new engine).
final class IsolateVoicevoxEngine implements VoicevoxOps {
  IsolateVoicevoxEngine._(this._link, this.voiceId);

  /// Starts the isolate, opens the dictionary and loads the model. Throws
  /// when the engine library is not in this build or does not open them.
  static Future<IsolateVoicevoxEngine> open(VoiceAssetsReady assets) async {
    final link = _Link();
    await Isolate.spawn(
      _main,
      (
        link.replies.sendPort,
        assets.dictionaryPath,
        assets.modelPath,
        assets.edition.styleId,
      ),
      onError: link.replies.sendPort,
      onExit: link.replies.sendPort,
    );
    await link.ready.future;
    final e = assets.edition;
    return IsolateVoicevoxEngine._(
      link,
      'voicevox-${e.coreVersion}/${e.variant}/style-${e.styleId}'
      '/speed-$speechSpeedScale',
    );
  }

  final _Link _link;

  @override
  final String voiceId;

  /// False once the isolate has ended.
  bool get isAlive => !_link.dead;

  @override
  Future<List<AccentPhrase>> phrasesFromKana(String kana) async =>
      AccentPhrase.listFromJson(await _link.send<String>('kana', kana));

  @override
  Future<List<AccentPhrase>> phrasesFromText(String text) async =>
      AccentPhrase.listFromJson(await _link.send<String>('text', text));

  @override
  Future<List<AccentPhrase>> replaceMoraPitch(List<AccentPhrase> p) async =>
      AccentPhrase.listFromJson(
        await _link.send<String>('pitch', AccentPhrase.listToJson(p)),
      );

  @override
  Future<Uint8List> synthesize(List<AccentPhrase> phrases) async {
    final wav = await _link.send<TransferableTypedData>(
      'synth',
      AccentPhrase.listToJson(phrases),
    );
    return wav.materialize().asUint8List();
  }
}

/// The main isolate's end of the engine isolate.
final class _Link {
  _Link() {
    replies.listen(_onMessage);
  }

  final replies = ReceivePort();
  final ready = Completer<void>();
  final _pending = <int, Completer<Object?>>{};
  SendPort? _port;
  var _next = 0;
  var dead = false;

  Future<T> send<T>(String op, String input) async {
    final port = _port;
    if (dead || port == null) throw StateError('the engine is not running');
    final id = _next++;
    final done = Completer<Object?>();
    _pending[id] = done;
    port.send((id, op, input));
    return (await done.future) as T;
  }

  void _onMessage(Object? message) {
    switch (message) {
      case final SendPort port:
        _port = port;
        ready.complete();
      case (final int id, final Object? value, final String? error):
        final done = _pending.remove(id);
        if (done == null) return;
        if (error == null) {
          done.complete(value);
        } else {
          done.completeError(StateError(error));
        }
      case (final String error, null):
        _fail(error);
      // An uncaught error in the engine isolate: [error, stack].
      case [final Object? error, _]:
        _fail('engine isolate: $error');
      // The engine isolate ended.
      case null:
        _fail('engine isolate ended');
    }
  }

  void _fail(String why) {
    dead = true;
    if (!ready.isCompleted) ready.completeError(StateError(why));
    for (final done in _pending.values) {
      done.completeError(StateError(why));
    }
    _pending.clear();
    replies.close();
  }
}

/// The engine isolate: opens everything, then answers `(id, op, input)`.
void _main((SendPort, String, String, int) args) {
  final (replies, dictionary, model, styleId) = args;
  final VoicevoxLibrary lib;
  try {
    lib = VoicevoxLibrary.open();
  } on Object catch (error) {
    replies.send(('$error', null));
    Isolate.exit();
  }
  // What is made before a later step fails is freed: the native heap belongs
  // to the process, not to this isolate, and the next request tries again.
  Pointer<Void>? openJtalk;
  Pointer<Void>? made;
  try {
    final ort = lib.onnxruntime();
    openJtalk = lib.openJtalk(dictionary);
    made = lib.synthesizer(ort, openJtalk);
    // The synthesizer keeps its own reference.
    lib.deleteOpenJtalk(openJtalk);
    openJtalk = null;
    lib.loadModel(made, model);
  } on Object catch (error) {
    if (made != null) lib.deleteSynthesizer(made);
    if (openJtalk != null) lib.deleteOpenJtalk(openJtalk);
    replies.send(('$error', null));
    Isolate.exit();
  }
  final synthesizer = made;
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  requests.listen((message) {
    final (id, op, input) = message as (int, String, String);
    try {
      final Object value = switch (op) {
        'kana' => lib.accentPhrasesFromKana(synthesizer, input, styleId),
        'text' => lib.accentPhrasesFromText(synthesizer, input, styleId),
        'pitch' => lib.replaceMoraPitch(synthesizer, input, styleId),
        'synth' => TransferableTypedData.fromList([
          lib.synthesis(
            synthesizer,
            withSpeedScale(lib.audioQueryOf(input), speechSpeedScale),
            styleId,
          ),
        ]),
        _ => throw ArgumentError.value(op, 'op'),
      };
      replies.send((id, value, null));
    } on Object catch (error) {
      replies.send((id, null, '$error'));
    }
  });
}
