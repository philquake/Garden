import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit_config.dart';
import 'package:garden/domain/notification_plan.dart';
import 'package:garden/notify/notification_sync.dart';
import 'package:garden/state/garden_controller.dart';

import '../support.dart';
import 'fake_scheduler.dart';

const _today = testToday;
final _now = DateTime(2024, 10, 4, 6, 0); // day 20000 at 06:00

PlannedNotification _n(int id, int day, int minutes) => PlannedNotification(
  id: id,
  habitId: 'h',
  dayIndex: day,
  minutes: minutes,
  isGrouped: false,
  title: 't',
  body: 'b',
);

HabitConfig _habit(String id) => habit(id, name: 'Read');

ProviderContainer _container(
  FakeScheduler fake, {
  List<HabitConfig> habits = const [],
}) => makeContainer(
  habits: [for (final h in habits) tracked(h)],
  overrides: [
    nowProvider.overrideWithValue(() => _now),
    notificationSchedulerProvider.overrideWithValue(fake),
  ],
);

void main() {
  group('selectItems', () {
    test('drops the past and dedupes by id', () {
      final items = selectItems([
        _n(1, _today, 300), // 05:00, already past
        _n(2, _today, 600),
        _n(2, _today, 600),
      ], _now);
      expect(items.map((i) => i.n.id), [2]);
    });

    test('caps at 60, soonest first', () {
      final planned = [
        for (var i = 0; i < 80; i++) _n(100 + i, _today + 1 + i % 10, 540),
      ];
      final items = selectItems(planned, _now);
      expect(items.length, 60);
      for (var i = 1; i < items.length; i++) {
        expect(items[i - 1].when.isAfter(items[i].when), isFalse);
      }
    });
  });

  test('plans on start and again after a garden change', () async {
    final fake = FakeScheduler();
    final c = _container(fake, habits: [_habit('a')]);
    c.read(notificationSyncProvider);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, ['schedule', 'cancel']);
    // Everything just scheduled is kept; only older ids can be cancelled.
    expect(fake.kept.single, {for (final i in fake.scheduled.single) i.n.id});
    final expected = selectItems(
      planNotifications([tracked(_habit('a'))], _today, nowMinutes: 360),
      _now,
    );
    expect(
      fake.scheduled.single.map((i) => i.n.id),
      expected.map((i) => i.n.id),
    );
    expect(fake.scheduled.single, isNotEmpty);

    await c.read(gardenProvider.notifier).add(_habit('b'));
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, ['schedule', 'cancel', 'schedule', 'cancel']);
    expect(
      fake.scheduled.last.length,
      greaterThan(fake.scheduled.first.length),
    );
  });

  test('logging today replans without the reminder for today', () async {
    final fake = FakeScheduler();
    final c = _container(fake, habits: [_habit('a')]);
    c.read(notificationSyncProvider);
    await Future<void>.delayed(Duration.zero);
    expect(fake.scheduled.last.first.n.dayIndex, _today);
    await c.read(gardenProvider.notifier).setValue('a', _today, 1);
    await Future<void>.delayed(Duration.zero);
    expect(fake.scheduled.last.first.n.dayIndex, _today + 1);
  });

  test('removing a habit replans without it', () async {
    final fake = FakeScheduler();
    final c = _container(fake, habits: [_habit('a'), _habit('b')]);
    c.read(notificationSyncProvider);
    await Future<void>.delayed(Duration.zero);
    expect(fake.scheduled.last.any((i) => i.n.habitId == 'a'), isTrue);
    await c.read(gardenProvider.notifier).remove('a');
    await Future<void>.delayed(Duration.zero);
    expect(fake.scheduled.length, 2);
    expect(fake.scheduled.last.any((i) => i.n.habitId == 'a'), isFalse);
    expect(fake.scheduled.last, isNotEmpty);
  });

  test('overlapping replans never run concurrently', () async {
    final fake = FakeScheduler()..hold = Completer<void>();
    final c = _container(fake, habits: [_habit('a')]);
    final hold = fake.hold!;
    c.read(notificationSyncProvider);
    await Future<void>.delayed(Duration.zero);
    await c.read(gardenProvider.notifier).add(_habit('b'));
    await c.read(gardenProvider.notifier).add(_habit('c'));
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, ['schedule', 'cancel']); // first replan still held
    hold.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fake.maxRunning, 1);
    // One in-flight replan, then one more covering both later changes.
    expect(fake.calls, ['schedule', 'cancel', 'schedule', 'cancel']);
    final all = selectItems(
      planNotifications(
        [tracked(_habit('a')), tracked(_habit('b')), tracked(_habit('c'))],
        _today,
        nowMinutes: 360,
      ),
      _now,
    );
    expect(fake.scheduled.last.map((i) => i.n.id), all.map((i) => i.n.id));
  });

  test(
    'a throwing scheduler is swallowed and the garden is unaffected',
    () async {
      final fake = FakeScheduler()..throwing = true;
      final c = _container(fake, habits: [_habit('a')]);
      c.read(notificationSyncProvider);
      await c.read(gardenProvider.notifier).add(_habit('b'));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(gardenProvider).length, 2);
      await c.read(notificationSyncProvider).replan(); // must not throw
    },
  );
}
