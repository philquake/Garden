import 'day.dart';
import 'habit.dart';

/// Waterings in the Monday-start week containing [today], against what the
/// schedule asks for in a week.
({int done, int expected}) weekProgress(Habit h, int today) {
  final week = weekIndex(today);
  final done = h.wateredDays.where((d) => weekIndex(d) == week).length;
  return (done: done, expected: h.schedule.perWeek);
}
