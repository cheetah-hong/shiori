import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/platform_star_meter.dart';
import 'package:shiori/adapters/platform_text_recognizer.dart';
import 'package:shiori_core/shiori_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = PlatformTextRecognizer.defaultChannel;
  const meter = PlatformStarMeter();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Future<Object?> Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, handler);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  const cells = [
    StarCell(
      entryIndex: 0,
      no: '0013',
      x: 0.37,
      y: 0.18,
      width: 0.06,
      height: 0.027,
    ),
    StarCell(
      entryIndex: 2,
      no: '0016',
      x: 0.366,
      y: 0.32,
      width: 0.064,
      height: 0.027,
    ),
  ];
  const color = StarColor(minRed: 120, minRedLead: 45, minShare: 0.002);

  test('sends path, cells, colour and turn; parses the shares', () async {
    MethodCall? seen;
    answer((call) async {
      seen = call;
      return jsonEncode({
        'ratios': [0.0123, 0],
        'ms': 41,
      });
    });
    final out = await meter.measure(
      const PageImage('/data/page.jpg'),
      cells: cells,
      color: color,
      turned: 90,
    );
    expect(seen?.method, 'measureStars');
    expect(seen?.arguments, {
      'path': '/data/page.jpg',
      'cells': [
        {'x': 0.37, 'y': 0.18, 'w': 0.06, 'h': 0.027},
        {'x': 0.366, 'y': 0.32, 'w': 0.064, 'h': 0.027},
      ],
      'color': {'minRed': 120, 'minRedLead': 45},
      'turned': 90,
    });
    expect(out?.ratios, [0.0123, 0.0]);
    expect(out?.elapsed, const Duration(milliseconds: 41));
  });

  // iOS answers measureStars with notImplemented, which arrives here as a
  // MissingPluginException, like a platform without the channel.
  test('no channel or no method (iOS) measures nothing', () async {
    answer((call) async => throw MissingPluginException('no measureStars'));
    expect(
      await meter.measure(const PageImage('a'), cells: cells, color: color),
      isNull,
    );
  });

  test('an empty answer measures nothing', () async {
    answer((call) async => null);
    expect(
      await meter.measure(const PageImage('a'), cells: cells, color: color),
      isNull,
    );
  });

  test('a native error (PlatformException) measures nothing', () async {
    for (final code in ['bad_image', 'bad_args', 'ocr_failed']) {
      answer((call) async => throw PlatformException(code: code));
      expect(
        await meter.measure(const PageImage('a'), cells: cells, color: color),
        isNull,
        reason: code,
      );
    }
  });

  test('a malformed answer measures nothing', () async {
    for (final payload in [
      '',
      '[1]',
      '{"ratios": "x"}',
      '{"ratios": [0.1, null]}',
    ]) {
      answer((call) async => payload);
      expect(
        await meter.measure(const PageImage('a'), cells: cells, color: color),
        isNull,
        reason: payload,
      );
    }
  });
}
