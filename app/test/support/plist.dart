/// A reader for the XML property lists in the repository (Info.plist,
/// PrivacyInfo.xcprivacy): dict, array, string, integer, true and false.
/// Enough for the release settings tests; not a general plist parser.
library;

/// The top-level dictionary of [xml]. Throws [FormatException] for anything
/// this reader does not know.
Map<String, Object?> readPlist(String xml) {
  final body = RegExp(
    r'<plist[^>]*>([\s\S]*)</plist>',
  ).firstMatch(xml)?.group(1);
  if (body == null) throw const FormatException('no <plist> element');
  final reader = _Reader(_tokens(body));
  final value = reader.value();
  if (!reader.done) throw const FormatException('text after the top value');
  if (value is! Map<String, Object?>) {
    throw const FormatException('the top value is not a dict');
  }
  return value;
}

/// Tags (`<dict>`, `</key>`, `<true/>`) and the text between them, without
/// comments and blank text.
List<String> _tokens(String body) {
  final withoutComments = body.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  return [
    for (final m in RegExp(r'<[^>]+>|[^<]+').allMatches(withoutComments))
      if (m.group(0)!.trim().isNotEmpty) m.group(0)!,
  ];
}

final class _Reader {
  _Reader(this._tokens);

  final List<String> _tokens;
  var _at = 0;

  bool get done => _at >= _tokens.length;

  String _next() {
    if (done) throw const FormatException('unexpected end');
    return _tokens[_at++];
  }

  void _expect(String tag) {
    final got = _next();
    if (got != tag) throw FormatException('expected $tag, got $got');
  }

  /// Text up to [closing]; empty when the element is empty.
  String _text(String closing) {
    if (_tokens[_at] == closing) {
      _at++;
      return '';
    }
    final text = _next();
    _expect(closing);
    return _unescape(text);
  }

  Object? value() {
    final tag = _next();
    switch (tag) {
      case '<true/>':
        return true;
      case '<false/>':
        return false;
      case '<string/>':
        return '';
      case '<array/>':
        return const <Object?>[];
      case '<dict/>':
        return const <String, Object?>{};
      case '<string>':
        return _text('</string>');
      case '<integer>':
        return int.parse(_text('</integer>').trim());
      case '<array>':
        final items = <Object?>[];
        while (_tokens[_at] != '</array>') {
          items.add(value());
        }
        _at++;
        return List<Object?>.unmodifiable(items);
      case '<dict>':
        final entries = <String, Object?>{};
        while (_tokens[_at] != '</dict>') {
          _expect('<key>');
          final key = _text('</key>');
          if (entries.containsKey(key)) {
            throw FormatException('duplicate key $key');
          }
          entries[key] = value();
        }
        _at++;
        return Map<String, Object?>.unmodifiable(entries);
    }
    throw FormatException('unknown plist element $tag');
  }

  static String _unescape(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
