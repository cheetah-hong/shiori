import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/entry_editor_sheet.dart';
import 'package:shiori/features/capture/evidence_tile.dart';
import 'package:shiori/features/capture/evidence_view.dart';
import 'package:shiori/features/capture/fragment_tray.dart';
import 'package:shiori/features/capture/ocr_export.dart';
import 'package:shiori/features/playlists/playlist_actions.dart';
import 'package:shiori/features/playlists/playlist_picker.dart';
import 'package:shiori/shared/dictionary_notice.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// Which of the draft's headwords the library has, and how many of them
/// each playlist holds. The argument is the headwords, one per line.
final addPreviewProvider = FutureProvider.autoDispose
    .family<AddPreview, String>((ref, headwords) {
      ref.watch(dataRevisionProvider);
      return ref
          .watch(libraryServiceProvider)
          .previewAdd(headwords.split('\n'));
    });

/// 검토: check flagged cells, fix them, add the words to a playlist.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({
    super.key,
    required this.draft,
    this.sourceLabel,
    this.recognizerId,
    this.scan,
    this.photo,
  });

  final CaptureDraft draft;
  final String? sourceLabel;
  final String? recognizerId;

  /// The OCR passes of the page: drawn as the page when there is no [photo].
  final OcrScan? scan;

  /// The page photo, upright (as the OCR boxes): cut for the evidence view.
  final Uint8List? photo;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late CaptureDraft _draft = widget.draft;
  bool _onlyFlagged = false;
  bool _saving = false;

  /// Whether this page was read while a dictionary was not open. The words
  /// on screen stay as they were read, so the notice stays too (it says so
  /// once 「다시 시도」 opens the dictionaries).
  late final bool _readWithoutDictionary;

  @override
  void initState() {
    super.initState();
    _readWithoutDictionary = ref.read(dictionaryProblemProvider) != null;
  }

  EvidencePage get _page =>
      EvidencePage(photo: widget.photo, scan: widget.scan);

  Future<void> _showEvidence(int index, EntryField field) => showEvidence(
    context,
    entry: _draft.entries[index],
    field: field,
    page: _page,
  );

  void _pickCandidate(int index, EntryField field, String value) =>
      _replace(index, pickCandidate(_draft.entries[index], field, value));

  /// An unpaired fragment goes on an entry's cell or becomes a new entry,
  /// and leaves the tray.
  Future<void> _useFragment(Fragment fragment) async {
    final use = await showFragmentSheet(
      context,
      fragment: fragment,
      entries: _draft.entries,
    );
    if (use == null || !mounted) return;
    final rest = [
      for (final f in _draft.unpaired)
        if (f.id != fragment.id) f,
    ];
    setState(() {
      _draft = switch (use) {
        AttachFragment(:final index, :final field) =>
          _draft
              .replaceEntry(
                index,
                attachFragment(_draft.entries[index], field, fragment),
              )
              .copyWith(unpaired: rest),
        NewEntryFromFragment() => _draft.copyWith(
          entries: [..._draft.entries, entryFromFragment(fragment)],
          unpaired: rest,
        ),
      };
      // With the last flag fixed, the "확인 필요" filter would show nothing.
      if (_draft.needsReviewCount == 0) _onlyFlagged = false;
    });
  }

  /// "높음 전체 승인": confirms the entries whose pairings are all high.
  void _approveHigh() => setState(() => _draft = approveHighConfidence(_draft));

  Future<void> _edit(int index) async {
    final edited = await showEntryEditor(context, _draft.entries[index]);
    if (edited != null && mounted) _replace(index, edited);
  }

  void _toggle(int index, bool included) =>
      _replace(index, _draft.entries[index].copyWith(included: included));

  void _replace(int index, CapturedEntry entry) => setState(() {
    _draft = _draft.replaceEntry(index, entry);
    // With the last flag fixed, the "확인 필요" filter would show nothing.
    if (_draft.needsReviewCount == 0) _onlyFlagged = false;
  });

  /// The headwords the add would save, for the library preview.
  String get _headwordsKey => [
    for (final e in _draft.entries)
      if (e.included && e.headword.trim().isNotEmpty) e.headword.trim(),
  ].join('\n');

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final library = ref.read(libraryServiceProvider);
    // The picker shows how many of these words each playlist holds; without
    // the preview it still works, only without those counts.
    final preview = ref.read(addPreviewProvider(_headwordsKey)).value;
    final target = await showPlaylistPicker(context, preview: preview);
    if (target == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final result = await library.addDraft(_draft, to: target);
      if (!mounted) return;
      ref.read(dataRevisionProvider.notifier).bump();
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(addedMessage(result))));
    } on LibraryException catch (e) {
      _saveFailed(messenger, e.message);
    } on Exception catch (e, stack) {
      // A storage block failed (a disk error, say).
      debugPrint('add failed: $e\n$stack');
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
    final libraryKeys =
        ref.watch(addPreviewProvider(_headwordsKey)).value?.libraryKeys ??
        const <String>{};
    final entries = _draft.entries;
    bool inLibrary(CapturedEntry e) =>
        e.headword.trim().isNotEmpty &&
        libraryKeys.contains(wordKey(e.headword));
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
      appBar: AppBar(
        title: const Text('검토'),
        actions: [OcrExportButton(scan: widget.scan)],
      ),
      body: CustomScrollView(
        slivers: [
          if (_readWithoutDictionary)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                Space.md,
              ),
              sliver: SliverToBoxAdapter(child: ReadWithoutDictionaryNotice()),
            ),
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
                sourceLabel: widget.sourceLabel,
                inLibraryCount: entries
                    .where((e) => e.included && inLibrary(e))
                    .length,
                onApproveHigh:
                    _draft.entries.any((e) => e.evidence != null) &&
                        ref.watch(highConfidenceApprovalProvider)
                    ? _approveHigh
                    : null,
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
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              _draft.unpaired.isEmpty ? 120 : Space.xl,
            ),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
              itemBuilder: (_, k) {
                final i = visible[k];
                return EvidenceEntryTile(
                  key: ValueKey('word-$i'),
                  index: i,
                  entry: entries[i],
                  onEdit: () => _edit(i),
                  onToggle: (v) => _toggle(i, v),
                  onShowEvidence: (field) => _showEvidence(i, field),
                  onPickCandidate: (field, value) =>
                      _pickCandidate(i, field, value),
                  inLibrary: inLibrary(entries[i]),
                );
              },
            ),
          ),
          if (_draft.unpaired.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                120,
              ),
              sliver: SliverToBoxAdapter(
                child: FragmentTray(
                  fragments: _draft.unpaired,
                  onTap: _useFragment,
                ),
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
                  onPressed: saveable == 0 || _saving ? null : _add,
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.sheet,
                          ),
                        )
                      : const Icon(Icons.playlist_add),
                  label: Text('단어 $saveable개 추가'),
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
    required this.sourceLabel,
    required this.inLibraryCount,
    this.onApproveHigh,
  });

  final CaptureDraft draft;
  final String? sourceLabel;

  /// Included entries whose word the library has already.
  final int inLibraryCount;

  /// "높음 전체 승인"; null hides the button (switched off, or no evidence).
  final VoidCallback? onApproveHigh;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ms = draft.recognitionTime.inMilliseconds;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '단어 ${draft.entries.length}개',
            key: const ValueKey('review-heading'),
            style: context.text.titleLarge,
          ),
          const SizedBox(height: Space.xs),
          Text(
            [
              ?sourceLabel,
              if (ms > 0) '판독 ${(ms / 1000).toStringAsFixed(1)}초',
            ].join(' · '),
            key: const ValueKey('review-source'),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              if (draft.entries.any((e) => e.evidence != null))
                Pill(
                  '높음 ${draft.entries.where((e) => e.evidence?.isHigh ?? false).length}',
                  key: const ValueKey('high-count'),
                  background: t.okBg,
                  foreground: t.ok,
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
              if (draft.skippedKnown.isNotEmpty)
                Tooltip(
                  message: draft.skippedKnown.join(', '),
                  child: Pill(
                    '숨긴 단어 ${draft.skippedKnown.length}개는 뺐어요',
                    background: t.paper2,
                    foreground: t.ink2,
                  ),
                ),
            ],
          ),
          if (onApproveHigh != null) ...[
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: highConfidenceCount(draft) == 0 ? null : onApproveHigh,
              icon: const Icon(Icons.done_all),
              label: const Text('높음 전체 승인'),
            ),
          ],
          if (inLibraryCount > 0) ...[
            const SizedBox(height: Space.md),
            Text(
              '이미 있는 단어 $inLibraryCount개는 저장된 뜻을 그대로 써요',
              style: context.text.bodySmall?.copyWith(color: t.ink2),
            ),
          ],
        ],
      ),
    );
  }
}
