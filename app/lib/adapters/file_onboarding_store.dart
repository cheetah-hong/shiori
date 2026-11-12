import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shiori/features/onboarding/onboarding_store.dart';

/// The first-run guide's mark: a small file in the app support folder whose
/// content is the guide's edition. A later edition of the guide can raise
/// [edition] to be shown once more.
final class FileOnboardingStore implements OnboardingStore {
  FileOnboardingStore({required this.directory, this.edition = 1});

  factory FileOnboardingStore.appSupport() =>
      FileOnboardingStore(directory: getApplicationSupportDirectory);

  static const fileName = 'onboarding_seen';

  final Future<Directory> Function() directory;
  final int edition;

  Future<File> _file() async => File('${(await directory()).path}/$fileName');

  @override
  Future<bool> hasSeen() async {
    final file = await _file();
    if (!await file.exists()) return false;
    final seen = int.tryParse((await file.readAsString()).trim()) ?? 0;
    return seen >= edition;
  }

  @override
  Future<void> markSeen() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString('$edition', flush: true);
  }
}
