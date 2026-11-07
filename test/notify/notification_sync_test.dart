import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/notification_plan.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/notify/notification_sync.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_scheduler.dart';

const _today = 20000;
final _now = DateTime(2024, 10, 4, 6, 0); // day 20000 at 06:00

PlannedNotification _n(int id, int day, int minutes, {bool warning = false}) =>
    PlannedNotification(
      id: id,
      habitId: 'h',
      dayIndex: day,
      minutes: minutes,
      isWarning: warning,
      isGrouped: false,
      title: 't',
      body: 'b',
    );

Habit _habit(String id) => Habit.newSeed(
  id: id,
  name: 'Read',
  flowerId: 'lily',
  schedule: const Schedule.daily(),
  today: _today,
  reminderMinutes: 540,
);

Future<ProviderContainer> _container(
  FakeScheduler fake, {
  List<Habit> habits = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = HabitStore(await SharedPreferences.getInstance());
  await store.save(habits);
  final c = ProviderContainer(
    overrides: [
      habitStoreProvider.overrideWithValue(store),
      todayProvider.overrideWithValue(() => _today),
      nowProvider.overrideWithValue(() => _now),
      notificationSchedulerProvider.overrideWithValue(fake),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

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

    test('caps at 60 and keeps every warning first', () {
      final planned = [
        for (var i = 0; i < 80; i++) _n(100 + i, _today + 1 + i % 10, 540),
        for (var i = 0; i < 5; i++) _n(i, _today + 9, 900, warning: true),
      ];
      final items = selectItems(planned, _now);
      expect(items.length, 60);
      expect(items.take(5).every((i) => i.n.isWarning), isTrue);
      expect(items.where((i) => i.n.isWarning).length, 5);
      expect(items.skip(5).first.when.isBefore(items.last.when), isTrue);
    });
  });

  test('plans on start and again after a garden change', () async {
    final fake = FakeScheduler();
    final c = await _container(fake, habits: [_habit('a')]);
    c.read(notificationSyncProvider);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, ['cancel', 'schedule']);
    final expected = selectItems(
      planNotifications([_habit('a')], _today, nowMinutes: 360),
      _now,
    );
    expect(
      fake.scheduled.single.map((i) => i.n.id),
      expected.map((i) => i.n.id),
    );
    expect(fake.scheduled.single, isNotEmpty);

    await c.read(gardenProvider.notifier).add(_habit('b'));
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, ['cancel', 'schedule', 'cancel', 'schedule']);
    expect(
      fake.scheduled.last.length,
      greaterThan(fake.scheduled.first.length),
    );
  });

  test('watering then replanning schedules all three loss warnings', () async {
    final fake = FakeScheduler();
    final c = await _container(fake, habits: [_habit('a')]);
    c.read(notificationSyncProvider);
    await c.read(gardenProvider.notifier).water('a');
    await Future<void>.delayed(Duration.zero);
    final warnings = fake.scheduled.last.where((i) => i.n.isWarning);
    expect(warnings.map((i) => i.n.dayIndex), [
      _today + 14,
      _today + 21,
      _today + 27,
    ]);
  });

  test('overlapping replans never run concurrently', () async {
    final fake = FakeScheduler()..hold = Completer<void>();
    final c = await _container(fake, habits: [_habit('a')]);
    final hold = fake.hold!;
    c.read(notificationSyncProvider);
    await Future<void>.delayed(Duration.zero);
    await c.read(gardenProvider.notifier).add(_habit('b'));
    await c.read(gardenProvider.notifier).add(_habit('c'));
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, ['cancel']); // first replan still held
    hold.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fake.maxRunning, 1);
    // One in-flight replan, then one more covering both later changes.
    expect(fake.calls, ['cancel', 'schedule', 'cancel', 'schedule']);
    final all = selectItems(
      planNotifications(
        [_habit('a'), _habit('b'), _habit('c')],
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
      final c = await _container(fake, habits: [_habit('a')]);
      c.read(notificationSyncProvider);
      await c.read(gardenProvider.notifier).add(_habit('b'));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(gardenProvider).length, 2);
      await c.read(notificationSyncProvider).replan(); // must not throw
    },
  );
}
