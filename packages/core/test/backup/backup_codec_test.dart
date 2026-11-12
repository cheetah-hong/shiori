// Backup files (설정 › 백업): format version 1 as written, read back, and
// every file a restore must refuse (K4·K5·K6). Made-up words only.
import 'dart:convert';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/backup_sample.dart';

Matcher _refused(BackupProblem problem) => throwsA(
  isA<BackupException>().having((e) => e.problem, 'problem', problem),
);

/// [document] changed by [change], then decoded.
BackupFile _decodeChanged(void Function(Map<String, Object?> doc) change) {
  final doc = sampleDocument();
  change(doc);
  return decodeBackup(bytesOf(doc));
}

void main() {
  group('format version 1 as written', () {
    test('top level, format, version, app and the columns of each table', () {
      final doc = sampleDocument();

      expect(doc.keys.toSet(), {
        'format',
        'version',
        'createdAt',
        'app',
        'words',
        'playlists',
        'playlistWords',
        'reviewCards',
        'reviewLogs',
        'settings',
      });
      expect(doc['format'], 'shiori-backup');
      expect(doc['version'], 1);
      expect(doc['app'], {'version': '1.0.0', 'build': '7', 'schema': 5});
      List<Object?> columns(String table) =>
          tableOf(doc, table)['columns']! as List<Object?>;
      expect(columns('words'), [
        'id',
        'key',
        'headword',
        'readings',
        'pos',
        'meaning',
        'exampleJa',
        'exampleKo',
        'createdAt',
        'hiddenAt',
      ]);
      expect(columns('playlists'), ['id', 'name', 'createdAt', 'position']);
      expect(columns('playlistWords'), [
        'playlistId',
        'wordId',
        'position',
        'addedAt',
      ]);
      expect(columns('reviewCards'), [
        'scope',
        'mode',
        'wordId',
        'level',
        'dueAt',
        'lastReviewedAt',
        'reviewCount',
        'lapseCount',
      ]);
      expect(columns('reviewLogs'), [
        'id',
        'scope',
        'mode',
        'wordId',
        'answer',
        'at',
        'levelBefore',
        'levelAfter',
        'retriesInSession',
      ]);
      expect(doc['settings'], {
        'study.record_mode': 'shared',
        'study.scope_mode': 'all_or_playlist',
        'study.mode': 'choice',
        'study.daily_goal': '30',
        'study.shuffle': 'off',
      });
    });

    test(
      'times are UTC microseconds; createdAt is ISO 8601 with the offset',
      () {
        final doc = sampleDocument();
        final data = sampleBackupData();

        expect(
          cell(doc, 'words', 0, 'createdAt'),
          data.words.first.createdAt.microsecondsSinceEpoch,
        );
        expect(cell(doc, 'reviewLogs', 0, 'at'), isA<int>());
        expect(cell(doc, 'words', 0, 'readings'), isA<List<Object?>>());
        expect(cell(doc, 'words', 1, 'exampleJa'), isNull);
        expect(cell(doc, 'reviewCards', 0, 'mode'), 'meaning');
        expect(cell(doc, 'reviewCards', 0, 'scope'), '');
        final created = doc['createdAt']! as String;
        expect(
          created,
          matches(RegExp(r'^2026-11-12T22:30:00(\.0+)?([+-]\d\d:\d\d|Z)$')),
        );
        expect(DateTime.parse(created).isAtSameMomentAs(backupNow), isTrue);
      },
    );

    test('written as UTF-8 JSON', () {
      final bytes = encodeBackup(sampleBackupFile());
      expect(() => jsonDecode(utf8.decode(bytes)), returnsNormally);
    });
  });

  group('read back', () {
    test('everything comes back equal', () {
      final file = sampleBackupFile();

      final back = decodeBackup(encodeBackup(file));

      expect(back.data, file.data);
      expect(back.app, file.app);
      expect(back.createdAt, file.createdAt);
      expect(back.createdAt.isUtc, isFalse);
    });

    test('a press on a word the file does not hold is kept (history)', () {
      final back = decodeBackup(encodeBackup(sampleBackupFile()));
      expect(back.data.logs.map((l) => l.wordId), contains('w-gone'));
    });

    test('an empty library reads back empty', () {
      final file = BackupFile(
        createdAt: backupNow,
        app: sampleApp,
        data: BackupData(),
      );
      final back = decodeBackup(encodeBackup(file));
      expect(back.data, BackupData());
      expect(back.data.isEmpty, isTrue);
    });
  });

  group('K6 summary and file name', () {
    test('the summary counts the rows and reads the header', () {
      final summary = decodeBackup(encodeBackup(sampleBackupFile())).summary;

      expect(summary.words, 30);
      expect(summary.playlists, 3);
      expect(summary.presses, 21);
      expect(summary.createdAt, backupNow);
      expect(summary.appVersion, '1.0.0');
    });

    test('rows added by hand are counted, not taken from anywhere else', () {
      final file = _decodeChanged((doc) {
        rowsOf(doc, 'playlists').removeLast();
        rowsOf(
          doc,
          'playlistWords',
        ).removeWhere((r) => (r! as List<Object?>)[0] == 'pl-sample-2');
      });
      expect(file.summary.playlists, 2);
      expect(file.summary.words, 30);
    });

    test('file name from the time on the device', () {
      expect(backupFileName(backupNow), 'shiori-backup-20261112-2230.json');
      expect(
        backupFileName(DateTime(2026, 1, 2, 3, 4, 59)),
        'shiori-backup-20260102-0304.json',
      );
    });
  });

  group('K4 refused files', () {
    test('empty', () {
      expect(() => decodeBackup(const []), _refused(BackupProblem.empty));
      expect(
        () => decodeBackup(utf8.encode('  \n\t')),
        _refused(BackupProblem.empty),
      );
    });

    test('over the size limit; at the limit it is read', () {
      final bytes = encodeBackup(sampleBackupFile());
      expect(
        () => decodeBackup(bytes, maxBytes: bytes.length - 1),
        _refused(BackupProblem.tooLarge),
      );
      expect(
        decodeBackup(bytes, maxBytes: bytes.length).data,
        sampleBackupData(),
      );
    });

    test('an export over the limit is not made', () {
      expect(
        () => encodeBackup(sampleBackupFile(), maxBytes: 100),
        _refused(BackupProblem.tooLarge),
      );
    });

    test('not JSON: cut short, not UTF-8, gzip bytes, an array at the top', () {
      final whole = utf8.decode(encodeBackup(sampleBackupFile()));
      for (final bytes in [
        utf8.encode(whole.substring(0, whole.length ~/ 2)),
        [0xff, 0xfe, 0x7b, 0x7d],
        [0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03],
        utf8.encode('[]'),
        utf8.encode('"shiori-backup"'),
      ]) {
        expect(
          () => decodeBackup(bytes),
          _refused(BackupProblem.notJson),
          reason: '$bytes',
        );
      }
    });

    test('not a Shiori backup: another format, or none', () {
      expect(
        () => _decodeChanged((doc) => doc['format'] = 'other-app'),
        _refused(BackupProblem.notBackup),
      );
      expect(
        () => _decodeChanged((doc) => doc.remove('format')),
        _refused(BackupProblem.notBackup),
      );
      expect(
        () => decodeBackup(utf8.encode('{"words": []}')),
        _refused(BackupProblem.notBackup),
      );
    });

    test('version missing, not a whole number, or below 1', () {
      for (final version in [null, '1', 1.0, 0, -1]) {
        expect(
          () => _decodeChanged((doc) {
            if (version == null) {
              doc.remove('version');
            } else {
              doc['version'] = version;
            }
          }),
          _refused(BackupProblem.invalid),
          reason: '$version',
        );
      }
    });

    test('a newer version is refused before its tables are looked at', () {
      expect(
        () => _decodeChanged((doc) => doc['version'] = 2),
        _refused(BackupProblem.newerVersion),
      );
      expect(
        () => _decodeChanged((doc) {
          doc['version'] = 3;
          doc['words'] = 'a table this build cannot read';
          doc['somethingNew'] = true;
        }),
        _refused(BackupProblem.newerVersion),
      );
    });

    group('invalid', () {
      void refuses(String why, void Function(Map<String, Object?> doc) change) {
        test(why, () {
          expect(() => _decodeChanged(change), _refused(BackupProblem.invalid));
        });
      }

      refuses('an unknown key at the top', (doc) => doc['extra'] = 1);
      refuses('a table missing', (doc) => doc.remove('reviewLogs'));
      refuses('settings missing', (doc) => doc.remove('settings'));
      refuses('app missing', (doc) => doc.remove('app'));
      refuses('app version not text', (doc) {
        (doc['app']! as Map<String, Object?>)['version'] = 1;
      });
      refuses('createdAt not a time', (doc) => doc['createdAt'] = 'yesterday');
      refuses('a table that is not columns and rows', (doc) {
        doc['playlists'] = <Object?>[];
      });
      refuses('an unknown column', (doc) {
        final table = tableOf(doc, 'playlists');
        table['columns'] = [...table['columns']! as List<Object?>, 'color'];
        for (final row in rowsOf(doc, 'playlists')) {
          (row! as List<Object?>).add('blue');
        }
      });
      refuses('columns in another order', (doc) {
        tableOf(doc, 'playlists')['columns'] = [
          'name',
          'id',
          'createdAt',
          'position',
        ];
      });
      refuses('a row shorter than the columns', (doc) {
        (rowsOf(doc, 'words').first! as List<Object?>).removeLast();
      });
      refuses('a row that is not a list', (doc) {
        rowsOf(doc, 'words')[0] = {'id': 'w-sample-0'};
      });
      refuses('text where a number goes', (doc) {
        setCell(doc, 'reviewCards', 0, 'level', '2');
      });
      refuses('a fraction where a whole number goes', (doc) {
        setCell(doc, 'reviewCards', 0, 'level', 2.0);
      });
      refuses('a number where text goes', (doc) {
        setCell(doc, 'words', 0, 'meaning', 3);
      });
      refuses('null in a column that needs a value', (doc) {
        setCell(doc, 'words', 0, 'headword', null);
      });
      refuses('readings not a list of text', (doc) {
        setCell(doc, 'words', 0, 'readings', [1]);
      });
      refuses('readings as text', (doc) {
        setCell(doc, 'words', 0, 'readings', 'かざぐるま');
      });
      refuses('an empty id', (doc) => setCell(doc, 'words', 0, 'id', ''));
      refuses('an empty key', (doc) => setCell(doc, 'words', 0, 'key', ''));
      refuses('a level below 0', (doc) {
        setCell(doc, 'reviewCards', 0, 'level', -1);
      });
      refuses('a level above the last step', (doc) {
        setCell(doc, 'reviewCards', 0, 'level', 5);
      });
      refuses('a press level above the last step', (doc) {
        setCell(doc, 'reviewLogs', 0, 'levelAfter', 5);
      });
      refuses('a negative count', (doc) {
        setCell(doc, 'reviewCards', 0, 'reviewCount', -1);
      });
      refuses('a negative position', (doc) {
        setCell(doc, 'playlists', 0, 'position', -1);
      });
      refuses('a time before 2000', (doc) {
        setCell(
          doc,
          'words',
          0,
          'createdAt',
          DateTime.utc(1999, 12, 31).microsecondsSinceEpoch,
        );
      });
      refuses('a time from 2200 on', (doc) {
        setCell(
          doc,
          'reviewLogs',
          0,
          'at',
          DateTime.utc(2200).microsecondsSinceEpoch,
        );
      });
      refuses('a playlist name of spaces only', (doc) {
        setCell(doc, 'playlists', 0, 'name', '   ');
      });
      refuses('an example without its translation', (doc) {
        setCell(doc, 'words', 0, 'exampleKo', null);
      });
      refuses('an unknown study mode', (doc) {
        setCell(doc, 'reviewCards', 0, 'mode', 'speaking');
      });
      refuses('an unknown answer', (doc) {
        setCell(doc, 'reviewLogs', 0, 'answer', 'maybe');
      });
      refuses('an unknown part of speech', (doc) {
        setCell(doc, 'words', 1, 'pos', 'pronoun');
      });
      refuses('a scope that is not one', (doc) {
        setCell(doc, 'reviewCards', 0, 'scope', 'x:1');
      });
      refuses('a press id that is not a whole number', (doc) {
        setCell(doc, 'reviewLogs', 0, 'id', 'one');
      });
      refuses('a press id below 1', (doc) {
        setCell(doc, 'reviewLogs', 0, 'id', 0);
      });
      refuses('an unknown study option', (doc) {
        (doc['settings']! as Map<String, Object?>)['study.font'] = 'large';
      });
      refuses('a value a study option does not take', (doc) {
        (doc['settings']! as Map<String, Object?>)['study.daily_goal'] = '15';
      });
      refuses('a study option that is not text', (doc) {
        (doc['settings']! as Map<String, Object?>)['study.daily_goal'] = 20;
      });
      refuses('text longer than 10,000 characters', (doc) {
        setCell(doc, 'words', 0, 'meaning', 'あ' * 10001);
      });
    });

    group('duplicate', () {
      void refuses(String why, void Function(Map<String, Object?> doc) change) {
        test(why, () {
          expect(
            () => _decodeChanged(change),
            _refused(BackupProblem.duplicate),
          );
        });
      }

      refuses('two words with one id', (doc) {
        setCell(doc, 'words', 1, 'id', 'w-sample-0');
      });
      refuses('two words with one key', (doc) {
        setCell(doc, 'words', 1, 'key', cell(doc, 'words', 0, 'key'));
      });
      refuses('two playlists with one id', (doc) {
        setCell(doc, 'playlists', 1, 'id', 'pl-sample-0');
      });
      refuses('a word twice in one playlist', (doc) {
        final rows = rowsOf(doc, 'playlistWords');
        rows.add([...(rows.first! as List<Object?>)]);
      });
      refuses('two cards of one word in one mode', (doc) {
        final rows = rowsOf(doc, 'reviewCards');
        rows.add([...(rows.first! as List<Object?>)]);
      });
      refuses('two presses with one id', (doc) {
        setCell(doc, 'reviewLogs', 1, 'id', 1);
      });
    });

    group('dangling reference', () {
      void refuses(String why, void Function(Map<String, Object?> doc) change) {
        test(why, () {
          expect(
            () => _decodeChanged(change),
            _refused(BackupProblem.danglingReference),
          );
        });
      }

      refuses('a card of a word the file does not hold', (doc) {
        setCell(doc, 'reviewCards', 0, 'wordId', 'w-missing');
      });
      refuses('a playlist entry of a word the file does not hold', (doc) {
        setCell(doc, 'playlistWords', 0, 'wordId', 'w-missing');
      });
      refuses('a playlist entry of a playlist the file does not hold', (doc) {
        setCell(doc, 'playlistWords', 0, 'playlistId', 'pl-missing');
      });
    });
  });

  group('K5 older versions', () {
    test('version 1 is the first: no step to upgrade from', () {
      expect(backupVersion, 1);
      expect(backupUpgrades, isEmpty);
    });

    test('version 1 is read as it is', () {
      final doc = sampleDocument();
      expect(doc['version'], 1);
      expect(decodeBackup(bytesOf(doc)).data, sampleBackupData());
    });

    for (final table in ['reviewCards', 'reviewLogs']) {
      test('$table without the study mode column (schema v5) is refused', () {
        expect(
          () => _decodeChanged((doc) {
            final t = tableOf(doc, table);
            final columns = (t['columns']! as List).cast<String>();
            final at = columns.indexOf('mode');
            t['columns'] = [...columns]..removeAt(at);
            for (final row in rowsOf(doc, table)) {
              (row! as List<Object?>).removeAt(at);
            }
          }),
          _refused(BackupProblem.invalid),
        );
      });
    }
  });
}
