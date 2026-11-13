/// "판독 기록 내보내기": the page's two OCR passes in the recorded-fixture
/// format, handed to the share sheet so a page read
/// on a phone can be replayed on a desktop: from the review screen, and from
/// the capture screen when a page read gave no review. Only in builds that
/// are not release builds; the photo is never part of it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';

/// On in debug and profile builds, off in the store's release build.
const bool defaultOcrExportEnabled = !kReleaseMode;

/// One file to share: its name and its text.
@immutable
final class ExportFile {
  const ExportFile(this.name, this.text);

  final String name;
  final String text;
}

/// Whether the review screen offers the export, and how files are shared.
@immutable
final class OcrExport {
  const OcrExport({required this.enabled, required this.share});

  final bool enabled;
  final Future<void> Function(List<ExportFile> files) share;
}

final ocrExportProvider = Provider<OcrExport>(
  (ref) => const OcrExport(enabled: defaultOcrExportEnabled, share: shareFiles),
);

/// The share sheet with [files] as JSON attachments.
Future<void> shareFiles(List<ExportFile> files) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        for (final f in files)
          XFile.fromData(
            utf8.encode(f.text),
            name: f.name,
            mimeType: 'application/json',
          ),
      ],
      fileNameOverrides: [for (final f in files) f.name],
    ),
  );
}

/// `<name>.ja.json` and `<name>.ko.json`, each pass as
/// `FixtureTextRecognizer` reads it back. [at] names the files.
List<ExportFile> ocrExportFiles(OcrScan scan, {required DateTime at}) {
  final name = 'shiori-ocr-${_stamp(at)}';
  const json = JsonEncoder.withIndent(' ');
  return [
    ExportFile('$name.ja.json', json.convert(scan.japanese.toJson())),
    ExportFile('$name.ko.json', json.convert(scan.korean.toJson())),
  ];
}

String _stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

/// The export's name on its buttons.
const String ocrExportLabel = '판독 기록 내보내기';

/// Hands [scan]'s files to the share sheet; says so when it fails.
Future<void> shareOcrExport(
  BuildContext context,
  WidgetRef ref,
  OcrScan scan,
) async {
  final export = ref.read(ocrExportProvider);
  final files = ocrExportFiles(scan, at: ref.read(clockProvider).now());
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await export.share(files);
  } on Exception catch (e) {
    debugPrint('OCR export failed: $e');
    messenger?.showSnackBar(const SnackBar(content: Text('판독 기록을 내보내지 못했어요')));
  }
}

/// The review screen's export button: shown only when the export is on and
/// the page's OCR passes are at hand.
class OcrExportButton extends ConsumerWidget {
  const OcrExportButton({super.key, required this.scan});

  final OcrScan? scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = this.scan;
    if (!ref.watch(ocrExportProvider).enabled || scan == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const ValueKey('export-ocr'),
      tooltip: ocrExportLabel,
      icon: const Icon(CupertinoIcons.share),
      onPressed: () => unawaited(shareOcrExport(context, ref, scan)),
    );
  }
}

/// The capture screen's failure note's export button, under its message:
/// shown only when the export is on and the page was read.
class OcrExportFailureButton extends ConsumerWidget {
  const OcrExportFailureButton({super.key, required this.scan});

  final OcrScan? scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = this.scan;
    if (!ref.watch(ocrExportProvider).enabled || scan == null) {
      return const SizedBox.shrink();
    }
    return OutlinedButton(
      key: const ValueKey('export-ocr-failed'),
      onPressed: () => unawaited(shareOcrExport(context, ref, scan)),
      child: const Text(ocrExportLabel),
    );
  }
}
