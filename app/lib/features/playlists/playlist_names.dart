import 'package:flutter/material.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/keep_words.dart';
import 'package:shiori/shared/adaptive_dialog.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori_core/shiori_core.dart';

/// What is wrong with [name] as a playlist name (null: nothing). [taken]
/// are the other playlists' names; spaces, case and width do not count.
String? playlistNameProblem(String name, Iterable<String> taken) {
  if (name.trim().isEmpty) return '';
  final key = playlistNameKey(name);
  return taken.any((t) => playlistNameKey(t) == key)
      ? '같은 이름의 재생목록이 있어요'
      : null;
}

/// Asks for a playlist name: [title] (`새 재생목록`, `이름 바꾸기`), the
/// field filled with [initial], [action] to confirm. Returns the trimmed
/// name, or null when cancelled.
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  required String action,
  required Iterable<String> taken,
  String initial = '',
}) => showAdaptiveDialog<String>(
  context: context,
  builder: (_) => _NameDialog(
    title: title,
    action: action,
    taken: List.unmodifiable(taken),
    initial: initial,
  ),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.action,
    required this.taken,
    required this.initial,
  });

  final String title;
  final String action;
  final List<String> taken;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final problem = playlistNameProblem(_name.text, widget.taken);
    void submit() => Navigator.of(context).pop(_name.text.trim());
    // An iOS alert on the phone; the field needs a Material ancestor there.
    return AlertDialog.adaptive(
      title: CappedText(
        max: TextCaps.chrome,
        child: KeepWordsText(widget.title),
      ),
      content: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: '재생목록 이름',
              errorText: problem == null || problem.isEmpty ? null : problem,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: problem == null ? (_) => submit() : null,
          ),
        ),
      ),
      actions: [
        adaptiveDialogAction(
          context,
          label: '취소',
          onPressed: () => Navigator.of(context).pop(),
        ),
        adaptiveDialogAction(
          context,
          label: widget.action,
          isDefault: true,
          onPressed: problem == null ? submit : null,
        ),
      ],
    );
  }
}
