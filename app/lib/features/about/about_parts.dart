import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiori/app/theme.dart';

/// A link shown as text: selectable, with a copy button. The app opens no
/// browser itself.
class AboutLink extends StatelessWidget {
  const AboutLink({super.key, required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.bodySmall),
                Text(
                  url,
                  style: TextStyle(
                    color: t.ink,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: t.ink3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '링크 복사',
            icon: Icon(Icons.copy_rounded, size: 20, color: t.ink2),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: url));
              messenger.showSnackBar(
                const SnackBar(content: Text('링크를 복사했어요')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A label and its value on one line.
class AboutFact extends StatelessWidget {
  const AboutFact(this.label, this.value, {super.key, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 92, child: Text(label, style: context.text.bodySmall)),
        Expanded(
          child: Text(
            value,
            style: mono
                ? const TextStyle(
                    fontFamily: 'Menlo',
                    fontFamilyFallback: ['monospace'],
                    fontSize: 12,
                  )
                : context.text.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

/// One card of the 정보 screen.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.lg),
    decoration: BoxDecoration(
      color: context.tokens.sheet,
      borderRadius: BorderRadius.circular(Radii.card),
    ),
    child: child,
  );
}
