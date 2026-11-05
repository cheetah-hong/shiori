/// Ids per `IN (...)` query, well under SQLite's limit on bound variables.
const int idsPerQuery = 500;

/// [items] in runs of at most [size], in order.
Iterable<List<T>> chunked<T>(List<T> items, [int size = idsPerQuery]) sync* {
  for (var i = 0; i < items.length; i += size) {
    yield items.sublist(i, (i + size).clamp(0, items.length));
  }
}
