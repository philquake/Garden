import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/day.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/week_progress.dart';

// Day 20003 is a Monday (weekdayOf == 1).
const monday = 20003;

Habit _h(Schedule s, Set<int> watered) => Habit.newSeed(
  id: 'a',
  name: 'a',
  flowerId: 'tulip',
  schedule: s,
  today: monday - 30,
).copyWith(wateredDays: watered);

void main() {
  test('sanity: monday', () => expect(weekdayOf(monday), 1));

  test('expected per schedule kind', () {
    expect(weekProgress(_h(const Schedule.daily(), {}), monday).expected, 7);
    expect(weekProgress(_h(Schedule.timesPerWeek(3), {}), monday).expected, 3);
    expect(weekProgress(_h(Schedule.weekday(2), {}), monday).expected, 1);
  });

  test('previous week does not count; Sunday/Monday boundary', () {
    final h = _h(const Schedule.daily(), {monday - 1, monday, monday + 2});
    expect(weekProgress(h, monday).done, 2);
    // From the Sunday of the previous week, only the Sunday itself counts.
    expect(weekProgress(h, monday - 1).done, 1);
    // Sunday of the current week still sees Monday's watering.
    expect(weekProgress(h, monday + 6).done, 2);
  });
}
