import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/stats.dart';
import 'package:garden/state/garden_controller.dart';

import '../support.dart';

void main() {
  test('add shows the habit and saves it', () async {
    final db = FakeGardenDb();
    final c = makeContainer(db: db);
    await c.read(gardenProvider.notifier).add(habit('a'));
    expect(c.read(gardenProvider).map((t) => t.config.id), ['a']);
    expect(db.configs.keys, ['a']);
  });

  test('add rejects a duplicate id and an empty name', () async {
    final c = makeContainer(habits: [tracked(habit('a'))]);
    final g = c.read(gardenProvider.notifier);
    expect(() => g.add(habit('a')), throwsStateError);
    expect(() => g.add(habit('b', name: '  ')), throwsArgumentError);
    expect(c.read(gardenProvider).length, 1);
  });

  test(
    'update changes the settings but keeps history and creation day',
    () async {
      final db = FakeGardenDb([
        tracked(habit('a', createdDay: 19990), [19995]),
      ]);
      final c = makeContainer(
        habits: [
          tracked(habit('a', createdDay: 19990), [19995]),
        ],
        db: db,
      );
      await c
          .read(gardenProvider.notifier)
          .update(
            habit(
              'a',
              name: 'Run',
              schedule: Schedule.timesPerWeek(3),
              createdDay: 5,
            ),
          );
      final t = c.read(gardenProvider).single;
      expect(t.config.name, 'Run');
      expect(t.config.schedule, Schedule.timesPerWeek(3));
      expect(t.config.createdDay, 19990);
      expect(t.log, {19995: 1});
      expect(db.configs['a']!.name, 'Run');
    },
  );

  test('remove takes the habit and its history away', () async {
    final db = FakeGardenDb([
      tracked(habit('a'), [testToday]),
      tracked(habit('b')),
    ]);
    final c = makeContainer(
      habits: [
        tracked(habit('a'), [testToday]),
        tracked(habit('b')),
      ],
      db: db,
    );
    await c.read(gardenProvider.notifier).remove('a');
    expect(c.read(gardenProvider).map((t) => t.config.id), ['b']);
    expect(db.logs.containsKey('a'), isFalse);
  });

  group('setValue', () {
    test('logs and clears a day, in memory and on disk', () async {
      final db = FakeGardenDb([tracked(habit('a'))]);
      final c = makeContainer(habits: [tracked(habit('a'))], db: db);
      final g = c.read(gardenProvider.notifier);
      await g.setValue('a', testToday - 3, 1);
      expect(c.read(gardenProvider).single.log, {testToday - 3: 1});
      expect(db.logs['a'], {testToday - 3: 1});
      await g.setValue('a', testToday - 3, null);
      expect(c.read(gardenProvider).single.log, isEmpty);
      expect(db.logs['a'], isEmpty);
    });

    test(
      'any past day since creation can be edited, not before or after',
      () async {
        final c = makeContainer(
          habits: [tracked(habit('a', createdDay: testToday - 10))],
        );
        final g = c.read(gardenProvider.notifier);
        await g.setValue('a', testToday - 10, 1);
        await g.setValue('a', testToday, 1);
        expect(() => g.setValue('a', testToday - 11, 1), throwsArgumentError);
        expect(() => g.setValue('a', testToday + 1, 1), throwsArgumentError);
        expect(() => g.setValue('a', testToday, -1), throwsArgumentError);
      },
    );

    test('editing a past day recomputes the streak', () async {
      final c = makeContainer(
        habits: [
          tracked(habit('a', createdDay: testToday - 5), [
            testToday - 5,
            testToday - 4,
            testToday - 2,
            testToday - 1,
            testToday,
          ]),
        ],
      );
      int streak() => c.read(gardenProvider).single.stats(testToday).streak;
      expect(streak(), 6); // day -3 was forgiven
      await c.read(gardenProvider.notifier).setValue('a', testToday - 4, null);
      expect(streak(), 6); // two free misses
      await c.read(gardenProvider.notifier).setValue('a', testToday - 5, null);
      // nothing logged before the gap, so nothing to forgive: run restarts
      expect(streak(), 3);
    });
  });

  group('tap', () {
    test('a yes/no habit toggles today', () async {
      final c = makeContainer(habits: [tracked(habit('a'))]);
      final g = c.read(gardenProvider.notifier);
      await g.tap('a');
      expect(c.read(gardenProvider).single.log, {testToday: 1});
      await g.tap('a');
      expect(c.read(gardenProvider).single.log, isEmpty);
    });

    test('a numeric habit adds one each tap', () async {
      final c = makeContainer(
        habits: [tracked(habit('a', goal: const Goal(target: 8)))],
      );
      final g = c.read(gardenProvider.notifier);
      await g.tap('a');
      await g.tap('a');
      expect(c.read(gardenProvider).single.log, {testToday: 2});
    });
  });

  test('a failed write rolls the garden back and rethrows', () async {
    final db = FakeGardenDb([tracked(habit('a'))]);
    final c = makeContainer(habits: [tracked(habit('a'))], db: db);
    db.failWrites = true;
    final g = c.read(gardenProvider.notifier);
    await expectLater(g.tap('a'), throwsStateError);
    expect(c.read(gardenProvider).single.log, isEmpty);
    await expectLater(g.add(habit('b')), throwsStateError);
    expect(c.read(gardenProvider).length, 1);
  });
}
