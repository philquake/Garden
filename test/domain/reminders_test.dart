import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/reminders.dart';
import 'package:garden/domain/schedule.dart';

Habit _h({int reminder = -1, int missed = 0, int ignored = 0}) => Habit.newSeed(
  id: 'a',
  name: 'a',
  flowerId: 'tulip',
  schedule: const Schedule.daily(),
  today: 100,
  reminderMinutes: reminder,
).copyWith(missedSinceWater: missed, ignoredReminders: ignored);

void main() {
  test('no reminder resets to 0', () {
    expect(syncIgnoredReminders(_h(missed: 4, ignored: 4)).ignoredReminders, 0);
  });

  test('reminder mirrors missed count, clamped at 0', () {
    expect(
      syncIgnoredReminders(_h(reminder: 540, missed: 3)).ignoredReminders,
      3,
    );
    expect(
      syncIgnoredReminders(_h(reminder: 540, missed: -2, ignored: 1))
          .ignoredReminders,
      0,
    );
  });

  test('same instance when unchanged', () {
    final a = _h(reminder: 540, missed: 2, ignored: 2);
    expect(identical(syncIgnoredReminders(a), a), isTrue);
    final b = _h();
    expect(identical(syncIgnoredReminders(b), b), isTrue);
  });

  test('misses up to the baseline do not count; no reminder clears it', () {
    final h = _h(reminder: 540, missed: 5).copyWith(reminderBaselineMissed: 4);
    expect(syncIgnoredReminders(h).ignoredReminders, 1);
    final under = _h(
      reminder: 540,
      missed: 2,
      ignored: 1,
    ).copyWith(reminderBaselineMissed: 4);
    expect(syncIgnoredReminders(under).ignoredReminders, 0);
    final off = syncIgnoredReminders(
      _h(missed: 5).copyWith(reminderBaselineMissed: 4),
    );
    expect([off.ignoredReminders, off.reminderBaselineMissed], [0, 0]);
  });
}
