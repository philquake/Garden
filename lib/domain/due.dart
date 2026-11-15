import 'day.dart';
import 'habit.dart';
import 'schedule.dart';

/// Whether [h] still wants water on [today]: scheduled for today (or, for a
/// times-a-week habit, under this week's target) and not yet watered today.
bool needsWaterToday(Habit h, int today) {
  if (h.lost || h.wateredDays.contains(today)) return false;
  final s = h.schedule;
  switch (s.kind) {
    case ScheduleKind.daily:
      return true;
    case ScheduleKind.weekday:
      return weekdayOf(today) == s.value;
    case ScheduleKind.timesPerWeek:
      final week = weekIndex(today);
      return h.wateredDays.where((d) => weekIndex(d) == week).length < s.value;
  }
}
