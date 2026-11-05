import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/platform_text_recognizer.dart';
import 'package:shiori_core/shiori_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = PlatformTextRecognizer.defaultChannel;
  const recognizer = PlatformTextRecognizer();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Future<Object?> Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, handler);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sends the photo path and parses both passes', () async {
    MethodCall? seen;
    answer((call) async {
      seen = call;
      return jsonEncode({
        'ja': {
          'engine': 'apple-vision',
          'langs': ['ja-JP', 'ko-KR'],
          'ms': 640,
          'lines': [
            {
              't': '0015 □□□ 川',
              'c': 1,
              'x': 0.1,
              'y': 0.2,
              'w': 0.2,
              'h': 0.02,
            },
          ],
        },
        'ko': {
          'engine': 'apple-vision',
          'langs': ['ko-KR', 'ja-JP'],
          'ms': 600,
          'lines': <Object>[],
        },
      });
    });
    final scan = await recognizer.recognize(const PageImage('/tmp/page.jpg'));
    expect(seen?.method, 'recognize');
    expect(seen?.arguments, {'path': '/tmp/page.jpg'});
    expect(scan.japanese.lines.single.text, '0015 □□□ 川');
    expect(scan.elapsed, const Duration(milliseconds: 1240));
  });

  test('ignores an old "star" pass and the diagnostics keys', () async {
    MethodCall? seen;
    Map<String, Object?> page(int ms, List<Object> lines) => {
      'engine': 'apple-vision',
      'langs': ['ja-JP', 'ko-KR'],
      'ms': ms,
      'lines': lines,
    };
    answer((call) async {
      seen = call;
      return jsonEncode({
        'ja': page(600, []),
        'ko': page(500, []),
        'star': page(450, [
          {'t': '★ かわ', 'c': 0.5, 'x': 0.4, 'y': 0.3, 'w': 0.05, 'h': 0.02},
        ]),
        'turned': 90,
        'timing': {'orient_pass': 610, 'star_binarize': 40},
      });
    });
    final scan = await recognizer.recognize(const PageImage('/tmp/side.jpg'));
    expect(seen?.arguments, {'path': '/tmp/side.jpg'});
    expect(scan.japanese.lines, isEmpty);
    expect(scan.turned, 90);
    expect(scan.toJson(), isNot(contains('star')));
    expect(scan.elapsed, const Duration(milliseconds: 1100));
  });

  test(
    'native errors become recognition errors with a Korean message',
    () async {
      answer(
        (call) async =>
            throw PlatformException(code: 'bad_image', message: 'cannot open'),
      );
      await expectLater(
        recognizer.recognize(const PageImage('/nope.jpg')),
        throwsA(
          isA<TextRecognitionException>().having(
            (e) => e.message,
            'message',
            '사진을 열 수 없습니다',
          ),
        ),
      );
    },
  );

  test('an empty or malformed payload is a recognition error', () async {
    answer((call) async => '');
    await expectLater(
      recognizer.recognize(const PageImage('a')),
      throwsA(isA<TextRecognitionException>()),
    );
    answer((call) async => '[1]');
    await expectLater(
      recognizer.recognize(const PageImage('a')),
      throwsA(isA<TextRecognitionException>()),
    );
  });

  test(
    'a missing channel (unsupported platform) is a recognition error',
    () async {
      await expectLater(
        recognizer.recognize(const PageImage('a')),
        throwsA(isA<TextRecognitionException>()),
      );
    },
  );
}
