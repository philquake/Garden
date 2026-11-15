import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garden/data/garden_db.dart';
import 'package:garden/domain/habit_config.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/stats.dart';
import 'package:garden/export/backup.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support.dart';

List<Tracked> sample() => [
  tracked(habit('a', name: 'Café ☕', flower: 'daisy'), [
    testToday - 3,
    testToday - 1,
  ]),
  Tracked(
    habit(
      'w',
      name: 'Water, "daily"',
      goal: const Goal(target: 2.5, atMost: true),
      unit: 'l',
      schedule: Schedule.timesPerWeek(4),
      reminder: null,
    ),
    {testToday - 2: 1.5, testToday: 3},
  ),
  tracked(habit('x', schedule: Schedule.weekday(5), reminder: 1439)),
];

/// A backup file around [payload], with a correct checksum.
String envelope(Map<String, Object?> payload) {
  final data = jsonEncode(payload);
  return jsonEncode({
    'garden_backup': backupVersion,
    'checksum': backupChecksum(data),
    'data': data,
  });
}

Map<String, Object?> goodHabit([Map<String, Object?> over = const {}]) => {
  'id': 'a',
  'name': 'Read',
  'flowerId': 'tulip',
  'schedule': {'kind': 'daily'},
  'target': 1,
  'atMost': false,
  'unit': '',
  'createdDay': 100,
  'reminderMinutes': null,
  'log': {'100': 1},
  ...over,
};

Matcher rejects(String part) => throwsA(
  isA<BackupException>().having((e) => e.message, 'message', contains(part)),
);

void main() {
  group('round trip', () {
    test('restores every habit, setting and logged day exactly', () {
      final back = decodeBackup(encodeBackup(sample(), testToday));
      expect(back.length, 3);
      for (var i = 0; i < 3; i++) {
        final a = sample()[i], b = back[i];
        expect(b.config.id, a.config.id);
        expect(b.config.name, a.config.name);
        expect(b.config.flowerId, a.config.flowerId);
        expect(b.config.schedule, a.config.schedule);
        expect(b.config.goal.target, a.config.goal.target);
        expect(b.config.goal.atMost, a.config.goal.atMost);
        expect(b.config.unit, a.config.unit);
        expect(b.config.createdDay, a.config.createdDay);
        expect(b.config.reminderMinutes, a.config.reminderMinutes);
        expect(b.log, a.log);
      }
    });

    test('an empty garden is a valid backup', () {
      expect(decodeBackup(encodeBackup(const [], testToday)), isEmpty);
    });

    test('streaks are identical after a round trip', () {
      final before = sample().first.stats(testToday);
      final after = decodeBackup(encodeBackup(sample(), testToday)).first
          .stats(testToday);
      expect(after.streak, before.streak);
      expect(after.score, before.score);
    });
  });

  group('damaged or foreign files', () {
    test('not json, not a backup, wrong shape', () {
      for (final bad in [
        '',
        'hello',
        '[]',
        '{}',
        '{"garden_backup":"x"}',
        'null',
      ]) {
        expect(
          () => decodeBackup(bad),
          rejects('not a Garden backup'),
          reason: bad,
        );
      }
    });

    test('a file cut short is rejected, not half restored', () {
      final text = encodeBackup(sample(), testToday);
      expect(
        () => decodeBackup(text.substring(0, text.length - 20)),
        throwsA(isA<BackupException>()),
      );
    });

    test('an edited file fails the checksum', () {
      final text = encodeBackup(
        sample(),
        testToday,
      ).replaceFirst('Water', 'Wafer');
      expect(() => decodeBackup(text), rejects('damaged'));
    });

    test('a newer backup version asks for an update', () {
      final env = jsonDecode(encodeBackup(const [], testToday)) as Map;
      env['garden_backup'] = backupVersion + 1;
      expect(() => decodeBackup(jsonEncode(env)), rejects('newer version'));
    });
  });

  group('validation (with a correct checksum)', () {
    String file(List<Object?> habits) =>
        envelope({'version': 1, 'exportedDay': 1, 'habits': habits});

    test('accepts a minimal good habit', () {
      expect(decodeBackup(file([goodHabit()])).single.config.name, 'Read');
    });

    test('rejects a missing field', () {
      final h = goodHabit()..remove('unit');
      expect(() => decodeBackup(file([h])), rejects('incomplete'));
    });

    test('rejects a duplicate id', () {
      expect(
        () => decodeBackup(file([goodHabit(), goodHabit()])),
        rejects('twice'),
      );
    });

    test('rejects an empty name or id', () {
      expect(
        () => decodeBackup(
          file([
            goodHabit({'name': '  '}),
          ]),
        ),
        rejects('no name'),
      );
      expect(
        () => decodeBackup(
          file([
            goodHabit({'id': ''}),
          ]),
        ),
        rejects('no name'),
      );
    });

    test('rejects a schedule it does not know', () {
      expect(
        () => decodeBackup(
          file([
            goodHabit({
              'schedule': {'kind': 'monthly'},
            }),
          ]),
        ),
        rejects('schedule'),
      );
      expect(
        () => decodeBackup(
          file([
            goodHabit({
              'schedule': {'kind': 'timesPerWeek', 'n': 9},
            }),
          ]),
        ),
        rejects('schedule'),
      );
    });

    test('rejects bad numbers, dates and reminder times', () {
      expect(
        () => decodeBackup(
          file([
            goodHabit({'target': -1}),
          ]),
        ),
        rejects('bad number'),
      );
      expect(
        () => decodeBackup(
          file([
            goodHabit({'target': 0}),
          ]),
        ),
        rejects('zero'),
      );
      expect(
        () => decodeBackup(
          file([
            goodHabit({
              'log': {'x': 1},
            }),
          ]),
        ),
        rejects('bad date'),
      );
      expect(
        () => decodeBackup(
          file([
            goodHabit({
              'log': {'100': -3},
            }),
          ]),
        ),
        rejects('bad number'),
      );
      expect(
        () => decodeBackup(
          file([
            goodHabit({'reminderMinutes': 2000}),
          ]),
        ),
        rejects('reminder'),
      );
      expect(
        () => decodeBackup(
          file([
            goodHabit({'createdDay': 'soon'}),
          ]),
        ),
        rejects('incomplete'),
      );
    });

    test('a bad habit anywhere rejects the whole file', () {
      expect(
        () => decodeBackup(
          file([
            goodHabit(),
            goodHabit({'id': 'b', 'name': ''}),
          ]),
        ),
        throwsA(isA<BackupException>()),
      );
    });

    test('an at-most goal of zero is allowed', () {
      final h = goodHabit({'target': 0, 'atMost': true});
      expect(decodeBackup(file([h])).single.config.goal.atMost, isTrue);
    });
  });

  group('restoring', () {
    test(
      'the controller swaps the whole garden, in memory and on disk',
      () async {
        final db = FakeGardenDb([
          tracked(habit('old'), [testToday]),
        ]);
        final c = makeContainer(
          habits: [
            tracked(habit('old'), [testToday]),
          ],
          db: db,
        );
        await c.read(gardenProvider.notifier).replaceAll(sample());
        expect(c.read(gardenProvider).map((t) => t.config.id), ['a', 'w', 'x']);
        expect(db.configs.keys, ['a', 'w', 'x']);
        expect(db.logs['w'], {testToday - 2: 1.5, testToday: 3});
        expect(db.logs.containsKey('old'), isFalse);
      },
    );

    test('a failed write puts the old garden back', () async {
      final db = FakeGardenDb([tracked(habit('old'))])..failWrites = true;
      final c = makeContainer(habits: [tracked(habit('old'))], db: db);
      await expectLater(
        c.read(gardenProvider.notifier).replaceAll(sample()),
        throwsStateError,
      );
      expect(c.read(gardenProvider).single.config.id, 'old');
    });

    test(
      'the real database replaces atomically and rolls back on error',
      () async {
        sqfliteFfiInit();
        final db = await GardenDb.open(
          databaseFactoryFfi,
          inMemoryDatabasePath,
        );
        addTearDown(db.close);
        await db.saveHabit(habit('old'));
        await db.setValue('old', testToday, 1);

        await db.replaceAll(sample());
        expect((await db.habits()).map((h) => h.id), ['a', 'w', 'x']);
        expect(await db.log('w'), {testToday - 2: 1.5, testToday: 3});
        expect(await db.log('old'), isEmpty);

        // The same id twice makes the second insert fail: nothing must change.
        await expectLater(
          db.replaceAll([tracked(habit('p')), tracked(habit('p'))]),
          throwsA(anything),
        );
        expect((await db.habits()).map((h) => h.id), ['a', 'w', 'x']);
        expect(await db.log('w'), {testToday - 2: 1.5, testToday: 3});
      },
    );
  });
}
