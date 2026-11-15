import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit_config.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/stats.dart';
import 'package:garden/widget/widget_data.dart';

const today = 20000;

HabitConfig habit(String id, {String flower = 'rose', Goal? goal}) =>
    HabitConfig(
      id: id,
      name: 'Habit $id',
      flowerId: flower,
      schedule: const Schedule.daily(),
      goal: goal ?? const Goal(),
      createdDay: today - 10,
    );

void main() {
  test('tiles keep the habit order and its chosen flower', () {
    final tiles = tilesOf([
      Tracked(habit('b', flower: 'tulip'), const {}),
      Tracked(habit('a'), const {}),
    ], today);
    expect([for (final t in tiles) t.id], ['b', 'a']);
    expect([for (final t in tiles) t.flower], ['tulip', 'rose']);
  });

  test('done only when today meets the goal', () {
    final tiles = tilesOf([
      Tracked(habit('yes'), {today: 1}),
      Tracked(habit('no'), {today - 1: 1}),
      Tracked(habit('part', goal: const Goal(target: 3)), {today: 2}),
      Tracked(habit('full', goal: const Goal(target: 3)), {today: 3}),
    ], today);
    expect([for (final t in tiles) t.done], [true, false, false, true]);
  });

  test('a new habit shows the seed stage; a long one grows', () {
    final young = tilesOf([Tracked(habit('y'), const {})], today).single;
    expect(young.stage, 0);
    final log = {for (var d = today - 70; d <= today; d++) d: 1};
    final old = HabitConfig(
      id: 'o',
      name: 'o',
      flowerId: 'rose',
      schedule: const Schedule.daily(),
      goal: const Goal(),
      createdDay: today - 70,
    );
    expect(tilesOf([Tracked(old, log)], today).single.stage, 4);
  });

  test('snapshot json carries the day and asset names', () {
    final j = jsonDecode(snapshotJson([Tracked(habit('a'), {today: 1})], today))
        as Map<String, dynamic>;
    expect(j['day'], today);
    final tile = (j['tiles'] as List).single as Map<String, dynamic>;
    expect(tile['asset'], 'rose_0');
    expect(tile['done'], true);
  });

  test('tapValue toggles yes/no and counts up otherwise', () {
    final yn = habit('a');
    expect(tapValue(yn, null), 1);
    expect(tapValue(yn, 1), isNull);
    final count = habit('b', goal: const Goal(target: 8));
    expect(tapValue(count, null), 1);
    expect(tapValue(count, 4), 5);
  });
}
