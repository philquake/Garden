import 'dart:math';

import 'day.dart';
import 'habit.dart';
import 'rules.dart';
import 'schedule.dart';

int daysSinceWater(Habit h, int today) => today - h.lastWaterDay;

/// Long enough without water for the gentle loss warnings (day 14 onwards).
bool isWaiting(Habit h, int today) =>
    !h.lost && daysSinceWater(h, today) >= Rules.warnDays.first;

/// A fresh start is offered in petal loss or once the warnings begin.
bool canFreshStart(Habit h, int today) =>
    !h.lost && (h.declineStep >= 3 || isWaiting(h, today));

/// Rolls neglect forward over every closed day in [evaluatedDay, today).
/// A day only counts once it is over, and thresholds use days-since-water at
/// the end of each day, so one big jump equals many small advances.
Habit advance(Habit h, int today) {
  if (today <= h.evaluatedDay) return h;
  var missed = h.missedSinceWater;
  var step = h.declineStep;
  var lost = h.lost;
  for (var d = h.evaluatedDay; d < today; d++) {
    // A watered Sunday still closes a times-a-week week (a quota check, not a
    // missed day); the planting day stays a grace day.
    final weekEnd =
        h.schedule.kind == ScheduleKind.timesPerWeek &&
        weekdayOf(d) == 7 &&
        d > h.plantedDay;
    if ((d <= h.lastWaterDay || h.wateredDays.contains(d)) && !weekEnd) {
      continue;
    }
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
      final done = h.wateredDays.where((w) => w >= weekStart && w <= d).length;
      return max(0, expected - done);
  }
}
