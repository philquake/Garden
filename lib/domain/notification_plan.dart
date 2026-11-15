import 'day.dart';
import 'habit_config.dart';
import 'schedule.dart';

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.habitId,
    required this.dayIndex,
    required this.minutes,
    required this.isGrouped,
    required this.title,
    required this.body,
  });

  final int id;
  final String? habitId;
  final int dayIndex;
  final int minutes;
  final bool isGrouped;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.id == id &&
      other.habitId == habitId &&
      other.dayIndex == dayIndex &&
      other.minutes == minutes &&
      other.isGrouped == isGrouped &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode =>
      Object.hash(id, habitId, dayIndex, minutes, isGrouped, title, body);

  @override
  String toString() => 'Planned($id, $habitId, day $dayIndex, $minutes)';
}

/// Stable positive 31-bit id (FNV-1a), unlike String.hashCode which may vary.
int notificationId(String key) {
  var h = 0x811c9dc5;
  for (final u in key.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0xFFFFFFFF;
  }
  return h & 0x7FFFFFFF;
}

int _quiet(int m) => (m >= 22 * 60 || m < 8 * 60) ? 8 * 60 : m;

bool _reminderDay(Schedule s, int d) {
  switch (s.kind) {
    case ScheduleKind.daily:
      return true;
    case ScheduleKind.weekday:
      return weekdayOf(d) == s.value;
    case ScheduleKind.timesPerWeek:
      final n = s.value;
      final offset = weekdayOf(d) - 1;
      for (var i = 0; i < n; i++) {
        if (i * 7 ~/ n == offset) return true;
      }
      return false;
  }
}

List<PlannedNotification> planNotifications(
  List<Tracked> habits,
  int today, {
  int horizonDays = 14,
  int nowMinutes = 0,
}) {
  final out = <PlannedNotification>[];
  for (var d = today; d < today + horizonDays; d++) {
    // Reminders for this day as (minutes, habit), earliest first.
    final due = <(int, HabitConfig)>[];
    for (final t in habits) {
      final h = t.config;
      final at = h.reminderMinutes;
      if (at == null || d < h.createdDay || !_reminderDay(h.schedule, d)) {
        continue;
      }
      final logged = t.log[d];
      if (logged != null && h.goal.met(logged)) continue;
      final m = _quiet(at);
      if (d == today && m <= nowMinutes) continue;
      due.add((m, h));
    }
    due.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.id.compareTo(b.$2.id);
    });
    for (var i = 0; i < due.length; i++) {
      final (m, h) = due[i];
      if (due.length >= 3 && i >= 1) {
        out.add(
          PlannedNotification(
            id: notificationId('g:$d'),
            habitId: null,
            dayIndex: d,
            minutes: due[1].$1,
            isGrouped: true,
            title: 'Your garden',
            body: 'A few habits are waiting for you today.',
          ),
        );
        break;
      }
      out.add(
        PlannedNotification(
          id: notificationId('r:${h.id}:$d'),
          habitId: h.id,
          dayIndex: d,
          minutes: m,
          isGrouped: false,
          title: 'Time for ${h.name}',
          body: 'Your ${h.flowerId.toLowerCase()} is waiting for you.',
        ),
      );
    }
  }
  return out;
}
