import 'dart:math';

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
  final a = advance(h, today);
  if (a.lost) throw StateError('Habit is lost; replant first');
  if (a.wateredDays.contains(day)) return a;
  return a.copyWith(
    wateredDays: {...a.wateredDays, day},
    plantingWaterings: a.plantingWaterings + 1,
    missedSinceWater: 0,
    reminderBaselineMissed: 0,
    declineStep: max(0, a.declineStep - 1),
    lastWaterDay: max(a.lastWaterDay, day),
  );
}

/// Settles misses under the old schedule, then swaps the schedule.
Habit editSchedule(Habit h, Schedule s, int today) =>
    _settle(h, today).copyWith(schedule: s);

// Advances, then pins evaluatedDay so a backward clock never rewinds state.
Habit _settle(Habit h, int today) {
  final a = advance(h, today);
  return a.copyWith(evaluatedDay: max(a.evaluatedDay, today));
}

/// Clears decline from petal loss; keeps stage and history.
Habit freshStart(Habit h, int today) {
  final a = advance(h, today);
  if (a.lost || a.declineStep < 3) {
    throw StateError('Fresh start needs a flower in petal loss');
  }
  return a.copyWith(
    declineStep: 0,
    missedSinceWater: 0,
    reminderBaselineMissed: 0,
    lastWaterDay: max(a.lastWaterDay, today),
    evaluatedDay: max(a.evaluatedDay, today),
    lost: false,
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
    lastWaterDay: max(a.lastWaterDay, today),
    evaluatedDay: max(a.evaluatedDay, today),
    lost: false,
    plantingNumber: a.plantingNumber + 1,
  );
}
