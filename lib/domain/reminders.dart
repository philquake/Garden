import 'dart:math';

import 'habit.dart';

/// Keeps `ignoredReminders` equal to the scheduled misses since the last
/// watering or reminder change (both 0 when the habit has no reminder).
/// Returns [h] if unchanged.
Habit syncIgnoredReminders(Habit h) {
  if (h.reminderMinutes < 0) {
    return h.ignoredReminders == 0 && h.reminderBaselineMissed == 0
        ? h
        : h.copyWith(ignoredReminders: 0, reminderBaselineMissed: 0);
  }
  final want = max(0, h.missedSinceWater - h.reminderBaselineMissed);
  return want == h.ignoredReminders ? h : h.copyWith(ignoredReminders: want);
}
