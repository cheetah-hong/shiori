import 'dart:convert';

import 'package:drift/drift.dart';

/// Stores a time as microseconds since the Unix epoch (an instant in UTC).
///
/// Reads come back as local time for the same instant, which is what the
/// app's clock gives, so a saved local time reads back equal (`==`) and the
/// study day boundary (`dayStartHour`, local hour) is computed as before.
/// Microseconds keep the full precision of a Dart `DateTime`.
final class UtcMicrosConverter extends TypeConverter<DateTime, int> {
  const UtcMicrosConverter();

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMicrosecondsSinceEpoch(fromDb);

  @override
  int toSql(DateTime value) => value.microsecondsSinceEpoch;
}

/// Stores the readings of a word as a JSON array of strings, in order.
///
/// A row that does not hold such an array fails with a [FormatException]
/// instead of reading as an empty list.
final class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb);
    if (decoded is! List || decoded.any((e) => e is! String)) {
      throw FormatException('expected a JSON array of strings', fromDb);
    }
    return List.unmodifiable(decoded.cast<String>());
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
