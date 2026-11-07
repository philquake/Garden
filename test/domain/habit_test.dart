import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';

void main() {
  test('newSeed defaults', () {
    final h = Habit.newSeed(
      id: 'a',
      name: 'Read',
      flowerId: 'tulip',
      schedule: const Schedule.daily(),
      today: 12,
    );
    expect(h.wateredDays, isEmpty);
    expect(h.plantedDay, 12);
    expect(h.lastWaterDay, 12);
    expect(h.evaluatedDay, 12);
    expect(h.plantingNumber, 1);
    expect(h.reminderMinutes, -1);
    expect(h.lost, isFalse);
  });

  test('JSON round-trip through a string', () {
    final h = Habit.newSeed(
      id: 'a',
      name: 'Run',
      flowerId: 'poppy',
      schedule: Schedule.timesPerWeek(3),
      today: 5,
      reminderMinutes: 480,
    ).copyWith(wateredDays: {9, 5, 7}, declineStep: 2, lost: true);
    final json = h.toJson();
    expect(json['wateredDays'], [5, 7, 9]);
    final back = Habit.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
    expect(back.toJson(), json);
    expect(back.schedule, Schedule.timesPerWeek(3));
  });
}
