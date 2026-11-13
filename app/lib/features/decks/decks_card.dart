import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/about/about_parts.dart';
import 'package:shiori/features/decks/deck_data.dart';
import 'package:shiori/features/decks/deck_parts.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// The 정보 screen's 기본 단어장 section: each source of the lists with its
/// licence and link, and the lists' edition. Nothing (not even the heading)
/// until the list file is read, so the screen does not grow under a tap.
class DecksSection extends ConsumerWidget {
  const DecksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(builtinDecksProvider)) {
        AsyncData(:final value?) => _Section(child: _DecksCard(set: value)),
        AsyncError() => _Section(
          child: AboutCard(
            child: Text('기본 단어장 목록을 읽지 못했어요.', style: context.text.bodySmall),
          ),
        ),
        _ => const SizedBox.shrink(),
      };
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionLabel('기본 단어장'),
      child,
      const SizedBox(height: Space.section),
    ],
  );
}

class _DecksCard extends StatelessWidget {
  const _DecksCard({required this.set});

  final BuiltinDeckSet set;

  @override
  Widget build(BuildContext context) => AboutCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JLPT 대비 단어 목록', style: context.text.titleLarge),
        const SizedBox(height: Space.xs),
        Text(
          '교재가 없어도 시작할 수 있게 레벨별 단어 목록을 앱에 넣었어요. '
          '$deckNotOfficial 뜻·예문·발음은 위의 사전으로 채워요.',
          style: context.text.bodySmall,
        ),
        for (final s in set.sources) ...[
          const SizedBox(height: Space.lg),
          AboutQuote('${s.author}, ${s.name} (${s.license})'),
          const SizedBox(height: Space.sm),
          AboutLink(label: '목록', url: s.url),
          AboutLink(label: '라이선스 (${s.license})', url: s.licenseUrl),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: Space.md),
          child: Divider(),
        ),
        AboutFact('목록 판', set.edition),
      ],
    ),
  );
}

bool _deckLicensesRegistered = false;

/// Adds both sources of the built-in deck lists to the licences page
/// ([showLicensePage]). Call once at start.
void registerDeckLicenses() {
  if (_deckLicensesRegistered) return;
  _deckLicensesRegistered = true;
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(
        ['JLPT Resources (Jonathan Waller)'],
        '''The built-in JLPT word lists (기본 단어장) come from Jonathan Waller's
JLPT Resources, https://www.tanos.co.uk/jlpt/ . Everything on that site that
is not sold is licensed under Creative Commons "BY" (Attribution):
https://www.tanos.co.uk/jlpt/sharing/

The lists are not published by the organizers of the Japanese-Language
Proficiency Test.''',
      ),
    ),
  );
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(
        ['yomitan-jlpt-vocab (Stephen Kraus)'],
        '''The same lists linked to JMdict entries by Stephen Kraus,
https://github.com/stephenmk/yomitan-jlpt-vocab . The app's deck file is a
changed copy (spellings, readings, order, one word per headword).

Licence: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA
4.0), https://creativecommons.org/licenses/by-sa/4.0/

The deck file is distributed under the same licence.''',
      ),
    ),
  );
}
