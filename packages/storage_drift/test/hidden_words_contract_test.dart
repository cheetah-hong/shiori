import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

import 'contract/hidden_words_contract.dart';

final class _InMemory implements HidingStorageUnderTest {
  final _library = InMemoryLibraryRepository();

  @override
  LibraryRepository get library => _library;
  @override
  HiddenWordRepository get hidden => _library;
  @override
  final ReviewRepository reviews = InMemoryReviewRepository();

  @override
  Future<void> close() async {}
}

final class _Drift implements HidingStorageUnderTest {
  _Drift(this._db)
    : _library = DriftLibraryRepository(_db),
      reviews = DriftReviewRepository(_db);

  final ShioriDatabase _db;
  final DriftLibraryRepository _library;

  @override
  LibraryRepository get library => _library;
  @override
  HiddenWordRepository get hidden => _library;
  @override
  final ReviewRepository reviews;

  @override
  Future<void> close() => _db.close();
}

void main() {
  hiddenWordsContract('in-memory', _InMemory.new);
  hiddenWordsContract('drift', () => _Drift(ShioriDatabase.memory()));
}
