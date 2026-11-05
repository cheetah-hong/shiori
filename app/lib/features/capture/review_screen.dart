import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/entry_editor_sheet.dart';
import 'package:shiori/features/capture/entry_tile.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// Where the reviewed words go: an existing textbook or a new one.
sealed class SaveTarget {
  const SaveTarget();
}

final class ExistingTextbook extends SaveTarget {
  const ExistingTextbook(this.textbook);

  final Textbook textbook;
}

final class NewTextbook extends SaveTarget {
  const NewTextbook(this.title);

  final String title;
}

/// 검토: check flagged cells, fix them, choose the textbook, save.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({
    super.key,
    required this.draft,
    this.sourceLabel,
    this.recognizerId,
  });

  final CaptureDraft draft;
  final String? sourceLabel;
  final String? recognizerId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late CaptureDraft _draft = widget.draft;
  SaveTarget? _target;
  bool _onlyFlagged = false;
  bool _saving = false;

  TextbookTemplate? get _template =>
      ref.read(templateRegistryProvider).byId(_draft.templateId);

  SaveTarget _defaultTarget(List<ShelfItem> shelf) => shelf.isNotEmpty
      ? ExistingTextbook(shelf.last.textbook)
      : NewTextbook(_template?.suggestedTextbookTitle ?? '내 단어장');

  Future<void> _edit(int index) async {
    final edited = await showEntryEditor(context, _draft.entries[index]);
    if (edited != null && mounted) _replace(index, edited);
  }

  /// A dictionary candidate fills the empty headword; the cell shows as fixed.
  void _pick(int index, String headword) {
    final entry = _draft.entries[index];
    _replace(
      index,
      entry
          .edit(headword: headword)
          .withIssue(
            EntryIssue.corrected(
              EntryField.headword,
              note: pickedCandidateNote(headword),
            ),
          ),
    );
  }

  void _toggle(int index, bool included) =>
      _replace(index, _draft.entries[index].copyWith(included: included));

  void _replace(int index, CapturedEntry entry) => setState(() {
    _draft = _draft.replaceEntry(index, entry);
    // With the last flag fixed, the "확인 필요" filter would show nothing.
    if (_draft.needsReviewCount == 0) _onlyFlagged = false;
  });

  Future<void> _editMeta() async {
    final meta = await showModalBottomSheet<PageMeta>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MetaEditor(meta: _draft.meta),
    );
    if (meta != null && mounted) {
      setState(() => _draft = _draft.copyWith(meta: meta));
    }
  }

  Future<void> _chooseTarget(List<ShelfItem> shelf) async {
    final target = await showModalBottomSheet<SaveTarget>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TargetPicker(
        shelf: shelf,
        suggestedTitle: _template?.suggestedTextbookTitle ?? '내 단어장',
      ),
    );
    if (target != null && mounted) setState(() => _target = target);
  }

  Future<void> _save(SaveTarget target) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final library = ref.read(libraryServiceProvider);
      final textbookId = switch (target) {
        ExistingTextbook(:final textbook) => textbook.id,
        NewTextbook(:final title) => (await library.createTextbook(
          title,
          templateId: _draft.templateId,
        )).id,
      };
      final result = await library.saveDraft(_draft, textbookId: textbookId);
      if (!mounted) return;
      ref.read(dataRevisionProvider.notifier).bump();
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.updated == 0
                ? '단어 ${result.saved}개를 저장했어요'
                : '단어 ${result.added}개를 더하고 ${result.updated}개를 고쳤어요',
          ),
        ),
      );
    } on LibraryException catch (e) {
      _saveFailed(messenger, e.message);
    } on Exception catch (e, stack) {
      // A storage block failed (for example a disk error once drift lands).
      debugPrint('save failed: $e\n$stack');
      _saveFailed(messenger, '저장하지 못했어요. 다시 시도해 주세요');
    } on Error catch (e, stack) {
      // A bug in a block: report it like any uncaught error, but give the
      // learner the button back instead of an endless spinner.
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stack, library: 'review'),
      );
      _saveFailed(messenger, '저장하지 못했어요. 다시 시도해 주세요');
    }
  }

  void _saveFailed(ScaffoldMessengerState messenger, String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shelfState = ref.watch(shelfProvider);
    final shelf = shelfState.value ?? const <ShelfItem>[];
    // Until the textbook list is known, the default target could wrongly be a
    // new textbook, so saving waits for it.
    final shelfReady = shelfState.hasValue && !shelfState.hasError;
    final target = _target ?? _defaultTarget(shelf);
    final entries = _draft.entries;
    final visible = [
      for (final (i, e) in entries.indexed)
        if (!_onlyFlagged || e.needsReview) i,
    ];
    final saveable = entries
        .where((e) => e.included && e.headword.trim().isNotEmpty)
        .length;
    final blankHeadwords = entries
        .where((e) => e.included && e.headword.trim().isEmpty)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('검토')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.md,
            ),
            sliver: SliverToBoxAdapter(
              child: _Summary(
                draft: _draft,
                templateLabel: _template?.label ?? _draft.templateId,
                sourceLabel: widget.sourceLabel,
                target: target,
                onEditMeta: _editMeta,
                onChooseTarget: () => _chooseTarget(shelf),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('전체 ${entries.length}'),
                    selected: !_onlyFlagged,
                    onSelected: (_) => setState(() => _onlyFlagged = false),
                  ),
                  const SizedBox(width: Space.sm),
                  ChoiceChip(
                    label: Text('확인 필요 ${_draft.needsReviewCount}'),
                    selected: _onlyFlagged,
                    onSelected: _draft.needsReviewCount == 0
                        ? null
                        : (_) => setState(() => _onlyFlagged = true),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              120,
            ),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
              itemBuilder: (_, k) {
                final i = visible[k];
                return EntryTile(
                  key: ValueKey('entry-${entries[i].no}-$i'),
                  entry: entries[i],
                  onTap: () => _edit(i),
                  onToggle: (v) => _toggle(i, v),
                  onPickCandidate: (c) => _pick(i, c),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            Space.md,
          ),
          decoration: BoxDecoration(
            color: t.paper,
            border: Border(top: BorderSide(color: t.paper2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (shelfState.hasError)
                _ShelfError(onRetry: () => ref.invalidate(shelfProvider)),
              if (blankHeadwords > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Text(
                    '표제어가 빈 단어 $blankHeadwords개는 저장하지 않아요',
                    style: TextStyle(
                      color: t.risk,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saveable == 0 || _saving || !shelfReady
                      ? null
                      : () => _save(target),
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.sheet,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text('단어 $saveable개 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.draft,
    required this.templateLabel,
    required this.sourceLabel,
    required this.target,
    required this.onEditMeta,
    required this.onChooseTarget,
  });

  final CaptureDraft draft;
  final String templateLabel;
  final String? sourceLabel;
  final SaveTarget target;
  final VoidCallback onEditMeta;
  final VoidCallback onChooseTarget;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ms = draft.recognitionTime.inMilliseconds;
    final title = switch (target) {
      ExistingTextbook(:final textbook) => textbook.title,
      NewTextbook(:final title) => '새 교재 · $title',
    };
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onEditMeta,
            borderRadius: BorderRadius.circular(Radii.tile),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pageMetaLabel(draft.meta),
                    style: context.text.titleLarge,
                  ),
                ),
                Icon(Icons.edit_outlined, size: 18, color: t.ink3),
              ],
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            [
              templateLabel,
              ?sourceLabel,
              if (ms > 0) '판독 ${(ms / 1000).toStringAsFixed(1)}초',
            ].join(' · '),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              Pill(
                '단어 ${draft.entries.length}',
                background: t.paper2,
                foreground: t.ink,
              ),
              if (draft.needsReviewCount > 0)
                Pill(
                  '확인 필요 ${draft.needsReviewCount}',
                  background: t.riskBg,
                  foreground: t.risk,
                ),
              if (draft.correctedCount > 0)
                Pill(
                  '자동 보정 ${draft.correctedCount}',
                  background: t.okBg,
                  foreground: t.ok,
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.md),
            child: Divider(),
          ),
          InkWell(
            onTap: onChooseTarget,
            borderRadius: BorderRadius.circular(Radii.tile),
            child: Row(
              children: [
                Icon(Icons.menu_book_outlined, size: 20, color: t.ink2),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('저장할 교재', style: context.text.bodySmall),
                      Text(
                        title,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more, color: t.ink3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaEditor extends StatefulWidget {
  const _MetaEditor({required this.meta});

  final PageMeta meta;

  @override
  State<_MetaEditor> createState() => _MetaEditorState();
}

class _MetaEditorState extends State<_MetaEditor> {
  late final _day = TextEditingController(
    text: widget.meta.day?.toString() ?? '',
  );
  late final _title = TextEditingController(text: widget.meta.title ?? '');
  late final _page = TextEditingController(
    text: widget.meta.page?.toString() ?? '',
  );

  @override
  void dispose() {
    _day.dispose();
    _title.dispose();
    _page.dispose();
    super.dispose();
  }

  PageMeta _result() {
    final title = _title.text.trim();
    return PageMeta(
      day: _positive(_day.text),
      title: title.isEmpty ? null : title,
      page: _positive(_page.text),
    );
  }

  static int? _positive(String text) {
    final n = int.tryParse(text.trim());
    return n != null && n > 0 ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('쪽 정보', style: context.text.titleLarge),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _day,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'DAY'),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: TextField(
                  controller: _page,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '쪽'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'DAY 제목'),
          ),
          const SizedBox(height: Space.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_result()),
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }
}

class _TargetPicker extends StatefulWidget {
  const _TargetPicker({required this.shelf, required this.suggestedTitle});

  final List<ShelfItem> shelf;
  final String suggestedTitle;

  @override
  State<_TargetPicker> createState() => _TargetPickerState();
}

class _TargetPickerState extends State<_TargetPicker> {
  late final _title = TextEditingController(text: widget.suggestedTitle);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('어느 교재에 넣을까요?', style: context.text.titleLarge),
          const SizedBox(height: Space.md),
          for (final (i, item) in widget.shelf.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: BookSpine(
                label: item.textbook.title.characters.firstOrNull ?? '?',
                index: i,
              ),
              title: Text(
                item.textbook.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('단어 ${item.wordCount}개'),
              onTap: () =>
                  Navigator.of(context).pop(ExistingTextbook(item.textbook)),
            ),
          const SizedBox(height: Space.md),
          Text('새 교재', style: context.text.labelLarge?.copyWith(color: t.ink3)),
          const SizedBox(height: Space.sm),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '교재 이름'),
          ),
          const SizedBox(height: Space.md),
          FilledButton(
            onPressed: () {
              final title = _title.text.trim();
              if (title.isNotEmpty) {
                Navigator.of(context).pop(NewTextbook(title));
              }
            },
            child: const Text('새 교재로 저장'),
          ),
        ],
      ),
    );
  }
}

class _ShelfError extends StatelessWidget {
  const _ShelfError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '교재 목록을 불러오지 못해 저장할 수 없어요',
              style: TextStyle(
                color: t.risk,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 불러오기')),
        ],
      ),
    );
  }
}
