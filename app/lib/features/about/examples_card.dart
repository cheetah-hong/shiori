import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/bundled_examples.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/about/about_parts.dart';

const _tatoebaUrl = 'https://tatoeba.org';
const _ccBy20FrUrl = 'https://creativecommons.org/licenses/by/2.0/fr/';

/// The 정보 screen's 예문 section: the Tatoeba sentences and their credit,
/// or why there are none.
class ExamplesSection extends ConsumerWidget {
  const ExamplesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(bundledExamplesProvider)) {
        AsyncData(:final value) when value.edition != null => _ExamplesCard(
          edition: value.edition!,
        ),
        AsyncData(:final value) => _NoExamples(problem: value.problemKind),
        AsyncError() => const _NoExamples(),
        _ => const SizedBox.shrink(),
      };
}

/// The sentences credited as CC BY 2.0 FR asks (source, link, licence).
class _ExamplesCard extends StatelessWidget {
  const _ExamplesCard({required this.edition});

  final ExamplesEdition edition;

  @override
  Widget build(BuildContext context) {
    return AboutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tatoeba', style: context.text.titleLarge),
          const SizedBox(height: Space.xs),
          Text(
            '사진에 예문이 없는 낱말은 학습 카드에 Tatoeba 문장을 보여 줍니다. '
            '카드에는 "예문: Tatoeba"가 붙고, 한국어 번역이 없으면 영어 번역을 보여 줍니다.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Space.md),
          AboutQuote(edition.attribution),
          const SizedBox(height: Space.lg),
          AboutLink(
            label: '라이선스 (${edition.license})',
            url: edition.licenseUrl,
          ),
          AboutLink(label: '문장 출처', url: edition.url),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.md),
            child: Divider(),
          ),
          AboutFact('내보낸 날', edition.edition),
          AboutFact('만든 날', edition.builtOn),
        ],
      ),
    );
  }
}

/// No sentences: a build without the asset (a debug build), or one whose
/// asset did not open.
class _NoExamples extends StatelessWidget {
  const _NoExamples({this.problem});

  final DictionaryProblem? problem;

  @override
  Widget build(BuildContext context) => AboutCard(
    child: Text(
      problem == DictionaryProblem.missing || problem == null
          ? '이 앱에는 Tatoeba 예문이 들어 있지 않아요. '
                '사진에 예문이 있는 낱말만 카드에 예문이 보여요.'
          : '예문 파일을 열지 못해 Tatoeba 예문을 쓰지 않고 있어요. '
                '사진에 예문이 있는 낱말만 카드에 예문이 보여요. '
                '앱을 업데이트하면 고쳐질 수 있어요.',
      style: context.text.bodySmall,
    ),
  );
}

bool _registered = false;

/// Adds the Tatoeba sentences to the licences page ([showLicensePage]).
/// Call once at start.
void registerExampleLicense() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(
        ['Tatoeba'],
        '''Example sentences from Tatoeba ($_tatoebaUrl), by the Tatoeba
contributors, shown on study cards whose page printed no example, with their
Korean or English translations from Tatoeba. The app picks one sentence per
dictionary word and changes nothing in it.

Licence: Creative Commons Attribution 2.0 France (CC BY 2.0 FR),
$_ccBy20FrUrl''',
      ),
    ),
  );
}
