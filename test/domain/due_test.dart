import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/due.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';

// Day 102 is a Monday; 102..108 is one Monday-start week.
Habit _h(Schedule s, {Set<int> watered = const {}, bool lost = false}) =>
    Habit.newSeed(
      id: 'a',
      name: 'Read',
      flowerId: 'tulip',
      schedule: s,
      today: 95,
    ).copyWith(wateredDays: watered, lost: lost);

void main() {
  test('a lost habit never needs water', () {
    expect(needsWaterToday(_h(const Schedule.daily(), lost: true), 102), false);
  });

  test('daily: due until watered today', () {
    expect(needsWaterToday(_h(const Schedule.daily()), 102), true);
    expect(
      needsWaterToday(_h(const Schedule.daily(), watered: {102}), 102),
      false,
    );
  });

  test('weekday: due only on its day, until watered', () {
    final monday = Schedule.weekday(1);
    expect(needsWaterToday(_h(monday), 102), true);
    expect(needsWaterToday(_h(monday), 103), false);
    expect(needsWaterToday(_h(monday, watered: {102}), 102), false);
  });

  test('times a week: due while this week is under target', () {
    final three = Schedule.timesPerWeek(3);
    expect(needsWaterToday(_h(three, watered: {102, 103}), 104), true);
    expect(needsWaterToday(_h(three, watered: {102, 103, 104}), 105), false);
    // Last week's waterings do not count.
    expect(needsWaterToday(_h(three, watered: {99, 100, 101}), 102), true);
    // Under target but already watered today.
    expect(needsWaterToday(_h(three, watered: {102}), 102), false);
  });
}
