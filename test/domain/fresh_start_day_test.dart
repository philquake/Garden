import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/actions.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/neglect.dart';
import 'package:garden/domain/schedule.dart';

Habit _seed() => Habit.newSeed(
  id: 'a',
  name: 'Read',
  flowerId: 'tulip',
  schedule: const Schedule.daily(),
  today: 100,
);

void main() {
  // Day 109: nine days dry, so petal loss and a fresh start is allowed.
  final petalLoss = advance(_seed(), 109);

  test('a new seed has no fresh-start day', () {
    expect(_seed().freshStartDay, -1);
  });

  test('gardens saved before the field existed load as -1', () {
    final j = _seed().toJson()..remove('freshStartDay');
    expect(Habit.fromJson(j).freshStartDay, -1);
  });

  test('round-trips through JSON', () {
    final h = _seed().copyWith(freshStartDay: 20764);
    final back = Habit.fromJson(
      jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>,
    );
    expect(back.freshStartDay, 20764);
  });

  test('freshStart records the day', () {
    expect(freshStart(petalLoss, 109).freshStartDay, 109);
  });

  test('a new watering clears it, back-fill included', () {
    final f = freshStart(petalLoss, 109);
    expect(water(f, 109).freshStartDay, -1);
    expect(water(f, 109, forDay: 108).freshStartDay, -1);
  });

  test('watering an already-watered day leaves it alone', () {
    final f = freshStart(petalLoss, 109).copyWith(wateredDays: {109});
    expect(water(f, 109).freshStartDay, 109);
  });

  test('replant clears it', () {
    final lost = advance(_seed(), 130).copyWith(freshStartDay: 5);
    expect(lost.lost, isTrue);
    expect(replant(lost, 130).freshStartDay, -1);
  });
}
