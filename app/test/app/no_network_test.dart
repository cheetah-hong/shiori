// D7: the app makes no network calls. Dictionary updates are built by the
// development tools (tools/dict) and ship inside the app; nothing in the app
// or its packages opens a connection or asks for the permission to.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app and the packages it is built from (paths from app/).
const _packages = [
  '.',
  '../packages/core',
  '../packages/dict_jmdict',
  '../packages/jmdict_block',
  '../packages/krdict_block',
  '../packages/storage_drift',
];

/// Packages whose only job is to talk to the network.
const _networkPackages = {
  'http',
  'dio',
  'web_socket_channel',
  'url_launcher',
  'cronet_http',
  'cupertino_http',
  'grpc',
  'firebase_core',
};

/// Code that opens a connection.
final _networkCode = RegExp(
  r"HttpClient\b|package:http/|package:dio/|WebSocket\b|"
  r'\bSocket\.connect|\bRawSocket\b|SecureSocket|HttpServer\b|'
  r'\bdart:html\b|package:web_socket',
);

/// Names under `dependencies:` (not dev_dependencies) of a pubspec.
Set<String> _dependencies(String pubspec) {
  final names = <String>{};
  var inside = false;
  for (final line in pubspec.split('\n')) {
    if (RegExp(r'^\S').hasMatch(line)) inside = line.trim() == 'dependencies:';
    final m = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
    if (inside && m != null) names.add(m.group(1)!);
  }
  return names;
}

void main() {
  test('no package depends directly on a network client', () {
    for (final dir in _packages) {
      final deps = _dependencies(File('$dir/pubspec.yaml').readAsStringSync());
      expect(deps, isNotEmpty, reason: '$dir/pubspec.yaml has dependencies');
      expect(
        deps.intersection(_networkPackages),
        isEmpty,
        reason: '$dir/pubspec.yaml',
      );
    }
  });

  test('no library code opens a connection', () {
    final offenders = <String>[];
    for (final dir in _packages) {
      final lib = Directory('$dir/lib');
      expect(lib.existsSync(), isTrue, reason: lib.path);
      for (final f in lib.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (final (i, line) in lines.indexed) {
          final code = line.split('//').first;
          if (_networkCode.hasMatch(code)) offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the released Android app asks for no internet permission', () {
    // debug/ and profile/ add it for Flutter's development tools only.
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, isNot(contains('android.permission.INTERNET')));
  });

  test('the pattern catches what it is meant to catch', () {
    for (final code in [
      'final c = HttpClient();',
      "import 'package:http/http.dart' as http;",
      'await Socket.connect(host, 80);',
      'WebSocket.connect(url)',
    ]) {
      expect(_networkCode.hasMatch(code), isTrue, reason: code);
    }
    expect(_networkCode.hasMatch('final socketCount = 0;'), isFalse);
  });
}
