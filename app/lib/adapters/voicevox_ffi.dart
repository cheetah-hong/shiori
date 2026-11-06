// dart:ffi bindings for the few VOICEVOX core 0.17 C API functions the app
// uses (voicevox_core.h of the official release).
//
// Ownership, from the header:
// - OpenJtalkRc: voicevox_open_jtalk_rc_new → voicevox_open_jtalk_rc_delete
// - VoicevoxSynthesizer: voicevox_synthesizer_new → voicevox_synthesizer_delete
//   (it keeps its own reference to the OpenJtalkRc)
// - VoicevoxVoiceModelFile: voicevox_voice_model_file_open →
//   voicevox_voice_model_file_delete, right after it is loaded
// - JSON strings: voicevox_string_free; WAV bytes: voicevox_bytes_free
// - VoicevoxOnnxruntime: one per process, never freed
// - voicevox_error_result_to_message: a static string, never freed
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final class _LoadOnnxruntimeOptions extends Struct {
  external Pointer<Utf8> filename;
}

final class _InitializeOptions extends Struct {
  @Int32()
  external int accelerationMode;
  @Uint16()
  external int cpuNumThreads;
}

final class _LoadVoiceModelOptions extends Struct {
  @Int32()
  external int onExisting;
}

final class _SynthesisOptions extends Struct {
  @Bool()
  external bool enableInterrogativeUpspeak;
}

typedef _Rc = Int32;
typedef _JsonFn =
    int Function(Pointer<Void>, Pointer<Utf8>, int, Pointer<Pointer<Utf8>>);
typedef _JsonNative =
    _Rc Function(Pointer<Void>, Pointer<Utf8>, Uint32, Pointer<Pointer<Utf8>>);

/// A C API call returned an error code.
final class VoicevoxError implements Exception {
  const VoicevoxError(this.call, this.code, this.message);

  final String call;
  final int code;
  final String message;

  @override
  String toString() => 'VoicevoxError($call: $code $message)';
}

/// The engine library, one per isolate that uses it.
final class VoicevoxLibrary {
  VoicevoxLibrary._(this._lib);

  /// iOS: the frameworks are linked into the app, so the symbols are in the
  /// process. Android: `libvoicevox_core.so` from the app's native libraries.
  /// Throws when the library is not in this build.
  factory VoicevoxLibrary.open() {
    if (Platform.isIOS) return VoicevoxLibrary._(DynamicLibrary.process());
    if (Platform.isAndroid) {
      return VoicevoxLibrary._(DynamicLibrary.open('libvoicevox_core.so'));
    }
    throw UnsupportedError('VOICEVOX runs on iOS and Android only');
  }

  final DynamicLibrary _lib;

  late final _errorMessage = _lib
      .lookupFunction<Pointer<Utf8> Function(_Rc), Pointer<Utf8> Function(int)>(
        'voicevox_error_result_to_message',
      );

  void _check(int rc, String call) {
    if (rc != 0) {
      throw VoicevoxError(call, rc, _errorMessage(rc).toDartString());
    }
  }

  late final String version = _lib
      .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'voicevox_get_version',
      )()
      .toDartString();

  /// The process's ONNX Runtime: linked on iOS (`init_once`), loaded by
  /// name elsewhere (`load_once`).
  Pointer<Void> onnxruntime() => using((arena) {
    final out = arena<Pointer<Void>>();
    if (Platform.isIOS) {
      final init = _lib
          .lookupFunction<
            _Rc Function(Pointer<Pointer<Void>>),
            int Function(Pointer<Pointer<Void>>)
          >('voicevox_onnxruntime_init_once');
      _check(init(out), 'onnxruntime_init_once');
    } else {
      final load = _lib
          .lookupFunction<
            _Rc Function(_LoadOnnxruntimeOptions, Pointer<Pointer<Void>>),
            int Function(_LoadOnnxruntimeOptions, Pointer<Pointer<Void>>)
          >('voicevox_onnxruntime_load_once');
      final options = arena<_LoadOnnxruntimeOptions>();
      options.ref.filename = 'libvoicevox_onnxruntime.so'.toNativeUtf8(
        allocator: arena,
      );
      _check(load(options.ref, out), 'onnxruntime_load_once');
    }
    return out.value;
  });

  Pointer<Void> openJtalk(String dictionaryDir) => using((arena) {
    final open = _lib
        .lookupFunction<
          _Rc Function(Pointer<Utf8>, Pointer<Pointer<Void>>),
          int Function(Pointer<Utf8>, Pointer<Pointer<Void>>)
        >('voicevox_open_jtalk_rc_new');
    final out = arena<Pointer<Void>>();
    _check(
      open(dictionaryDir.toNativeUtf8(allocator: arena), out),
      'open_jtalk_rc_new',
    );
    return out.value;
  });

  void deleteOpenJtalk(Pointer<Void> openJtalk) =>
      _lib.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('voicevox_open_jtalk_rc_delete')(openJtalk);

  Pointer<Void> synthesizer(
    Pointer<Void> onnxruntime,
    Pointer<Void> openJtalk,
  ) {
    final defaults = _lib
        .lookupFunction<
          _InitializeOptions Function(),
          _InitializeOptions Function()
        >('voicevox_make_default_initialize_options');
    final create = _lib
        .lookupFunction<
          _Rc Function(
            Pointer<Void>,
            Pointer<Void>,
            _InitializeOptions,
            Pointer<Pointer<Void>>,
          ),
          int Function(
            Pointer<Void>,
            Pointer<Void>,
            _InitializeOptions,
            Pointer<Pointer<Void>>,
          )
        >('voicevox_synthesizer_new');
    return using((arena) {
      final out = arena<Pointer<Void>>();
      _check(
        create(onnxruntime, openJtalk, defaults(), out),
        'synthesizer_new',
      );
      return out.value;
    });
  }

  void deleteSynthesizer(Pointer<Void> synthesizer) =>
      _lib.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('voicevox_synthesizer_delete')(synthesizer);

  /// Opens the model file, loads it into [synthesizer] and closes the file.
  void loadModel(Pointer<Void> synthesizer, String path) => using((arena) {
    final open = _lib
        .lookupFunction<
          _Rc Function(Pointer<Utf8>, Pointer<Pointer<Void>>),
          int Function(Pointer<Utf8>, Pointer<Pointer<Void>>)
        >('voicevox_voice_model_file_open');
    final close = _lib
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('voicevox_voice_model_file_delete');
    final defaults = _lib
        .lookupFunction<
          _LoadVoiceModelOptions Function(),
          _LoadVoiceModelOptions Function()
        >('voicevox_make_default_load_voice_model_options');
    final load = _lib
        .lookupFunction<
          _Rc Function(Pointer<Void>, Pointer<Void>, _LoadVoiceModelOptions),
          int Function(Pointer<Void>, Pointer<Void>, _LoadVoiceModelOptions)
        >('voicevox_synthesizer_load_voice_model');
    final out = arena<Pointer<Void>>();
    _check(
      open(path.toNativeUtf8(allocator: arena), out),
      'voice_model_file_open',
    );
    try {
      _check(load(synthesizer, out.value, defaults()), 'load_voice_model');
    } finally {
      close(out.value);
    }
  });

  late final _stringFree = _lib
      .lookupFunction<
        Void Function(Pointer<Utf8>),
        void Function(Pointer<Utf8>)
      >('voicevox_string_free');

  String _json(
    String name,
    Pointer<Void> synthesizer,
    String input,
    int styleId,
  ) => using((arena) {
    final f = _lib.lookupFunction<_JsonNative, _JsonFn>('voicevox_$name');
    final out = arena<Pointer<Utf8>>();
    _check(
      f(synthesizer, input.toNativeUtf8(allocator: arena), styleId, out),
      name,
    );
    try {
      return out.value.toDartString();
    } finally {
      _stringFree(out.value);
    }
  });

  /// Accent phrases JSON of VOICEVOX kana.
  String accentPhrasesFromKana(Pointer<Void> s, String kana, int styleId) =>
      _json('synthesizer_create_accent_phrases_from_kana', s, kana, styleId);

  /// Accent phrases JSON of Japanese text.
  String accentPhrasesFromText(Pointer<Void> s, String text, int styleId) =>
      _json('synthesizer_create_accent_phrases', s, text, styleId);

  /// The phrases with their pitches made again.
  String replaceMoraPitch(Pointer<Void> s, String phrasesJson, int styleId) =>
      _json('synthesizer_replace_mora_pitch', s, phrasesJson, styleId);

  /// An audio query JSON of accent phrases JSON.
  String audioQueryOf(String phrasesJson) => using((arena) {
    final f = _lib
        .lookupFunction<
          _Rc Function(Pointer<Utf8>, Pointer<Pointer<Utf8>>),
          int Function(Pointer<Utf8>, Pointer<Pointer<Utf8>>)
        >('voicevox_audio_query_create_from_accent_phrases');
    final out = arena<Pointer<Utf8>>();
    _check(
      f(phrasesJson.toNativeUtf8(allocator: arena), out),
      'audio_query_create_from_accent_phrases',
    );
    try {
      return out.value.toDartString();
    } finally {
      _stringFree(out.value);
    }
  });

  /// WAV of an audio query (copied into Dart memory, the C buffer freed).
  Uint8List synthesis(Pointer<Void> s, String queryJson, int styleId) {
    final defaults = _lib
        .lookupFunction<
          _SynthesisOptions Function(),
          _SynthesisOptions Function()
        >('voicevox_make_default_synthesis_options');
    final synth = _lib
        .lookupFunction<
          _Rc Function(
            Pointer<Void>,
            Pointer<Utf8>,
            Uint32,
            _SynthesisOptions,
            Pointer<UintPtr>,
            Pointer<Pointer<Uint8>>,
          ),
          int Function(
            Pointer<Void>,
            Pointer<Utf8>,
            int,
            _SynthesisOptions,
            Pointer<UintPtr>,
            Pointer<Pointer<Uint8>>,
          )
        >('voicevox_synthesizer_synthesis');
    final free = _lib
        .lookupFunction<
          Void Function(Pointer<Uint8>),
          void Function(Pointer<Uint8>)
        >('voicevox_bytes_free');
    return using((arena) {
      final length = arena<UintPtr>();
      final out = arena<Pointer<Uint8>>();
      _check(
        synth(
          s,
          queryJson.toNativeUtf8(allocator: arena),
          styleId,
          defaults(),
          length,
          out,
        ),
        'synthesis',
      );
      try {
        return Uint8List.fromList(out.value.asTypedList(length.value));
      } finally {
        free(out.value);
      }
    });
  }
}
