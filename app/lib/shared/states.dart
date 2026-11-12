import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';

/// An empty state: one ruled row on the page with what is missing (a
/// sentence) and how it fills (one quieter line). The next step is usually
/// the screen's bottom bar; [action] is for a screen without one.
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.title, this.body, this.action});

  final String title;
  final String? body;

  /// The one thing to do next (a button), if the screen has no bar for it.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rule = BorderSide(color: t.line);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: rule),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: t.text2,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (body case final body?) ...[
              const SizedBox(height: Space.xs),
              Text(
                body,
                style: TextStyle(color: t.text3, fontSize: 15, height: 1.45),
              ),
            ],
            if (action case final action?) ...[
              const SizedBox(height: Space.sm),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// A load that failed: one line and 다시 불러오기. The error itself is for
/// the log, not the screen.
class LoadFailure extends StatelessWidget {
  const LoadFailure({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              color: context.tokens.text,
            ),
          ),
          const SizedBox(height: Space.md),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 불러오기'),
          ),
        ],
      ),
    ),
  );
}

/// A spinner VoiceOver reads as 불러오는 중.
class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(semanticsLabel: '불러오는 중'));
}
