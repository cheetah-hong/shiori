/// OCR scan → review draft. Every page is read by the general extractor
/// (docs/extraction.md, 9: why the row templates were taken out).
library;

import 'package:shiori_core/src/extract/extracted_word.dart';
import 'package:shiori_core/src/extract/general_extractor.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/ocr.dart';

/// The review draft of [scan]: the words [extractor] finds, minus the
/// [knownHeadwords] (every headword in the learner's library, hidden words
/// too), in the order the photo shows them, with the text nothing paired
/// with for the tray.
Future<CaptureDraft> pageDraft(
  GeneralExtractor extractor,
  OcrScan scan, {
  Set<String> knownHeadwords = const {},
}) async {
  final extraction = await extractor.extract(
    scan,
    knownHeadwords: knownHeadwords,
  );
  return CaptureDraft(
    entries: List.unmodifiable([
      for (final w in _inPhotoOrder(extraction.words))
        w.toCapturedEntry(fragments: extraction.fragments),
    ]),
    recognitionTime: scan.elapsed,
    unpaired: extraction.unpaired,
    skippedKnown: extraction.skippedKnown,
  );
}

/// [words] by where their headword sits in the photo: fragments are numbered
/// in reading order (top to bottom, left to right). The sort is stable, and
/// a word without a headword fragment keeps its place after the others.
List<ExtractedWord> _inPhotoOrder(List<ExtractedWord> words) {
  int place(ExtractedWord w) => w.headwordFragmentId ?? _afterEveryFragment;
  final indexed = [...words.indexed]
    ..sort((a, b) {
      final byPlace = place(a.$2).compareTo(place(b.$2));
      return byPlace != 0 ? byPlace : a.$1.compareTo(b.$1);
    });
  return [for (final (_, w) in indexed) w];
}

const int _afterEveryFragment = 1 << 30;
