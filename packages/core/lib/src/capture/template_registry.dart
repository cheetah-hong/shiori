import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/ports/textbook_template.dart';

/// Holds the installed textbook templates and picks one per page.
final class TemplateRegistry {
  TemplateRegistry(List<TextbookTemplate> templates)
    : templates = List.unmodifiable(templates) {
    if (templates.isEmpty) {
      throw ArgumentError('TemplateRegistry needs at least one template');
    }
    final ids = templates.map((t) => t.id).toSet();
    if (ids.length != templates.length) {
      throw ArgumentError('template ids must be unique');
    }
  }

  final List<TextbookTemplate> templates;

  /// Highest `match` score; on a tie the template registered first wins.
  TextbookTemplate detect(OcrScan scan) {
    var best = templates.first;
    var bestScore = best.match(scan);
    for (final t in templates.skip(1)) {
      final s = t.match(scan);
      if (s > bestScore) {
        best = t;
        bestScore = s;
      }
    }
    return best;
  }

  TextbookTemplate? byId(String id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }
}
