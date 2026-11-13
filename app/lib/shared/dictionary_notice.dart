import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';

/// Every line the dictionary notice shows, kept in one place.
abstract final class DictionaryNoticeText {
  static const title = '사전을 열지 못했어요';
  static const damaged =
      '앱에 들어 있는 사전 파일이 온전하지 않아요. 지금은 사진의 글자만으로 단어를 모으고, '
      '표기 확인과 한국어 뜻 채우기는 쉬어요. 앱을 업데이트하면 고쳐질 수 있어요.';
  static const failed =
      '사전 파일을 풀지 못했어요. 기기 저장 공간을 확인한 뒤 다시 시도해 주세요. '
      '그동안은 사진의 글자만으로 단어를 모아요.';
  static const retry = '다시 시도';
  static const preparing = '사전을 준비하고 있어요';
  static const opened = '사전을 열었어요';
  static const reviewSummary = '사전 없이 읽은 결과예요 — 표기 확인과 뜻 채우기가 빠졌어요';
  static const reviewReopened =
      '사전을 열었어요. 이 쪽은 사전 없이 읽었으니, 사전으로 읽으려면 페이지를 다시 등록해 주세요.';

  /// The body for [problem].
  static String of(DictionaryProblem problem) => switch (problem) {
    DictionaryProblem.damaged => damaged,
    DictionaryProblem.failed || DictionaryProblem.missing => failed,
  };
}

/// Whether [problem] is one to tell the learner about (a build without the
/// assets is not: that is a development build).
bool isNoticeable(DictionaryProblem? problem) =>
    problem == DictionaryProblem.damaged || problem == DictionaryProblem.failed;

/// The problem to tell the learner about: [DictionaryProblem.damaged] when
/// either dictionary is damaged, else [DictionaryProblem.failed] when either
/// failed; null while they open, when both are open, or when the app was
/// built without them ([DictionaryProblem.missing]).
final dictionaryProblemProvider = Provider<DictionaryProblem?>((ref) {
  final kinds = {
    ref.watch(bundledDictionaryProvider).value?.problemKind,
    ref.watch(bundledGlossaryProvider).value?.problemKind,
  };
  if (kinds.contains(DictionaryProblem.damaged)) {
    return DictionaryProblem.damaged;
  }
  if (kinds.contains(DictionaryProblem.failed)) return DictionaryProblem.failed;
  return null;
});

/// Opens again each dictionary that did not open (unpacking it again: a
/// refused asset leaves no marker) and says so when both are then usable.
/// A dictionary that is open is left alone: a page may be reading with it.
Future<void> retryDictionaries(WidgetRef ref, BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final retryDictionary = isNoticeable(
    ref.read(bundledDictionaryProvider).value?.problemKind,
  );
  final retryGlossary = isNoticeable(
    ref.read(bundledGlossaryProvider).value?.problemKind,
  );
  if (retryDictionary) ref.invalidate(bundledDictionaryProvider);
  if (retryGlossary) ref.invalidate(bundledGlossaryProvider);
  try {
    final dictionary = await ref.read(bundledDictionaryProvider.future);
    final glossary = await ref.read(bundledGlossaryProvider.future);
    if (isNoticeable(dictionary.problemKind) ||
        isNoticeable(glossary.problemKind)) {
      return;
    }
  } on Object {
    return; // the providers never fail; nothing better to say if they do
  }
  messenger?.showSnackBar(
    const SnackBar(content: Text(DictionaryNoticeText.opened)),
  );
}

/// 「사전을 열지 못했어요」 with 「다시 시도」, shown only when there is a
/// problem to tell: [problem] when given (one dictionary, as on the 정보
/// screen), else [dictionaryProblemProvider]. [compact]: the one-line form for
/// the review screen.
class DictionaryNotice extends ConsumerWidget {
  const DictionaryNotice({super.key, this.compact = false, this.problem});

  final bool compact;
  final DictionaryProblem? problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = problem ?? ref.watch(dictionaryProblemProvider);
    if (shown == null || !isNoticeable(shown)) return const SizedBox.shrink();
    final opening =
        ref.watch(bundledDictionaryProvider).isLoading ||
        ref.watch(bundledGlossaryProvider).isLoading;
    final t = context.tokens;
    final action = opening
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: t.risk),
              ),
              const SizedBox(width: Space.sm),
              Text(
                DictionaryNoticeText.preparing,
                style: TextStyle(color: t.risk),
              ),
            ],
          )
        : TextButton(
            onPressed: () => retryDictionaries(ref, context),
            style: TextButton.styleFrom(foregroundColor: t.risk),
            child: const Text(DictionaryNoticeText.retry),
          );
    final text = TextStyle(color: t.risk, height: 1.45);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          Space.lg,
          compact ? Space.sm : Space.lg,
          Space.sm,
          Space.sm,
        ),
        decoration: BoxDecoration(
          color: t.riskBg,
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        child: compact
            ? Row(
                children: [
                  Icon(CupertinoIcons.book, color: t.risk, size: 20),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      DictionaryNoticeText.reviewSummary,
                      style: text.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  action,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_circle,
                        color: t.risk,
                        size: 20,
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Text(
                          DictionaryNoticeText.title,
                          style: text.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 20 + Space.md,
                      right: Space.sm,
                    ),
                    child: Text(DictionaryNoticeText.of(shown), style: text),
                  ),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              ),
      ),
    );
  }
}

/// The review screen's line for a page read without a dictionary: the
/// compact [DictionaryNotice] while the problem lasts; once 「다시 시도」
/// opens the dictionaries, a note that this page stays as it was read.
class ReadWithoutDictionaryNotice extends ConsumerWidget {
  const ReadWithoutDictionaryNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(dictionaryProblemProvider) != null) {
      return const DictionaryNotice(compact: true);
    }
    final t = context.tokens;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: t.warnBg,
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.book, color: t.warn, size: 20),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                DictionaryNoticeText.reviewReopened,
                style: TextStyle(color: t.warn, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
