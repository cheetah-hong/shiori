import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

import 'contract/card_reset_contract.dart';
import 'contract/repository_contract.dart';

final class _InMemory implements StorageUnderTest {
  @override
  final LibraryRepository library = InMemoryLibraryRepository();
  @override
  final ReviewRepository reviews = InMemoryReviewRepository();

  @override
  Future<void> close() async {}
}

final class _Drift implements StorageUnderTest {
  _Drift(this._db)
    : library = DriftLibraryRepository(_db),
      reviews = DriftReviewRepository(_db);

  final ShioriDatabase _db;
  @override
  final LibraryRepository library;
  @override
  final ReviewRepository reviews;

  @override
  Future<void> close() => _db.close();
}

void main() {
  repositoryContract('in-memory', _InMemory.new);
  repositoryContract('drift', () => _Drift(ShioriDatabase.memory()));
  cardResetContract('in-memory', _InMemory.new);
  cardResetContract('drift', () => _Drift(ShioriDatabase.memory()));
}
