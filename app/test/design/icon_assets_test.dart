// U7: the app icon and launch screen files (made by tools/design/make_icons.py;
// its --check keeps them in step with the drawing). Every iOS icon size is
// there, opaque, at its pixel size; the dev icon is its own set and the dev
// build configurations use it; Android has both flavors' icons; the launch
// ground is the page background token, light and dark.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';

const _assets = 'ios/Runner/Assets.xcassets';

/// Width, height and PNG color type (2 = RGB, 6 = RGBA) from the IHDR chunk.
(int, int, int) _png(String path) {
  final b = File(path).readAsBytesSync();
  expect(b.sublist(1, 4), 'PNG'.codeUnits, reason: path);
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20), b[25]);
}

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

Color _colorOf(Map<String, Object?> entry) {
  final c = (entry['color']! as Map)['components']! as Map<String, Object?>;
  int v(String k) => int.parse((c[k]! as String).substring(2), radix: 16);
  return Color.fromARGB(255, v('red'), v('green'), v('blue'));
}

void main() {
  for (final set in ['AppIcon', 'AppIcon-dev']) {
    test('$set: every size, opaque, at its pixel size', () {
      final folder = '$_assets/$set.appiconset';
      final images = (_json('$folder/Contents.json')['images']! as List)
          .cast<Map<String, Object?>>();
      expect(images, isNotEmpty);
      expect(
        images.map((i) => i['size']),
        containsAll(['20x20', '29x29', '40x40', '60x60', '1024x1024']),
      );
      for (final i in images) {
        final points = double.parse((i['size']! as String).split('x').first);
        final scale = int.parse((i['scale']! as String)[0]);
        final (w, h, type) = _png('$folder/${i['filename']}');
        expect((w, h), ((points * scale).round(), (points * scale).round()));
        expect(type, 2, reason: '${i['filename']} has no alpha');
      }
    });
  }

  test('the dev icon differs from the shipped one', () {
    const name = 'Icon-App-1024x1024@1x.png';
    expect(
      File('$_assets/AppIcon-dev.appiconset/$name').readAsBytesSync(),
      isNot(File('$_assets/AppIcon.appiconset/$name').readAsBytesSync()),
    );
  });

  test('dev build configurations use AppIcon-dev, prod ones AppIcon', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(
      RegExp(
        'ASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-dev";',
      ).allMatches(project).length,
      3,
    );
    expect(
      RegExp(
        'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
      ).allMatches(project).length,
      3,
    );
  });

  test('the launch screen lies on the page background, light and dark', () {
    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    expect(storyboard, contains('name="LaunchBackground"'));
    expect(storyboard, contains('image="LaunchImage"'));

    final colors =
        (_json('$_assets/LaunchBackground.colorset/Contents.json')['colors']!
                as List)
            .cast<Map<String, Object?>>();
    final light = colors.singleWhere((c) => c['appearances'] == null);
    final dark = colors.singleWhere((c) => c['appearances'] != null);
    expect(_colorOf(light), ShioriTokens.light.bg);
    expect(_colorOf(dark), ShioriTokens.dark.bg);

    final images =
        (_json('$_assets/LaunchImage.imageset/Contents.json')['images']!
                as List)
            .cast<Map<String, Object?>>();
    for (final i in images) {
      expect(
        File('$_assets/LaunchImage.imageset/${i['filename']}').existsSync(),
        isTrue,
        reason: '${i['filename']}',
      );
    }
  });

  test('Android: both flavors have the legacy and the adaptive icon', () {
    for (final flavor in ['main', 'dev']) {
      final res = 'android/app/src/$flavor/res';
      for (final (density, px) in [
        ('mdpi', 48),
        ('hdpi', 72),
        ('xhdpi', 96),
        ('xxhdpi', 144),
        ('xxxhdpi', 192),
      ]) {
        final (w, h, _) = _png('$res/mipmap-$density/ic_launcher.png');
        expect((w, h), (px, px), reason: '$flavor $density');
      }
      final adaptive = File(
        '$res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsStringSync();
      expect(adaptive, contains('@color/ic_launcher_background'));
      expect(adaptive, contains('@drawable/ic_launcher_foreground'));
    }
    String ground(String flavor) => File(
      'android/app/src/$flavor/res/values/ic_launcher_background.xml',
    ).readAsStringSync();
    expect(ground('dev'), isNot(ground('main')));
  });
}
