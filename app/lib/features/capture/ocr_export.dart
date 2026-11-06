/// "판독 기록 내보내기": the page's two OCR passes in the recorded-fixture
/// format, handed to the share sheet so a page read
/// on a phone can be replayed on a desktop. Only in builds that are not
/// release builds; the photo is never part of it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

/// The review screen's export button: shown only when the export is on and
/// the page's OCR passes are at hand.
class OcrExportButton extends ConsumerWidget {
  const OcrExportButton({super.key, required this.scan});

  final OcrScan? scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final export = ref.watch(ocrExportProvider);
    final scan = this.scan;
    if (!export.enabled || scan == null) return const SizedBox.shrink();
    return IconButton(
      key: const ValueKey('export-ocr'),
      tooltip: '판독 기록 내보내기',
      icon: const Icon(Icons.ios_share),
      onPressed: () => unawaited(
        _share(
          context,
          export,
          ocrExportFiles(scan, at: ref.read(clockProvider).now()),
        ),
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    OcrExport export,
    List<ExportFile> files,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await export.share(files);
    } on Exception catch (e) {
      debugPrint('OCR export failed: $e');
      messenger?.showSnackBar(
        const SnackBar(content: Text('판독 기록을 내보내지 못했습니다')),
      );
    }
  }
}
