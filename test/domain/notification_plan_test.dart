import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/day.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/notification_plan.dart';
import 'package:garden/domain/schedule.dart';

const today = 20000;

Habit h(
  String id, {
  Schedule schedule = const Schedule.daily(),
  int reminder = 540,
  int ignored = 0,
  bool lost = false,
  int? planted,
  int? lastWater,
  Set<int> watered = const {},
  String flower = 'Tulip',
}) =>
    Habit.newSeed(
      id: id,
      name: id,
      flowerId: flower,
      schedule: schedule,
      today: planted ?? today - 30,
      reminderMinutes: reminder,
    ).copyWith(
      ignoredReminders: ignored,
      lost: lost,
      lastWaterDay: lastWater ?? today,
      wateredDays: watered,
    );

List<PlannedNotification> reminders(List<PlannedNotification> l) =>
    l.where((n) => !n.isWarning).toList();

void main() {
  test('empty list gives empty plan', () {
    expect(planNotifications([], today), isEmpty);
  });

  test('daily: one reminder per day for 14 days at its time', () {
    final p = planNotifications([h('a', reminder: 600)], today);
    expect(p.length, 14);
    expect(p.map((n) => n.dayIndex), [for (var i = 0; i < 14; i++) today + i]);
    expect(p.every((n) => n.minutes == 600 && !n.isWarning), isTrue);
    expect(p.first.title, 'Time for a');
    expect(p.first.body, 'Your tulip would love a drink.');
    expect(p.first.habitId, 'a');
  });

  test('weekday only on its weekday', () {
    final p = planNotifications([h('a', schedule: Schedule.weekday(3))], today);
    expect(p.length, 2);
    expect(p.every((n) => weekdayOf(n.dayIndex) == 3), isTrue);
  });

  test('timesPerWeek lands on expected weekdays', () {
    Set<int> days(int n) => {
      for (final x in planNotifications([
        h('a', schedule: Schedule.timesPerWeek(n)),
      ], today))
        weekdayOf(x.dayIndex),
    };
    expect(days(3), {1, 3, 5});
    expect(days(1), {1});
    expect(days(7), {1, 2, 3, 4, 5, 6, 7});
  });

  test('watered today: none today, still tomorrow', () {
    final p = planNotifications([
      h('a', watered: {today}),
    ], today);
    expect(p.first.dayIndex, today + 1);
    expect(p.length, 13);
  });

  test('days before plantedDay skipped', () {
    final p = planNotifications([h('a', planted: today + 5)], today);
    expect(p.first.dayIndex, today + 5);
    expect(p.length, 9);
  });

  test('nowMinutes skips today earlier-or-equal reminder', () {
    expect(
      planNotifications([h('a')], today, nowMinutes: 540).first.dayIndex,
      today + 1,
    );
    expect(
      planNotifications([h('a')], today, nowMinutes: 539).first.dayIndex,
      today,
    );
  });

  test('quiet hours move to 08:00 same day', () {
    for (final m in [23 * 60, 3 * 60, 22 * 60, 0]) {
      final p = planNotifications([h('a', reminder: m)], today);
      expect(p.every((n) => n.minutes == 480), isTrue, reason: '$m');
      expect(p.first.dayIndex, today);
    }
    expect(
      planNotifications([h('a', reminder: 1319)], today).first.minutes,
      1319,
    );
  });

  test('four due habits: 1 individual + 1 grouped', () {
    final hs = [
      for (final id in ['d', 'c', 'b', 'a']) h(id),
    ];
    final p = planNotifications(hs, today, horizonDays: 1);
    expect(p.length, 2);
    final first = p.firstWhere((n) => !n.isGrouped);
    expect(first.habitId, 'a');
    final g = p.firstWhere((n) => n.isGrouped);
    expect(g.habitId, isNull);
    expect(g.title, 'Your garden');
    expect(g.body, 'A few flowers would love a drink.');
    expect(g.minutes, 540);
    expect(g.isWarning, isFalse);
  });

  test('grouped sits at the second reminder time', () {
    final p = planNotifications(
      [h('a', reminder: 500), h('b', reminder: 700), h('c', reminder: 900)],
      today,
      horizonDays: 1,
    );
    expect(p.map((n) => n.minutes), [500, 700]);
    expect(p[1].isGrouped, isTrue);
  });

  test('two habits give two individual reminders', () {
    final p = planNotifications([h('a'), h('b')], today, horizonDays: 1);
    expect(p.length, 2);
    expect(p.any((n) => n.isGrouped), isFalse);
  });

  test('paused, unset and lost reminders; warnings survive pause', () {
    expect(reminders(planNotifications([h('a', ignored: 3)], today)), isEmpty);
    expect(planNotifications([h('a', reminder: -1)], today), isEmpty);
    expect(
      planNotifications([h('a', lost: true, lastWater: today - 5)], today),
      isEmpty,
    );
    final p = planNotifications(
      [h('a', ignored: 3, lastWater: today - 10)],
      today,
      horizonDays: 40,
    );
    expect(p.length, 3);
    expect(p.every((n) => n.isWarning), isTrue);
    expect(p.map((n) => n.dayIndex), [today + 4, today + 11, today + 17]);
  });

  test('warnings at 14/21/27 with default 540 time', () {
    final p = planNotifications(
      [h('a', reminder: -1, lastWater: today - 2)],
      today,
      horizonDays: 40,
    );
    expect(p.map((n) => n.dayIndex), [today + 12, today + 19, today + 25]);
    expect(p.every((n) => n.minutes == 540), isTrue);
    expect(p.first.title, 'Your tulip is waiting');
    expect(
      p.first.body,
      'A fresh start is here whenever you want it. Your history stays.',
    );
    expect(
      planNotifications(
        [h('a', reminder: -1, lastWater: today - 14)],
        today,
        nowMinutes: 540,
      ).where((n) => n.dayIndex == today),
      isEmpty,
    );
  });

  test('warning day keeps 2 reminders plus the warning', () {
    final p = planNotifications(
      [h('a', lastWater: today - 10), h('b')],
      today,
      horizonDays: 6,
    );
    final day = p.where((n) => n.dayIndex == today + 4).toList();
    expect(day.length, 3);
    expect(day.where((n) => n.isWarning).length, 1);
  });

  test('ids stable, distinct; sorted', () {
    final hs = [
      h('b', reminder: 700),
      h('a', reminder: 500, lastWater: today - 10),
    ];
    final p1 = planNotifications(hs, today, horizonDays: 20);
    expect(p1, planNotifications(hs, today, horizonDays: 20));
    expect(p1.map((n) => n.id).toSet().length, p1.length);
    for (var i = 1; i < p1.length; i++) {
      final a = p1[i - 1], b = p1[i];
      final ka = [a.dayIndex, a.minutes, a.id];
      final kb = [b.dayIndex, b.minutes, b.id];
      var c = 0;
      for (var k = 0; k < 3 && c == 0; k++) {
        c = ka[k].compareTo(kb[k]);
      }
      expect(c, lessThan(0));
    }
    expect(notificationId('r:a:1'), notificationId('r:a:1'));
    expect(notificationId('x'), inInclusiveRange(1, 0x7FFFFFFF));
  });

  test('no guilt words in any copy', () {
    final p = planNotifications(
      [
        for (final id in ['a', 'b', 'c', 'd']) h(id, lastWater: today - 10),
      ],
      today,
      horizonDays: 40,
    );
    final banned = RegExp(
      r'\b(fail|lazy|behind|missed|late|bad|should|guilt|streak|punish|lost|give up)',
      caseSensitive: false,
    );
    expect(p.any((n) => n.isGrouped), isTrue);
    expect(p.any((n) => n.isWarning), isTrue);
    for (final n in p) {
      expect(banned.hasMatch(n.title), isFalse, reason: n.title);
      expect(banned.hasMatch(n.body), isFalse, reason: n.body);
    }
  });
}
