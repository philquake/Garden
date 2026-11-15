import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/day.dart';
import 'package:garden/domain/habit_config.dart';
import 'package:garden/domain/notification_plan.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/stats.dart';

import '../support.dart';

const today = testToday; // a Friday

List<PlannedNotification> plan(List<Tracked> l, {int now = 0}) =>
    planNotifications(l, today, nowMinutes: now);

void main() {
  test('no habits, no plan', () {
    expect(plan([]), isEmpty);
  });

  test('a daily habit gets one reminder a day at its time for two weeks', () {
    final p = plan([tracked(habit('a'))]);
    expect(p.length, 14);
    expect(p.map((n) => n.dayIndex), [for (var i = 0; i < 14; i++) today + i]);
    expect(p.every((n) => n.minutes == 540 && n.habitId == 'a'), isTrue);
  });

  test('a weekday habit reminds only on its weekday', () {
    final p = plan([tracked(habit('a', schedule: Schedule.weekday(1)))]);
    expect(p.length, 2);
    expect(p.every((n) => weekdayOf(n.dayIndex) == 1), isTrue);
  });

  test('a 3-a-week habit lands on Monday, Wednesday and Friday', () {
    final p = plan([tracked(habit('a', schedule: Schedule.timesPerWeek(3)))]);
    expect({for (final n in p) weekdayOf(n.dayIndex)}, {1, 3, 5});
  });

  test('a habit with no reminder time plans nothing', () {
    expect(plan([tracked(habit('a', reminder: null))]), isEmpty);
  });

  test('met today: none today, still tomorrow', () {
    final p = plan([
      tracked(habit('a'), [today]),
    ]);
    expect(p.first.dayIndex, today + 1);
  });

  test('a numeric habit short of its target is still reminded today', () {
    final h = habit('a', goal: const Goal(target: 8));
    final p = plan([
      Tracked(h, {today: 3}),
    ]);
    expect(p.first.dayIndex, today);
  });

  test('days before the habit existed are skipped', () {
    final p = plan([tracked(habit('a', createdDay: today + 3))]);
    expect(p.first.dayIndex, today + 3);
  });

  test('a reminder time already past today moves to tomorrow', () {
    final p = plan([tracked(habit('a', reminder: 540))], now: 540);
    expect(p.first.dayIndex, today + 1);
  });

  test('quiet hours move a reminder to 08:00', () {
    final late = plan([tracked(habit('a', reminder: 23 * 60))]);
    final early = plan([tracked(habit('a', reminder: 5 * 60))]);
    expect(late.first.minutes, 480);
    expect(early.first.minutes, 480);
  });

  test('three or more due habits become one grouped reminder', () {
    final p = plan([
      tracked(habit('a', reminder: 540)),
      tracked(habit('b', reminder: 600)),
      tracked(habit('c', reminder: 660)),
      tracked(habit('d', reminder: 720)),
    ]).where((n) => n.dayIndex == today).toList();
    expect(p.length, 2);
    expect(p.where((n) => n.isGrouped).length, 1);
    expect(p.firstWhere((n) => n.isGrouped).minutes, 600);
  });

  test('two habits give two individual reminders', () {
    final p = plan([tracked(habit('a')), tracked(habit('b'))])
        .where((n) => n.dayIndex == today);
    expect(p.length, 2);
    expect(p.any((n) => n.isGrouped), isFalse);
  });

  test('ids are stable, distinct and the plan is sorted', () {
    final habits = [tracked(habit('a')), tracked(habit('b', reminder: 600))];
    final p = plan(habits);
    expect(p.map((n) => n.id).toSet().length, p.length);
    expect(plan(habits), p);
    for (var i = 1; i < p.length; i++) {
      final a = p[i - 1], b = p[i];
      expect(
        a.dayIndex < b.dayIndex ||
            (a.dayIndex == b.dayIndex && a.minutes <= b.minutes),
        isTrue,
      );
    }
  });

  test('the copy is gentle', () {
    final p = plan([tracked(habit('Read'))]);
    final text = '${p.first.title} ${p.first.body}'.toLowerCase();
    for (final w in ['lost', 'dead', 'missed', 'failed', 'streak', 'hurry']) {
      expect(text.contains(w), isFalse, reason: w);
    }
  });
}
