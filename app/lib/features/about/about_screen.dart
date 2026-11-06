import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/about/crash_log_screen.dart';
import 'package:shiori/features/about/extract_licenses.dart';
import 'package:shiori/features/about/voice_licenses.dart';
import 'package:shiori/shared/dictionary_notice.dart';
import 'package:shiori/shared/widgets.dart';

const _projectUrl =
    'https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project';
const _licenseUrl = 'https://www.edrdg.org/edrdg/licence.html';

/// The EDRDG notice, for the licences page (the database holds its own copy).
const _notice =
    'This application uses the JMdict dictionary files. These files are the '
    'property of the Electronic Dictionary Research and Development Group, '
    "and are used in conformance with the Group's licence.";

const _krdictUrl = 'https://krdict.korean.go.kr';

/// The licence the converted JMdict data is distributed under.
const _ccBySa40Url = 'https://creativecommons.org/licenses/by-sa/4.0/';

const _jlUrl = 'https://github.com/rampaa/JL';
const _jlCommit = 'd8011e289eb4cd265fd4e3beb3fd155e8a764004';
const _unihanUrl = 'https://www.unicode.org/Public/18.0.0/ucd/Unihan.zip';

/// 정보: where the app's data comes from (the JMdict notice the EDRDG licence
/// asks for on a screen of its own, the credit line of the Basic Korean
/// Dictionary) and the open source licences.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dictionary = ref.watch(bundledDictionaryProvider);
    final glossary = ref.watch(bundledGlossaryProvider);
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
              AsyncData(:final value) when isNoticeable(value.problemKind) =>
                DictionaryNotice(problem: value.problemKind),
              AsyncData() || AsyncError() => const _NoDictionary(),
              _ => const _Preparing(),
            },
            const SizedBox(height: Space.section),
            const SectionLabel('한국어 뜻 사전'),
            switch (glossary) {
              AsyncData(:final value) when value.isAvailable => _GlossaryCard(
                edition: value.edition!,
              ),
              AsyncData(:final value) when isNoticeable(value.problemKind) =>
                DictionaryNotice(problem: value.problemKind),
              AsyncData() || AsyncError() => const _NoGlossary(),
              _ => const _Preparing(),
            },
            const SizedBox(height: Space.section),
            const SectionLabel('단어 추출 데이터'),
            const _ExtractorCard(),
            const SizedBox(height: Space.section),
            const SectionLabel('발음'),
            const _VoiceCard(),
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

/// The data the word extractor ships with, credited as their licences ask.
class _ExtractorCard extends StatelessWidget {
  const _ExtractorCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget source(String title, String body) => Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleSmall),
          const SizedBox(height: Space.xs),
          Text(body, style: context.text.bodySmall?.copyWith(height: 1.5)),
        ],
      ),
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '배치가 다른 쪽에서 단어를 뽑을 때 아래 데이터를 씁니다.',
            style: context.text.bodySmall?.copyWith(color: t.ink2),
          ),
          source(
            'JL 활용 되돌리기 규칙 · $_jlUrl',
            '문장 속 활용형을 원형으로 되돌리는 규칙, Apache License 2.0. '
                '규칙은 Nazeka(Apache License 2.0)에서 왔습니다.',
          ),
          source(
            'Unihan (Unicode Han Database) 18.0.0',
            '한자의 한국 한자음(뜻과 표제어를 짝짓는 데 씀). Unicode, Inc., '
                'Unicode License v3. $_unihanUrl',
          ),
        ],
      ),
    );
  }
}

/// Kanjium's own wording for its credit (its README asks for this text on
/// an app's About page).
const kanjiumAttribution =
    'The pitch accent notation, verb particle data, phonetics, homonyms and '
    'other additions or modifications to EDICT, KANJIDIC or KRADFILE were '
    'provided by Uros O. through his free database.';

/// The voice, the engine and the accent data, credited as their terms ask.
class _VoiceCard extends StatelessWidget {
  const _VoiceCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget source(String title, String body) => Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleSmall),
          const SizedBox(height: Space.xs),
          Text(body, style: context.text.bodySmall?.copyWith(height: 1.5)),
        ],
      ),
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '단어와 예문 소리는 기기 안에서 만들어요. 인터넷을 쓰지 않아요.',
            style: context.text.bodySmall?.copyWith(color: t.ink2),
          ),
          source(
            '음성 · VOICEVOX:四国めたん',
            'VOICEVOX 음성 모델 이용규약과 四国めたん 음성 라이브러리 이용규약을 '
                '따릅니다.',
          ),
          source(
            'VOICEVOX core 0.17.1',
            '음성 합성 엔진, MIT License. 엔진에 든 Open JTalk는 수정 BSD '
                '라이선스입니다.',
          ),
          source(
            'VOICEVOX ONNX Runtime',
            'VOICEVOX ONNX Runtime 이용규약. Microsoft ONNX Runtime(MIT '
                'License)을 바탕으로 합니다.',
          ),
          source('Open JTalk 사전 1.11', '예문을 읽고 악센트를 정하는 사전, 수정 BSD 라이선스.'),
          source(
            'Kanjium 악센트 데이터',
            '음 높이 선과 단어 소리의 악센트, CC BY-SA 4.0. '
                '$kanjiumAttribution',
          ),
        ],
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
            '사진 속 낱말의 표기·읽기·품사 확인과 문장을 원형 단어로 나누는 데 '
            'EDRDG의 JMdict를 씁니다. 뜻은 사진에서 가져옵니다(사진에 뜻이 없을 때만 아래 한국어 뜻 사전).',
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
          const SizedBox(height: Space.md),
          Text(
            'EDRDG의 JMdict 파일을 이 앱의 사전 형식으로 변환(가공)한 사본입니다. '
            '변환한 데이터는 CC BY-SA 4.0으로 배포합니다.',
            style: context.text.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: Space.lg),
          _Link(label: 'JMdict 프로젝트', url: info.projectUrl),
          _Link(label: '라이선스 (${info.license})', url: info.licenseUrl),
          const _Link(label: '변환한 데이터의 라이선스 (CC BY-SA 4.0)', url: _ccBySa40Url),
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

/// The Korean glossary: one credit line per dictionary in the asset (the
/// licence asks for source, publisher, licence and that the data was changed).
class _GlossaryCard extends StatelessWidget {
  const _GlossaryCard({required this.edition});

  final GlossaryEdition edition;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('한국어기초사전', style: context.text.titleLarge),
          const SizedBox(height: Space.xs),
          Text(
            '교재에 뜻이 없거나 읽지 못했을 때만, 사전의 일본어 대역어를 거꾸로 찾아 '
            '뜻 칸을 채웁니다. 채운 뜻에는 "추정" 표시가 붙습니다.',
            style: context.text.bodySmall,
          ),
          for (final source in edition.sources) ...[
            const SizedBox(height: Space.md),
            Container(
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                color: t.paper,
                borderRadius: BorderRadius.circular(Radii.tile),
              ),
              child: Text(
                source.attribution,
                style: context.text.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: Space.lg),
            _Link(label: '라이선스 (${source.license})', url: source.licenseUrl),
          ],
          const _Link(label: '한국어기초사전', url: _krdictUrl),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.md),
            child: Divider(),
          ),
          Text('들어 있는 판', style: context.text.labelLarge),
          const SizedBox(height: Space.sm),
          for (final source in edition.sources)
            _Fact('${source.source.label} 판', source.edition),
          _Fact('만든 날', edition.builtOn),
          _Fact('판본', edition.variant),
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
              '사전 확인 없이 사진의 글자만으로 단어를 모읍니다.',
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoGlossary extends StatelessWidget {
  const _NoGlossary();

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
              '이 앱에는 한국어 뜻 사전이 들어 있지 않아요. '
              '교재에서 읽은 뜻만 씁니다.',
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

bool _glossaryLicenseRegistered = false;

/// Adds the Basic Korean Dictionary to the licences page ([showLicensePage]).
/// Call once at start.
void registerGlossaryLicense() {
  if (_glossaryLicenseRegistered) return;
  _glossaryLicenseRegistered = true;
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(
        ['한국어기초사전'],
        '''한국어기초사전 (Basic Korean Dictionary), 국립국어원 (National Institute of
Korean Language). The app's Korean meanings are its Japanese equivalents
indexed backwards; the converted data is a changed copy of the dictionary.

한국어기초사전: $_krdictUrl
Licence: Creative Commons Attribution-ShareAlike 2.0 Korea (CC BY-SA 2.0 KR),
https://creativecommons.org/licenses/by-sa/2.0/kr/

The converted data is distributed under the same licence.''',
      ),
    ),
  );
}

bool _extractorLicensesRegistered = false;

/// Adds the word extractor's data (JL's deconjugation rules, the Unicode Han
/// Database) to the licences page. Call once at start.
void registerExtractorLicenses() {
  if (_extractorLicensesRegistered) return;
  _extractorLicensesRegistered = true;
  LicenseRegistry.addLicense(
    () => Stream.fromIterable([
      const LicenseEntryWithLineBreaks(
        ['JL deconjugation rules'],
        '''Deconjugation rules (deconjugation_rules.json) from JL,
$_jlUrl (commit $_jlCommit), unchanged.
JL credits Nazeka (https://github.com/wareya/nazeka, Apache License 2.0) for
the rules. The deconjugator that reads them was written for this app.

$apacheLicense20''',
      ),
      const LicenseEntryWithLineBreaks(
        ['Unihan'],
        '''Korean readings of kanji from the Unicode Han Database (Unihan) 18.0.0:
kHangul and the variant fields, for the Joyo and Jinmeiyo kanji.
$_unihanUrl

$unicodeLicenseV3''',
      ),
    ]),
  );
}

bool _voiceLicensesRegistered = false;

/// Adds the pronunciation engine, voice and accent data to the licences
/// page. Call once at start.
void registerVoiceLicenses() {
  if (_voiceLicensesRegistered) return;
  _voiceLicensesRegistered = true;
  LicenseRegistry.addLicense(
    () => Stream.fromIterable([
      const LicenseEntryWithLineBreaks(['VOICEVOX core'], voicevoxCoreLicense),
      const LicenseEntryWithLineBreaks(
        ['VOICEVOX ONNX Runtime', 'VOICEVOX voice model'],
        '''VOICEVOX ONNX Runtime and the VOICEVOX voice model (0.vvm) are used under
their terms of use (VOICEVOX ONNX Runtime 利用規約, VOICEVOX 音声モデル 利用規約):
use in commercial and non-commercial apps and redistribution inside an app
are allowed; decompiling and reverse engineering are not; a credit showing
that VOICEVOX is used is required.

Voice: VOICEVOX:四国めたん (terms: https://zunko.jp/con_ongen_kiyaku.html).

VOICEVOX ONNX Runtime is built from Microsoft ONNX Runtime (MIT License).''',
      ),
      const LicenseEntryWithLineBreaks([
        'Open JTalk dictionary',
      ], openJtalkDictionaryLicense),
      const LicenseEntryWithLineBreaks(
        ['Kanjium'],
        '''Pitch accent data (accents.txt) from Kanjium,
https://github.com/mifunetoshiro/kanjium, converted to the app's accent table.

$kanjiumAttribution

Licence: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA
4.0), https://creativecommons.org/licenses/by-sa/4.0/. The converted table
is distributed under the same licence.''',
      ),
    ]),
  );
}
