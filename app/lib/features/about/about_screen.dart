import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/about/crash_log_screen.dart';
import 'package:shiori/shared/widgets.dart';

const _projectUrl =
    'https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project';
const _licenseUrl = 'https://www.edrdg.org/edrdg/licence.html';

/// The EDRDG notice, for the licences page (the database holds its own copy).
const _notice =
    'This application uses the JMdict dictionary files. These files are the '
    'property of the Electronic Dictionary Research and Development Group, '
    "and are used in conformance with the Group's licence.";

/// 정보: where the app's data comes from (the JMdict notice the EDRDG licence
/// asks for on a screen of its own) and the open source licences.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dictionary = ref.watch(bundledDictionaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('정보')),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.section,
          ),
          children: [
            const SectionLabel('사전 데이터'),
            switch (dictionary) {
              AsyncData(:final value) when value.isAvailable => _DictionaryCard(
                dictionary: value,
              ),
              AsyncData() || AsyncError() => const _NoDictionary(),
              _ => const _Preparing(),
            },
            const SizedBox(height: Space.section),
            const SectionLabel('오류 기록'),
            _Card(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('오류 기록 보기'),
                subtitle: const Text('앱에서 난 오류를 이 기기에만 남겨요. 복사해서 보낼 수 있어요.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CrashLogScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.section),
            const SectionLabel('오픈소스'),
            _Card(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('오픈소스 라이선스'),
                subtitle: const Text('앱에 쓰인 패키지와 데이터의 라이선스'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    showLicensePage(context: context, applicationName: '시오리'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DictionaryCard extends StatelessWidget {
  const _DictionaryCard({required this.dictionary});

  final BundledDictionary dictionary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final info = dictionary.info!;
    final edition = dictionary.edition!;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JMdict', style: context.text.titleLarge),
          const SizedBox(height: Space.xs),
          Text(
            '표제어 후보와 사전 확인에 EDRDG의 JMdict를 씁니다. '
            '뜻은 사전이 아니라 교재에서 가져옵니다.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: t.paper,
              borderRadius: BorderRadius.circular(Radii.tile),
            ),
            child: Text(
              info.attribution,
              style: context.text.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: Space.lg),
          _Link(label: 'JMdict 프로젝트', url: info.projectUrl),
          _Link(label: '라이선스 (${info.license})', url: info.licenseUrl),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.md),
            child: Divider(),
          ),
          Text('들어 있는 판', style: context.text.labelLarge),
          const SizedBox(height: Space.sm),
          _Fact('JMdict 날짜', edition.jmdictCreated),
          _Fact('만든 날', edition.builtOn),
          _Fact('판본', '${edition.variant} · 항목 ${info.entryCount}'),
          _Fact('원본 sha256', edition.sourceSha256, mono: true),
        ],
      ),
    );
  }
}

/// A link shown as text: selectable, with a copy button. The app opens no
/// browser itself.
class _Link extends StatelessWidget {
  const _Link({required this.label, required this.url});

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

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.mono = false});

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

class _NoDictionary extends StatelessWidget {
  const _NoDictionary();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: t.warn),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              '이 앱에는 사전 데이터가 들어 있지 않아요. '
              '표제어 후보와 사전 확인 없이 동작합니다.',
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing();

  @override
  Widget build(BuildContext context) => _Card(
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: Space.md),
        Text('사전을 준비하고 있어요', style: context.text.bodyMedium),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

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

bool _licenseRegistered = false;

/// Adds JMdict to the licences page ([showLicensePage]). Call once at start.
void registerDictionaryLicense() {
  if (_licenseRegistered) return;
  _licenseRegistered = true;
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(
        ['JMdict'],
        '''
$_notice

JMdict: $_projectUrl
Licence: $_licenseUrl

The dictionary data (a converted copy of JMdict) is distributed under the
Creative Commons Attribution-ShareAlike 4.0 International licence (CC BY-SA 4.0).''',
      ),
    ),
  );
}
