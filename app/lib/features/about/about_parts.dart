import 'package:flutter/cupertino.dart';
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
                    color: t.text,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: t.text3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '링크 복사',
            icon: Icon(CupertinoIcons.doc_on_doc, size: 20, color: t.text2),
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
                    fontSize: TypeScale.caption,
                  )
                : context.text.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

/// One part of the 정보 screen: on the page under its heading, ruled
/// above, no box.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.tokens.line)),
    ),
    child: Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: child,
    ),
  );
}

/// A notice quoted as its source words it (an attribution): set off by
/// rules above and below, not by a box.
class AboutQuote extends StatelessWidget {
  const AboutQuote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final rule = BorderSide(color: context.tokens.line);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: rule),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Text(
          text,
          style: context.text.bodyMedium?.copyWith(height: 1.5),
        ),
      ),
    );
  }
}
