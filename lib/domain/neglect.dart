import 'dart:math';

import 'day.dart';
import 'habit.dart';
import 'rules.dart';
import 'schedule.dart';

int daysSinceWater(Habit h, int today) => today - h.lastWaterDay;

/// Petals dropped so far; only while in petal loss (declineStep 3).
int petalsLost(Habit h) =>
    h.declineStep == 3 ? max(0, h.missedSinceWater - Rules.petalMissed) : 0;

/// Rolls neglect forward over every closed day in [evaluatedDay, today).
/// A day only counts once it is over, and thresholds use days-since-water at
/// the end of each day, so one big jump equals many small advances.
Habit advance(Habit h, int today) {
  if (today <= h.evaluatedDay) return h;
  var missed = h.missedSinceWater;
  var step = h.declineStep;
  var lost = h.lost;
  for (var d = h.evaluatedDay; d < today; d++) {
    if (d <= h.lastWaterDay || h.wateredDays.contains(d)) continue;
    missed += _missesOn(h, d);
    final ds = d + 1 - h.lastWaterDay;
    final target = missed >= Rules.petalMissed && ds >= Rules.petalDays
        ? 3
        : missed >= Rules.wiltMissed && ds >= Rules.wiltDays
            ? 2
            : missed >= 1
                ? 1
                : 0;
    step = max(step, target);
    if (ds >= Rules.lostDays) lost = true;
  }
  if (daysSinceWater(h, today) >= Rules.lostDays) lost = true;
  return h.copyWith(
    missedSinceWater: missed,
    declineStep: step,
    lost: lost,
    evaluatedDay: today,
  );
}

/// Scheduled occurrences missed on closed day [d] (not watered).
int _missesOn(Habit h, int d) {
  final s = h.schedule;
  switch (s.kind) {
    case ScheduleKind.daily:
      return 1;
    case ScheduleKind.weekday:
      return weekdayOf(d) == s.value ? 1 : 0;
    case ScheduleKind.timesPerWeek:
      if (weekdayOf(d) != 7) return 0;
      final weekStart = d - 6; // Monday of this week
      final available = d - max<int>(h.plantedDay, weekStart) + 1;
      final expected = min(s.value, available);
      final done =
          h.wateredDays.where((w) => w >= weekStart && w <= d).length;
      return max(0, expected - done);
  }
}
