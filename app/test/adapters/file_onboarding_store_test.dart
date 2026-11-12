// The first-run guide's mark on disk: missing means not seen, it survives a
// new store on the same folder, and a later edition of the guide shows again.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/file_onboarding_store.dart';

void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('onboarding');
    addTearDown(() => folder.delete(recursive: true));
  });

  FileOnboardingStore store({int edition = 1}) =>
      FileOnboardingStore(directory: () async => folder, edition: edition);

  test('not seen until marked, then seen by a new store too', () async {
    expect(await store().hasSeen(), isFalse);
    await store().markSeen();
    expect(await store().hasSeen(), isTrue);
    expect(
      File('${folder.path}/${FileOnboardingStore.fileName}').existsSync(),
      isTrue,
    );
  });

  test('a later edition of the guide is not seen yet', () async {
    await store().markSeen();
    expect(await store(edition: 2).hasSeen(), isFalse);
    await store(edition: 2).markSeen();
    expect(await store().hasSeen(), isTrue);
  });

  test('a mark that is not a number counts as not seen', () async {
    File(
      '${folder.path}/${FileOnboardingStore.fileName}',
    ).writeAsStringSync('x');
    expect(await store().hasSeen(), isFalse);
  });
}
