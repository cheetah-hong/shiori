import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/decks/decks_screen.dart';
import 'package:shiori/features/onboarding/onboarding_screen.dart';
import 'package:shiori/features/onboarding/onboarding_store.dart';
import 'package:shiori/shared/navigation.dart';

/// Shows the first-run guide before [child] when it has not been seen and
/// the library is empty. Someone who already has words (an update, a
/// restored backup) goes straight to [child] and is marked as having seen it.
///
/// A mark that cannot be read counts as not seen, unless there are words; a
/// mark that cannot be written is logged and the guide still closes.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  bool? _show;

  @override
  void initState() {
    super.initState();
    unawaited(_decide());
  }

  Future<void> _decide() async {
    final show = await _shouldShow();
    if (mounted) setState(() => _show = show);
  }

  Future<bool> _shouldShow() async {
    final store = ref.read(onboardingStoreProvider);
    try {
      if (await store.hasSeen()) return false;
    } on Object catch (error) {
      debugPrint('[shiori] could not read the guide mark: $error');
    }
    if (await _hasLibrary()) {
      unawaited(_markSeen(store));
      return false;
    }
    return true;
  }

  Future<bool> _hasLibrary() async {
    try {
      final library = ref.read(libraryRepositoryProvider);
      return (await library.playlists()).isNotEmpty ||
          (await library.words()).isNotEmpty;
    } on Object catch (error) {
      debugPrint('[shiori] could not look at the library: $error');
      return false;
    }
  }

  Future<void> _markSeen(OnboardingStore store) async {
    try {
      await store.markSeen();
    } on Object catch (error) {
      debugPrint('[shiori] could not keep the guide mark: $error');
    }
  }

  void _done() {
    unawaited(_markSeen(ref.read(onboardingStoreProvider)));
    setState(() => _show = false);
  }

  /// Done, then 기본 단어장 over home (back goes home).
  void _decks() {
    _done();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(pushScreen<void>(context, const DecksScreen()));
    });
  }

  @override
  Widget build(BuildContext context) => switch (_show) {
    null => const Scaffold(),
    true => OnboardingScreen(onDone: _done, onDecks: _decks),
    false => widget.child,
  };
}
