// 설정 › 백업 as a use case: export, open, restore with the copy kept from
// just before, and undoing a restore (K6·K9). Made-up words only.
import 'dart:async';
import 'dart:typed_data';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/backup_sample.dart';

/// Everything stored, in memory.
final class _Store implements BackupStore {
  _Store([BackupData? data]) : data = data ?? BackupData();

  BackupData data;
  int reads = 0;
  int replaces = 0;

  @override
  Future<BackupData> read() async {
    reads++;
    return data;
  }

  @override
  Future<void> replaceAll(BackupData data) async {
    replaces++;
    this.data = data;
  }
}

/// The kept copy, in memory; [failing] makes keeping fail.
final class _Keeper implements BackupKeeper {
  Uint8List? bytes;
  DateTime? at;
  bool failing = false;
  DateTime clock = DateTime(2026, 11, 12, 22, 31);

  @override
  Future<void> keep(Uint8List bytes) async {
    if (failing) throw StateError('disk full');
    this.bytes = bytes;
    at = clock;
  }

  @override
  Future<Uint8List?> read() async => bytes;

  @override
  Future<DateTime?> keptAt() async => at;

  @override
  Future<void> discard() async {
    bytes = null;
    at = null;
  }
}

/// A smaller library than the sample: two words, one playlist.
BackupData _other() => BackupData(
  words: [
    BackupWord(
      id: 'w-other-0',
      key: '灯台',
      headword: '灯台',
      readings: const ['とうだい'],
      meaning: '등대',
      createdAt: DateTime(2026, 9, 1),
    ),
    BackupWord(
      id: 'w-other-1',
      key: '港町',
      headword: '港町',
      readings: const ['みなとまち'],
      meaning: '항구 도시',
      createdAt: DateTime(2026, 9, 2),
    ),
  ],
  playlists: [
    BackupPlaylist(
      id: 'pl-other',
      name: '바다',
      createdAt: DateTime(2026, 9, 1),
      position: 0,
    ),
  ],
  playlistWords: [
    BackupPlaylistWord(
      playlistId: 'pl-other',
      wordId: 'w-other-0',
      position: 0,
      addedAt: DateTime(2026, 9, 1),
    ),
  ],
  settings: const {StudySettingKeys.recordMode: 'shared'},
);

BackupService _service(
  _Store store,
  _Keeper keeper, {
  int maxBytes = backupMaxBytes,
  BackupWork work = backupWorkHere,
}) => BackupService(
  store: store,
  keeper: keeper,
  clock: FixedClock(backupNow),
  app: () async => sampleApp,
  maxBytes: maxBytes,
  work: work,
);

void main() {
  group('export', () {
    test('everything stored, named after now, with the app', () async {
      final store = _Store(sampleBackupData());

      final export = await _service(store, _Keeper()).export();

      expect(export.fileName, 'shiori-backup-20261112-2230.json');
      final file = decodeBackup(export.bytes);
      expect(file.data, sampleBackupData());
      expect(file.app, sampleApp);
      expect(file.createdAt, backupNow);
    });

    test('over the limit: refused, nothing written anywhere', () async {
      final store = _Store(sampleBackupData());
      final keeper = _Keeper();

      await expectLater(
        _service(store, keeper, maxBytes: 100).export(),
        throwsA(
          isA<BackupException>().having(
            (e) => e.problem,
            'problem',
            BackupProblem.tooLarge,
          ),
        ),
      );
      expect(store.replaces, 0);
      expect(keeper.bytes, isNull);
    });

    test('encoding and checking run through the given worker', () async {
      var runs = 0;
      Future<R> counting<R>(FutureOr<R> Function() work) async {
        runs++;
        return work();
      }

      final service = _service(
        _Store(sampleBackupData()),
        _Keeper(),
        work: counting,
      );
      final export = await service.export();
      expect(runs, greaterThan(0));
      final before = runs;
      await service.open(export.bytes);
      expect(runs, greaterThan(before));
    });
  });

  group('open', () {
    test('a good file comes back checked, with its summary', () async {
      final bytes = encodeBackup(sampleBackupFile());

      final file = await _service(_Store(), _Keeper()).open(bytes);

      expect(file.data, sampleBackupData());
      expect(file.summary.words, 30);
    });

    test('a bad file: the problem, and nothing stored is touched', () async {
      final store = _Store(_other());
      final keeper = _Keeper();

      await expectLater(
        _service(store, keeper).open(bytesOf({'format': 'shiori-backup'})),
        throwsA(isA<BackupException>()),
      );
      expect(store.data, _other());
      expect(store.replaces, 0);
      expect(keeper.bytes, isNull);
    });
  });

  group('K9 restore keeps the data from just before', () {
    test(
      'hasData: words or presses count, study options alone do not',
      () async {
        expect(await _service(_Store(), _Keeper()).hasData(), isFalse);
        expect(
          await _service(
            _Store(
              BackupData(settings: const {StudySettingKeys.shuffle: 'off'}),
            ),
            _Keeper(),
          ).hasData(),
          isFalse,
        );
        expect(await _service(_Store(_other()), _Keeper()).hasData(), isTrue);
        expect(
          await _service(
            _Store(BackupData(logs: sampleBackupData().logs)),
            _Keeper(),
          ).hasData(),
          isTrue,
        );
      },
    );

    test('what was stored is kept, then everything is replaced', () async {
      final store = _Store(_other());
      final keeper = _Keeper();
      final service = _service(store, keeper);

      await service.restore(sampleBackupFile());

      expect(store.data, sampleBackupData());
      expect(decodeBackup(keeper.bytes!).data, _other());
      expect(await service.keptAt(), DateTime(2026, 11, 12, 22, 31));
    });

    test('an empty library is not kept (a first restore)', () async {
      final store = _Store(
        BackupData(settings: const {StudySettingKeys.shuffle: 'off'}),
      );
      final keeper = _Keeper();
      final service = _service(store, keeper);

      await service.restore(sampleBackupFile());

      expect(store.data, sampleBackupData());
      expect(keeper.bytes, isNull);
      expect(await service.keptAt(), isNull);
    });

    test('when the copy cannot be kept, nothing is restored', () async {
      final store = _Store(_other());
      final keeper = _Keeper()..failing = true;

      await expectLater(
        _service(store, keeper).restore(sampleBackupFile()),
        throwsA(isA<BackupNotKeptException>()),
      );
      expect(store.data, _other());
      expect(store.replaces, 0);
    });

    test('a second restore keeps the data from just before it', () async {
      final store = _Store(_other());
      final keeper = _Keeper();
      final service = _service(store, keeper);
      await service.restore(sampleBackupFile());

      await service.restore(
        BackupFile(createdAt: backupNow, app: sampleApp, data: _other()),
      );

      expect(store.data, _other());
      expect(decodeBackup(keeper.bytes!).data, sampleBackupData());
    });
  });

  group('K9 undo', () {
    test('puts back the kept copy and removes it', () async {
      final store = _Store(_other());
      final keeper = _Keeper();
      final service = _service(store, keeper);
      await service.restore(sampleBackupFile());

      await service.undoRestore();

      expect(store.data, _other());
      expect(keeper.bytes, isNull);
      expect(await service.keptAt(), isNull);
    });

    test('with no kept copy: a StateError, nothing changes', () async {
      final store = _Store(_other());
      final service = _service(store, _Keeper());

      await expectLater(service.undoRestore(), throwsStateError);
      expect(store.data, _other());
      expect(store.replaces, 0);
    });

    test('a damaged kept copy: the problem, nothing changes', () async {
      final store = _Store(_other());
      final keeper = _Keeper()
        ..bytes = Uint8List.fromList([1, 2, 3])
        ..at = DateTime(2026, 11, 12, 22, 31);

      await expectLater(
        _service(store, keeper).undoRestore(),
        throwsA(isA<BackupException>()),
      );
      expect(store.data, _other());
      expect(keeper.bytes, isNotNull);
    });
  });
}
