import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/growth.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';

Habit seed(Schedule s, int waterings) => Habit.newSeed(
      id: 'h',
      name: 'Habit',
      flowerId: 'rose',
      schedule: s,
      today: 0,
    ).copyWith(plantingWaterings: waterings);

void main() {
  test('daily habit with 0 waterings is stage 0', () {
    expect(growthStage(seed(const Schedule.daily(), 0)), 0);
  });

  test('daily habit with 7 waterings is stage 1', () {
    expect(growthStage(seed(const Schedule.daily(), 7)), 1);
  });

  test('daily habit with 28 waterings is stage 4', () {
    expect(growthStage(seed(const Schedule.daily(), 28)), 4);
  });

  test('weekday habit with 4 waterings is stage 4', () {
    expect(growthStage(seed(Schedule.weekday(1), 4)), 4);
  });

  test('progress beyond full stays at 4', () {
    expect(growthStage(seed(const Schedule.daily(), 100)), 4);
  });
}
