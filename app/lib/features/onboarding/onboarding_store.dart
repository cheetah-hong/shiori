import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/file_onboarding_store.dart';

/// Whether the first-run guide has been seen on this device.
///
/// Kept out of the learning database on purpose: a backup carries the
/// library and its settings, and restoring one must not bring the guide back
/// or be refused for a key it does not know.
abstract interface class OnboardingStore {
  Future<bool> hasSeen();

  Future<void> markSeen();
}

/// Kept in memory only (tests, previews).
final class InMemoryOnboardingStore implements OnboardingStore {
  InMemoryOnboardingStore({bool seen = false}) : _seen = seen;

  bool _seen;

  @override
  Future<bool> hasSeen() async => _seen;

  @override
  Future<void> markSeen() async => _seen = true;
}

/// Where the guide's mark is kept: a file in the app support folder.
final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => FileOnboardingStore.appSupport(),
);
