import 'package:flutter/material.dart';
import 'package:shiori/features/capture/capture_screen.dart';
import 'package:shiori/features/decks/decks_screen.dart';
import 'package:shiori/features/words/word_add_sheet.dart';
import 'package:shiori/features/words/word_labels.dart';
import 'package:shiori/shared/action_sheet.dart';
import 'package:shiori/shared/navigation.dart';

enum _Way { direct, photo, decks }

/// 단어 추가: by hand (into playlist [playlistId]), from a photo, or from a
/// built-in deck.
Future<void> showWordAddMenu(BuildContext context, {String? playlistId}) async {
  final way = await showChoices<_Way>(
    context,
    choices: const [
      SheetChoice(label: WordLabels.direct, value: _Way.direct),
      SheetChoice(label: WordLabels.photo, value: _Way.photo),
      SheetChoice(label: WordLabels.decks, value: _Way.decks),
    ],
  );
  if (way == null || !context.mounted) return;
  switch (way) {
    case _Way.direct:
      await showWordAdder(context, playlistId: playlistId);
    case _Way.photo:
      await pushScreen<void>(context, const CaptureScreen());
    case _Way.decks:
      await pushScreen<void>(context, const DecksScreen());
  }
}
