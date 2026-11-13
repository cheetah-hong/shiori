import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/about/about_parts.dart';
import 'package:shiori/shared/widgets.dart';

/// Where the policy is published on the web, once it is (docs/release.md).
/// Null: the 정보 screen shows no web address.
const String? privacyPolicyUrl = null;

/// Who to ask about the policy, once decided. Null: no contact line.
const String? privacyContact = null;

/// The date the policy takes effect (the web page says the same).
const String privacyPolicyEffective = '이 방침은 2026년 11월 12일부터 적용합니다.';

/// One part of the policy: a heading and its paragraphs.
@immutable
final class PolicySection {
  const PolicySection(this.heading, this.paragraphs);

  final String heading;
  final List<String> paragraphs;
}

/// The policy, as the app shows it. `site/privacy.html` carries the same
/// text (a test keeps the two together).
const List<PolicySection> privacyPolicySections = [
  PolicySection('수집하는 정보', [
    '시오리는 개인정보를 수집하지 않습니다. 앱은 인터넷에 연결하지 않으며, '
        '광고·분석·추적 도구를 쓰지 않습니다. 개발자에게 전송되는 정보는 없습니다.',
  ]),
  PolicySection('기기 안에 저장되는 정보', [
    '등록한 단어, 재생목록, 학습 기록과 설정은 이 기기 안의 앱 저장 공간에만 저장됩니다.',
    '앱에서 난 오류의 기록(시각, 오류 내용, 코드 위치)도 기기 안에만 남습니다. '
        '정보 화면에서 사용자가 직접 복사하지 않는 한 기기 밖으로 나가지 않습니다.',
    '앱을 지우면 기기 안의 이 정보도 함께 지워집니다. 기기 백업에 든 사본은 아래 「기기 백업」을 보세요.',
  ]),
  PolicySection('사진과 카메라', [
    '카메라와 사진 보관함은 교재 쪽을 찍거나 골라 단어를 등록할 때만 씁니다.',
    '사진 속 글자는 기기 안에서 읽고, 읽은 뒤에는 앱이 복사해 둔 사진을 지웁니다. '
        '사진을 저장하거나 보내지 않습니다.',
  ]),
  PolicySection('기기 백업', [
    'iPhone의 iCloud 백업이나 컴퓨터 백업에는 단어와 학습 기록이 함께 들어가, '
        '기기를 바꾸거나 되살릴 때 그대로 돌아옵니다. 백업은 Apple의 기기 백업 기능이 '
        '처리하며 개발자는 그 내용을 볼 수 없습니다.',
    '백업에 든 사본은 그 백업을 지우면 함께 지워집니다.',
    '오류 기록과 다시 만들 수 있는 사전·발음 파일은 백업에서 뺍니다.',
  ]),
  PolicySection('백업 파일', [
    '설정 › 백업 파일 만들기를 누르면 단어·재생목록·학습 기록·설정을 파일 하나(.json)로 만들어 '
        '공유 시트에 넘깁니다. 파일을 어디에 둘지(파일 앱, AirDrop 등)는 사용자가 고르며, '
        '앱은 이 파일을 어디로도 보내지 않고 개발자도 볼 수 없습니다.',
    '백업에서 복원하면 고른 파일의 내용으로 기기 안 데이터를 바꿉니다. 바꾸기 직전 데이터는 '
        '되돌릴 수 있게 앱 안에 한 번 보관하고, 되돌리거나 다음에 복원할 때 지워집니다.',
  ]),
  PolicySection('제3자 제공', ['개인정보를 제3자에게 제공하거나 처리를 맡기지 않습니다.']),
  PolicySection('아동', ['만 14세 미만 아동을 포함해 누구의 개인정보도 수집하지 않습니다.']),
  PolicySection('방침의 변경', [
    '이 방침이 바뀌면 앱 업데이트와 함께 앱의 개인정보처리방침 화면과 웹 페이지에 알립니다.',
  ]),
];

/// 정보 → 개인정보: a short summary and the way to the full policy, plus the
/// web address once it is published.
class PrivacySection extends StatelessWidget {
  const PrivacySection({
    super.key,
    this.url = privacyPolicyUrl,
    this.contact = privacyContact,
  });

  final String? url;
  final String? contact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final url = this.url;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('개인정보'),
        AboutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '시오리는 개인정보를 수집하지 않아요. 단어·학습 기록·사진은 이 기기 안에서만 다루고, '
                '인터넷에 연결하지 않아요.',
                style: context.text.bodySmall?.copyWith(
                  color: t.text2,
                  height: 1.5,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('개인정보처리방침'),
                subtitle: const Text('무엇을 어디에 저장하는지'),
                trailing: const Icon(CupertinoIcons.chevron_forward),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PrivacyPolicyScreen(contact: contact),
                  ),
                ),
              ),
              if (url != null) AboutLink(label: '웹에서 보기', url: url),
            ],
          ),
        ),
      ],
    );
  }
}

/// The full privacy policy, inside the app (the app opens no browser).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key, this.contact = privacyContact});

  /// The contact line, shown only when set.
  final String? contact;

  @override
  Widget build(BuildContext context) {
    final contact = this.contact;
    final body = context.text.bodyMedium?.copyWith(height: 1.6);
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보처리방침')),
      body: SelectionArea(
        // A column, not a lazy list: the policy is short and every part is
        // built (and found by screen readers) at once.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.section,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final section in privacyPolicySections) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    top: Space.lg,
                    bottom: Space.sm,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      section.heading,
                      style: context.text.titleSmall,
                    ),
                  ),
                ),
                for (final paragraph in section.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Text(paragraph, style: body),
                  ),
              ],
              const SizedBox(height: Space.lg),
              if (contact != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Text('문의: $contact', style: body),
                ),
              Text(privacyPolicyEffective, style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
