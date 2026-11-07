import 'day.dart';
import 'habit.dart';
import 'schedule.dart';

/// Waterings in the Monday-start week containing [today], against what the
/// schedule asks for in a week.
({int done, int expected}) weekProgress(Habit h, int today) {
  final week = weekIndex(today);
  final done = h.wateredDays.where((d) => weekIndex(d) == week).length;
  final expected = switch (h.schedule.kind) {
    ScheduleKind.daily => 7,
    ScheduleKind.timesPerWeek => h.schedule.value,
    ScheduleKind.weekday => 1,
  };
  return (done: done, expected: expected);
}
