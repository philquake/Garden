import 'day.dart';
import 'habit.dart';
import 'rules.dart';
import 'schedule.dart';

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.habitId,
    required this.dayIndex,
    required this.minutes,
    required this.isWarning,
    required this.isGrouped,
    required this.title,
    required this.body,
  });

  final int id;
  final String? habitId;
  final int dayIndex;
  final int minutes;
  final bool isWarning;
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
      other.isWarning == isWarning &&
      other.isGrouped == isGrouped &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    dayIndex,
    minutes,
    isWarning,
    isGrouped,
    title,
    body,
  );

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

String _flower(Habit h) => h.flowerId.toLowerCase();

List<PlannedNotification> planNotifications(
  List<Habit> habits,
  int today, {
  int horizonDays = 14,
  int nowMinutes = 0,
}) {
  final out = <PlannedNotification>[];
  final end = today + horizonDays;

  // Reminders, bucketed per day as (minutes, habit).
  for (var d = today; d < end; d++) {
    final due = <(int, Habit)>[];
    for (final h in habits) {
      if (h.lost || h.reminderMinutes < 0 || h.ignoredReminders >= 3) continue;
      if (d < h.plantedDay || h.wateredDays.contains(d)) continue;
      if (!_reminderDay(h.schedule, d)) continue;
      final m = _quiet(h.reminderMinutes);
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
            isWarning: false,
            isGrouped: true,
            title: 'Your garden',
            body: 'A few flowers would love a drink.',
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
          isWarning: false,
          isGrouped: false,
          title: 'Time for ${h.name}',
          body: 'Your ${_flower(h)} would love a drink.',
        ),
      );
    }
  }

  // Warnings: a safety net, independent of reminder pause and the daily limit.
  for (final h in habits) {
    if (h.lost) continue;
    final m = _quiet(h.reminderMinutes >= 0 ? h.reminderMinutes : 9 * 60);
    for (final w in Rules.warnDays) {
      final d = h.lastWaterDay + w;
      if (d < today || d >= end) continue;
      if (d == today && m <= nowMinutes) continue;
      out.add(
        PlannedNotification(
          id: notificationId('w:${h.id}:$w:${h.lastWaterDay}'),
          habitId: h.id,
          dayIndex: d,
          minutes: m,
          isWarning: true,
          isGrouped: false,
          title: 'Your ${_flower(h)} is waiting',
          body:
              'A fresh start is here whenever you want it. Your history stays.',
        ),
      );
    }
  }

  out.sort((a, b) {
    var c = a.dayIndex.compareTo(b.dayIndex);
    if (c == 0) c = a.minutes.compareTo(b.minutes);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return out;
}
