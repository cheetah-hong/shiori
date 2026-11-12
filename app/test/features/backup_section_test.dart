// 설정 › 백업 (K7·K9): 백업 파일 만들기 hands a file to the share sheet,
// 백업에서 복원 asks with the file's summary before replacing anything, a
// bad file says why and changes nothing, and 복원 전으로 되돌리기 puts the
// data from before back. Fakes stand in for the share sheet, the picker,
// the store and the kept copy. Made-up words only.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/backup_files.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/settings/settings_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

const _app = BackupApp(version: '1.0.0', build: '3', schema: 5);

/// Everything stored, in memory.
final class _Store implements BackupStore {
  _Store(this.data);

  BackupData data;
  Object? failing;

  @override
  Future<BackupData> read() async => data;

  @override
  Future<void> replaceAll(BackupData data) async {
    final failure = failing;
    if (failure != null) throw failure;
    this.data = data;
  }
}

/// The kept copy, in memory, kept at the test's fixed time.
final class _Keeper implements BackupKeeper {
  Uint8List? bytes;
  DateTime? at;
  bool failing = false;

  @override
  Future<void> keep(Uint8List bytes) async {
    if (failing) throw const FileSystemLikeError();
    this.bytes = bytes;
    at = testNow;
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

final class FileSystemLikeError implements Exception {
  const FileSystemLikeError();
}

BackupWord _word(String id, String headword, String meaning) => BackupWord(
  id: id,
  key: headword,
  headword: headword,
  readings: const ['よみ'],
  meaning: meaning,
  createdAt: DateTime(2026, 10, 1),
);

/// What is on the device before a restore: one word.
BackupData _current() => BackupData(
  words: [_word('w-now', '灯台', '등대')],
  settings: const {StudySettingKeys.dailyGoal: '20'},
);

/// What the picked file holds: 3 words, 1 playlist, 2 presses.
BackupData _backup() => BackupData(
  words: [
    _word('w-b0', '風車', '바람개비'),
    _word('w-b1', '雨傘', '우산'),
    _word('w-b2', '小道', '오솔길'),
  ],
  playlists: [
    BackupPlaylist(
      id: 'pl-b',
      name: '자연',
      createdAt: DateTime(2026, 10, 1),
      position: 0,
    ),
  ],
  playlistWords: [
    BackupPlaylistWord(
      playlistId: 'pl-b',
      wordId: 'w-b0',
      position: 0,
      addedAt: DateTime(2026, 10, 1),
    ),
  ],
  logs: [
    for (var i = 1; i <= 2; i++)
      BackupLog(
        id: i,
        wordId: 'w-b0',
        answer: Answer.known,
        at: DateTime(2026, 10, 2, 8, i),
        levelBefore: 0,
        levelAfter: 4,
        retriesInSession: 0,
      ),
  ],
);

Uint8List _file(BackupData data) => encodeBackup(
  BackupFile(createdAt: DateTime(2026, 11, 5, 20), app: _app, data: data),
);

/// The share sheet, the picker and the store, as a test sets them.
final class _Device {
  _Device({BackupData? stored}) : store = _Store(stored ?? _current());

  final _Store store;
  final keeper = _Keeper();
  final shared = <(BackupExport, Rect?)>[];
  BackupShareResult shareResult = BackupShareResult.shared;
  Object? shareFailure;
  List<int>? picked;
  Object? pickFailure;
  int picks = 0;
  int maxBytes = backupMaxBytes;

  List<Override> get overrides => [
    backupStoreProvider.overrideWithValue(store),
    backupKeeperProvider.overrideWithValue(keeper),
    backupAppProvider.overrideWithValue(() async => _app),
    backupWorkProvider.overrideWithValue(backupWorkHere),
    backupServiceProvider.overrideWith(
      (ref) => BackupService(
        store: store,
        keeper: keeper,
        clock: ref.watch(clockProvider),
        app: () async => _app,
        maxBytes: maxBytes,
      ),
    ),
    backupShareProvider.overrideWithValue((file, origin) async {
      final failure = shareFailure;
      if (failure != null) throw failure;
      shared.add((file, origin));
      return shareResult;
    }),
    backupPickerProvider.overrideWithValue(() async {
      picks++;
      final failure = pickFailure;
      if (failure != null) throw failure;
      return picked;
    }),
  ];
}

Future<void> _open(WidgetTester tester, _Device device) async {
  usePhoneSize(tester);
  await tester.pumpWidget(
    screen(TestBlocks(), const SettingsScreen(), extra: device.overrides),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the settings list to [text] and taps it.
Future<void> _tapRow(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  group('the 백업 rows', () {
    testWidgets('two rows and what a backup leaves out', (tester) async {
      await _open(tester, _Device());
      await tester.scrollUntilVisible(
        find.text('백업에서 복원'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('백업'), findsOneWidget);
      expect(find.text('백업 파일 만들기'), findsOneWidget);
      expect(find.text('단어·재생목록·학습 기록·설정을 파일 하나로 저장해요'), findsOneWidget);
      expect(find.text('백업에서 복원'), findsOneWidget);
      expect(find.text('파일 앱에서 백업 파일을 골라 지금 데이터를 바꿔요'), findsOneWidget);
      expect(find.text('사진·사전·목소리는 백업에 들어가지 않아요(앱에 같이 있어요).'), findsOneWidget);
      expect(find.text('복원 전으로 되돌리기'), findsNothing);
    });
  });

  group('K7 백업 파일 만들기', () {
    testWidgets('hands the file to the share sheet at the row', (tester) async {
      final device = _Device();
      await _open(tester, device);

      await _tapRow(tester, '백업 파일 만들기');

      expect(device.shared, hasLength(1));
      final (file, origin) = device.shared.single;
      expect(file.fileName, 'shiori-backup-20261105-2100.json');
      final back = decodeBackup(file.bytes);
      expect(back.data, _current());
      expect(back.app, _app);
      expect(origin, isNotNull);
      expect(origin!.isEmpty, isFalse);
      expect(find.text('백업 파일을 내보냈어요'), findsOneWidget);
    });

    testWidgets('closing the sheet says nothing', (tester) async {
      final device = _Device()..shareResult = BackupShareResult.dismissed;
      await _open(tester, device);

      await _tapRow(tester, '백업 파일 만들기');

      expect(device.shared, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a share that fails says so', (tester) async {
      final device = _Device()..shareFailure = Exception('no sheet');
      await _open(tester, device);

      await _tapRow(tester, '백업 파일 만들기');

      expect(find.text('백업 파일을 만들지 못했어요. 다시 시도해 주세요'), findsOneWidget);
    });

    testWidgets('a backup over the limit is not made', (tester) async {
      final device = _Device()..maxBytes = 100;
      await _open(tester, device);

      await _tapRow(tester, '백업 파일 만들기');

      expect(device.shared, isEmpty);
      expect(find.text('백업이 너무 커서(64MB 넘음) 파일을 만들 수 없어요'), findsOneWidget);
    });
  });

  group('K7 백업에서 복원', () {
    testWidgets('asks with the summary; 취소 changes nothing', (tester) async {
      final device = _Device()..picked = _file(_backup());
      await _open(tester, device);

      await _tapRow(tester, '백업에서 복원');

      expect(device.picks, 1);
      expect(find.text('백업에서 복원할까요?'), findsOneWidget);
      expect(
        find.textContaining('2026년 11월 5일 20:00에 만든 백업 · 시오리 1.0.0'),
        findsOneWidget,
      );
      expect(find.textContaining('단어 3개 · 재생목록 1개 · 학습 기록 2건'), findsOneWidget);
      expect(
        find.textContaining('지금 앱의 단어·재생목록·학습 기록·설정이 모두 이 백업 내용으로 바뀌어요.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('복원 전 데이터는 앱 안에 한 번 보관해 두어 되돌릴 수 있어요.'),
        findsOneWidget,
      );

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(device.store.data, _current());
      expect(device.keeper.bytes, isNull);
    });

    testWidgets('복원 replaces everything and offers to undo', (tester) async {
      final device = _Device()..picked = _file(_backup());
      await _open(tester, device);
      await _tapRow(tester, '백업에서 복원');

      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();

      expect(device.store.data, _backup());
      expect(decodeBackup(device.keeper.bytes!).data, _current());
      expect(find.text('복원했어요 · 단어 3개 · 재생목록 1개'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('복원 전으로 되돌리기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('11월 5일 21:00 복원 직전 데이터'), findsOneWidget);
    });

    testWidgets('on an empty app nothing is kept and nothing is offered', (
      tester,
    ) async {
      final device = _Device(stored: BackupData())..picked = _file(_backup());
      await _open(tester, device);
      await _tapRow(tester, '백업에서 복원');

      expect(find.textContaining('복원 전 데이터는 앱 안에 한 번 보관해 두어'), findsNothing);
      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();

      expect(device.store.data, _backup());
      expect(device.keeper.bytes, isNull);
      expect(find.text('복원 전으로 되돌리기'), findsNothing);
    });

    testWidgets('cancelling the picker does nothing', (tester) async {
      final device = _Device();
      await _open(tester, device);

      await _tapRow(tester, '백업에서 복원');

      expect(device.picks, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(device.store.data, _current());
    });
  });

  group('K7 files that cannot be restored', () {
    Future<void> refused(
      WidgetTester tester,
      _Device device,
      String message,
    ) async {
      await _open(tester, device);
      await _tapRow(tester, '백업에서 복원');

      expect(find.text('복원하지 못했어요'), findsOneWidget);
      expect(find.textContaining(message), findsOneWidget);
      expect(find.textContaining('지금 데이터는 바뀌지 않았어요'), findsOneWidget);
      expect(find.text('백업에서 복원할까요?'), findsNothing);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(device.store.data, _current());
      expect(device.keeper.bytes, isNull);
    }

    testWidgets('a file from a newer app', (tester) async {
      await refused(
        tester,
        _Device()
          ..picked = utf8.encode('{"format":"shiori-backup","version":2}'),
        '더 새 버전의 시오리에서 만든 백업이에요. 앱을 업데이트한 뒤 다시 복원해 주세요',
      );
    });

    testWidgets('a file that is not a backup', (tester) async {
      await refused(
        tester,
        _Device()..picked = utf8.encode('[1, 2, 3]'),
        '시오리 백업 파일이 아니에요. 「백업 파일 만들기」로 만든 .json 파일을 골라 주세요',
      );
    });

    testWidgets('a damaged backup', (tester) async {
      final doc =
          jsonDecode(utf8.decode(_file(_backup()))) as Map<String, Object?>;
      final rows =
          (doc['playlistWords']! as Map<String, Object?>)['rows']! as List;
      (rows.first as List)[1] = 'w-missing';
      await refused(
        tester,
        _Device()..picked = utf8.encode(jsonEncode(doc)),
        '백업 파일이 손상되어 복원할 수 없어요',
      );
    });

    testWidgets('a file over the limit', (tester) async {
      await refused(
        tester,
        _Device()..pickFailure = const BackupException(BackupProblem.tooLarge),
        '파일이 너무 커요(64MB 넘음). 시오리 백업 파일이 맞는지 확인해 주세요',
      );
    });

    testWidgets('when the data now cannot be kept, nothing is restored', (
      tester,
    ) async {
      final device = _Device()..picked = _file(_backup());
      device.keeper.failing = true;
      await _open(tester, device);
      await _tapRow(tester, '백업에서 복원');

      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();

      expect(find.text('복원하지 못했어요'), findsOneWidget);
      expect(find.textContaining('지금 데이터를 보관하지 못해 복원하지 않았어요'), findsOneWidget);
      expect(device.store.data, _current());
    });

    testWidgets('when the restore itself fails, it says so', (tester) async {
      final device = _Device()..picked = _file(_backup());
      device.store.failing = Exception('disk');
      await _open(tester, device);
      await _tapRow(tester, '백업에서 복원');

      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();

      expect(find.text('복원하지 못했어요'), findsOneWidget);
      expect(find.textContaining('지금 데이터는 바뀌지 않았어요'), findsOneWidget);
      expect(device.store.data, _current());
    });
  });

  group('K9 복원 전으로 되돌리기', () {
    testWidgets('asks, then puts the data from before back', (tester) async {
      final device = _Device()..picked = _file(_backup());
      await _open(tester, device);
      await _tapRow(tester, '백업에서 복원');
      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();

      await _tapRow(tester, '복원 전으로 되돌리기');

      expect(find.text('복원 전으로 되돌릴까요?'), findsOneWidget);
      expect(
        find.textContaining('11월 5일 21:00 복원 직전 데이터로 바뀌어요'),
        findsOneWidget,
      );
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();

      expect(device.store.data, _current());
      expect(device.keeper.bytes, isNull);
      expect(find.text('복원 전으로 되돌렸어요'), findsOneWidget);
      expect(find.text('복원 전으로 되돌리기'), findsNothing);
    });

    testWidgets('취소 keeps the restored data and the copy', (tester) async {
      final device = _Device()..picked = _file(_backup());
      await _open(tester, device);
      await _tapRow(tester, '백업에서 복원');
      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();

      await _tapRow(tester, '복원 전으로 되돌리기');
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(device.store.data, _backup());
      expect(device.keeper.bytes, isNotNull);
    });
  });
}
