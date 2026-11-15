import 'dart:math';

import 'day.dart';
import 'habit.dart';
import 'neglect.dart';
import 'rules.dart';
import 'schedule.dart';

/// Waters [h] for [forDay] (default [today]); up to Rules.backfillDays back.
Habit water(Habit h, int today, {int? forDay}) {
  final day = forDay ?? today;
  if (day > today || day < today - Rules.backfillDays) {
    throw ArgumentError.value(forDay, 'forDay', 'outside back-fill window');
  }
  final already = h.wateredDays.contains(day);
  // A late log of an earlier day counts before the roll-forward, so it can
  // still save a flower that would otherwise be lost today.
  final base = already || day == today
      ? h
      : h.copyWith(
          wateredDays: {...h.wateredDays, day},
          lastWaterDay: max(h.lastWaterDay, day),
        );
  final a = advance(base, today);
  if (a.lost) throw StateError('Habit is lost; replant first');
  if (already) return a;
  // Growth credit stops at the schedule's weekly target, so extra waterings
  // keep the flower healthy without making it bloom faster than four weeks.
  final week = weekIndex(day);
  final inWeek = h.wateredDays.where((d) => weekIndex(d) == week).length;
  return a.copyWith(
    wateredDays: {...a.wateredDays, day},
    plantingWaterings:
        a.plantingWaterings + (inWeek < a.schedule.perWeek ? 1 : 0),
    missedSinceWater: 0,
    reminderBaselineMissed: 0,
    declineStep: max(0, a.declineStep - 1),
    lastWaterDay: max(a.lastWaterDay, day),
    freshStartDay: -1,
  );
}

/// Settles misses under the old schedule, then swaps the schedule. Waterings
/// are rescaled to the new target so the growth stage does not jump.
Habit editSchedule(Habit h, Schedule s, int today) {
  final a = _settle(h, today);
  return a.copyWith(
    schedule: s,
    plantingWaterings:
        a.plantingWaterings * s.perFourWeeks ~/ a.schedule.perFourWeeks,
  );
}

// Advances, then pins evaluatedDay so a backward clock never rewinds state.
Habit _settle(Habit h, int today) {
  final a = advance(h, today);
  return a.copyWith(evaluatedDay: max(a.evaluatedDay, today));
}

/// Clears decline (petal loss, or 14+ days dry); keeps stage and history.
// Both days are set to today (not max): every counter is reset here, and a
// stale future day from a wrong clock would otherwise freeze the habit.
Habit freshStart(Habit h, int today) {
  final a = advance(h, today);
  if (!canFreshStart(a, today)) {
    throw StateError('Fresh start needs petal loss or 14 days without water');
  }
  return a.copyWith(
    declineStep: 0,
    missedSinceWater: 0,
    reminderBaselineMissed: 0,
    lastWaterDay: today,
    evaluatedDay: today,
    lost: false,
    freshStartDay: today,
  );
}

/// Starts over after a lost flower; watering history is kept.
Habit replant(Habit h, int today) {
  final a = advance(h, today);
  if (!a.lost) throw StateError('Only a lost habit can be replanted');
  return a.copyWith(
    plantingWaterings: 0,
    declineStep: 0,
    missedSinceWater: 0,
    reminderBaselineMissed: 0,
    lastWaterDay: today,
    evaluatedDay: today,
    lost: false,
    plantingNumber: a.plantingNumber + 1,
    freshStartDay: -1,
  );
}
