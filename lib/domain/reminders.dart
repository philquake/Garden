import 'habit.dart';

/// Keeps `ignoredReminders` equal to the consecutive scheduled misses since the
/// last watering (0 when the habit has no reminder). Returns [h] if unchanged.
Habit syncIgnoredReminders(Habit h) {
  final want = h.reminderMinutes < 0
      ? 0
      : (h.missedSinceWater < 0 ? 0 : h.missedSinceWater);
  return want == h.ignoredReminders ? h : h.copyWith(ignoredReminders: want);
}
