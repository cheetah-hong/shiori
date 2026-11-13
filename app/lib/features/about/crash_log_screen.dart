import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/crash_reporting.dart';
import 'package:shiori/app/theme.dart';

/// The device's crash log, newest first. Reading a local file again does not
/// help, so a failure shows at once instead of retrying.
final crashLogRecordsProvider = FutureProvider.autoDispose<List<CrashReport>>(
  (ref) async =>
      List.unmodifiable((await ref.watch(crashLogProvider).read()).reversed),
  retry: (_, _) => null,
);

/// 오류 기록: what the crash log on this device holds, with copy and clear.
class CrashLogScreen extends ConsumerWidget {
  const CrashLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(crashLogRecordsProvider);
    final shown = records.value ?? const <CrashReport>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('오류 기록'),
        actions: [
          IconButton(
            tooltip: '복사',
            icon: const Icon(CupertinoIcons.doc_on_doc),
            onPressed: shown.isEmpty ? null : () => _copy(context, shown),
          ),
          IconButton(
            tooltip: '지우기',
            icon: const Icon(CupertinoIcons.delete),
            // Also when the log cannot be read: clearing is the way out.
            onPressed: shown.isEmpty && !records.hasError
                ? null
                : () => _clear(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              Space.section,
            ),
            children: [
              const _WhatIsKept(),
              const SizedBox(height: Space.lg),
              ...switch (records) {
                AsyncData(:final value) when value.isEmpty => [
                  const _Message('기록된 오류가 없어요'),
                ],
                AsyncData(:final value) => [
                  for (final report in value) _ReportCard(report: report),
                ],
                AsyncError() => [const _Message('오류 기록을 읽지 못했어요')],
                _ => [
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(Space.xl),
                      child: CircularProgressIndicator(
                        semanticsLabel: '불러오는 중',
                      ),
                    ),
                  ),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, List<CrashReport> records) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: records.map((r) => r.format()).join('\n\n')),
    );
    messenger.showSnackBar(const SnackBar(content: Text('오류 기록을 복사했어요')));
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(crashLogProvider).clear();
    } on Exception catch (e) {
      debugPrint('[shiori] could not clear the crash log: $e');
      messenger.showSnackBar(const SnackBar(content: Text('기록을 지우지 못했어요')));
    }
    ref.invalidate(crashLogRecordsProvider);
  }
}

/// What the log holds, so the learner knows before copying it anywhere.
class _WhatIsKept extends StatelessWidget {
  const _WhatIsKept();

  @override
  Widget build(BuildContext context) => Text(
    '앱에서 난 오류의 시각, 내용, 코드 위치를 이 기기에만 저장하고, 앱이 어디로도 보내지 않아요'
    '(iPhone의 기기 백업에도 들어가지 않아요). '
    '오류 내용에 사진 파일 경로 같은 개인 정보가 섞일 수 있으니 복사해서 보내기 전에 확인해 주세요. '
    '같은 오류가 1분 안에 되풀이되면 한 번만 남겨요.',
    style: context.text.bodySmall?.copyWith(height: 1.5),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.xl),
    child: Center(child: Text(text, style: context.text.bodyMedium)),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final CrashReport report;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final source = switch (report.source) {
      CrashSource.flutter => '화면',
      CrashSource.platform => '비동기',
    };
    // One report per ruled row, on the page.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_stamp(report.time)} · $source',
            style: context.text.labelMedium?.copyWith(color: t.text3),
          ),
          const SizedBox(height: Space.xs),
          Text(report.error, style: context.text.bodyMedium),
          if (report.context case final where?) ...[
            const SizedBox(height: Space.xs),
            Text(where, style: context.text.bodySmall),
          ],
          if (report.stack case final stack? when stack.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(
              stack.trimRight(),
              style: TextStyle(
                fontFamily: 'Menlo',
                fontFamilyFallback: const ['monospace'],
                fontSize: TypeScale.caption,
                color: t.text2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _stamp(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
