import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit_config.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/stats.dart';
import 'package:garden/notify/notification_sync.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/habit_form.dart';

import '../notify/fake_scheduler.dart';
import '../support.dart';

/// The form on top of a first route, so saving and removing can pop.
Future<void> open(
  WidgetTester tester, {
  HabitConfig? existing,
  List<Tracked> habits = const [],
  FakeGardenDb? db,
  FakeScheduler? scheduler,
}) async {
  await pumpScreen(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const Key('open-form'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HabitForm(existing: existing),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    habits: habits,
    db: db,
    extra: [
      if (scheduler != null)
        notificationSchedulerProvider.overrideWithValue(scheduler),
    ],
  );
  await tester.tap(find.byKey(const Key('open-form')));
  await settle(tester);
}

List<Tracked> garden(WidgetTester tester) =>
    containerOf(tester).read(gardenProvider);

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('save-button')));
  await tester.tap(find.byKey(const Key('save-button')));
  await settle(tester);
}

void main() {
  testWidgets('a name is required', (tester) async {
    await open(tester);
    await save(tester);
    expect(find.text('Give your habit a name.'), findsOneWidget);
    expect(find.byType(HabitForm), findsOneWidget);
    expect(garden(tester), isEmpty);
    await tester.enterText(find.byKey(const Key('name-field')), 'R');
    await tester.pump();
    expect(find.text('Give your habit a name.'), findsNothing);
  });

  testWidgets('adds a yes/no daily habit created today', (tester) async {
    final db = FakeGardenDb();
    await open(tester, db: db);
    await tester.enterText(find.byKey(const Key('name-field')), '  Stretch ');
    await save(tester);
    expect(find.byType(HabitForm), findsNothing);
    final c = garden(tester).single.config;
    expect(c.name, 'Stretch');
    expect(c.isYesNo, isTrue);
    expect(c.schedule, const Schedule.daily());
    expect(c.createdDay, testToday);
    expect(c.reminderMinutes, isNull);
    expect(db.configs.keys, [c.id]);
  });

  testWidgets('picks a flower', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('name-field')), 'Run');
    await tester.tap(find.byKey(const Key('flower-choice-lavender')));
    await tester.pump();
    await save(tester);
    expect(garden(tester).single.config.flowerId, 'lavender');
  });

  testWidgets('a number habit needs a target; "at most" can be zero', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('name-field')), 'Water');
    await tester.tap(find.byKey(const Key('type-number')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('target-field')), '0');
    await save(tester);
    expect(find.text('Enter a number.'), findsOneWidget);
    expect(garden(tester), isEmpty);

    await tester.enterText(find.byKey(const Key('target-field')), 'lots');
    await save(tester);
    expect(find.text('Enter a number.'), findsOneWidget);

    await tester.tap(find.text('At most'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('target-field')), '0');
    await save(tester);
    final c = garden(tester).single.config;
    expect(c.goal.target, 0);
    expect(c.goal.atMost, isTrue);
  });

  testWidgets('saves a number goal with its unit', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('name-field')), 'Water');
    await tester.tap(find.byKey(const Key('type-number')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('target-field')), '8');
    await tester.enterText(find.byKey(const Key('unit-field')), 'glasses');
    await save(tester);
    final c = garden(tester).single.config;
    expect(c.goal.target, 8);
    expect(c.goal.atMost, isFalse);
    expect(c.unit, 'glasses');
    expect(c.isYesNo, isFalse);
  });

  testWidgets('times a week and one weekday', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('name-field')), 'Gym');
    await tester.tap(find.byKey(const Key('schedule-times')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('times-plus')));
    await tester.pump();
    await save(tester);
    expect(garden(tester).single.config.schedule, Schedule.timesPerWeek(4));
  });

  testWidgets('one weekday', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('name-field')), 'Call mum');
    await tester.tap(find.byKey(const Key('schedule-weekday')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('weekday-3')));
    await tester.pump();
    await save(tester);
    expect(garden(tester).single.config.schedule, Schedule.weekday(3));
  });

  testWidgets('the stepper stays within 1..7', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('schedule-times')));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.ensureVisible(find.byKey(const Key('times-minus')));
      await tester.tap(find.byKey(const Key('times-minus')));
      await tester.pump();
    }
    expect(find.text('1'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const Key('times-plus')));
      await tester.pump();
    }
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('a reminder asks permission once and is saved at 09:00', (
    tester,
  ) async {
    final fake = FakeScheduler();
    await open(tester, scheduler: fake);
    await tester.enterText(find.byKey(const Key('name-field')), 'Read');
    await tester.ensureVisible(find.byKey(const Key('reminder-switch')));
    await tester.tap(find.byKey(const Key('reminder-switch')));
    await settle(tester);
    expect(fake.permissionRequests, 1);
    expect(find.byKey(const Key('reminder-time')), findsOneWidget);
    await save(tester);
    expect(garden(tester).single.config.reminderMinutes, 540);
  });

  testWidgets('declined notifications are explained, the habit still saves', (
    tester,
  ) async {
    final fake = FakeScheduler(permission: false);
    await open(tester, scheduler: fake);
    await tester.enterText(find.byKey(const Key('name-field')), 'Read');
    await tester.ensureVisible(find.byKey(const Key('reminder-switch')));
    await tester.tap(find.byKey(const Key('reminder-switch')));
    await settle(tester);
    expect(find.textContaining('Notifications are off'), findsOneWidget);
    await save(tester);
    expect(garden(tester).single.config.reminderMinutes, 540);
  });

  testWidgets('a failed save keeps the form and says so', (tester) async {
    final db = FakeGardenDb()..failWrites = true;
    await open(tester, db: db);
    await tester.enterText(find.byKey(const Key('name-field')), 'Read');
    await save(tester);
    expect(find.byType(HabitForm), findsOneWidget);
    expect(find.textContaining("didn't go through"), findsOneWidget);
    expect(garden(tester), isEmpty);
    db.failWrites = false;
    await save(tester);
    expect(find.byType(HabitForm), findsNothing);
    expect(garden(tester).length, 1);
  });

  group('editing', () {
    final existing = habit(
      'a',
      name: 'Water',
      goal: const Goal(target: 8, atMost: true),
      unit: 'glasses',
      schedule: Schedule.timesPerWeek(5),
      createdDay: testToday - 20,
      flower: 'sunflower',
    );

    testWidgets('fills in every field', (tester) async {
      await open(tester, existing: existing, habits: [tracked(existing)]);
      TextField field(String k) => tester.widget<TextField>(find.byKey(Key(k)));
      expect(field('name-field').controller!.text, 'Water');
      expect(field('target-field').controller!.text, '8');
      expect(field('unit-field').controller!.text, 'glasses');
      expect(find.text('5'), findsOneWidget);
      expect(find.byKey(const Key('reminder-time')), findsOneWidget);
      expect(find.text('Edit habit'), findsOneWidget);
    });

    testWidgets('saving keeps the creation day and the history', (
      tester,
    ) async {
      final t = tracked(existing, [testToday - 1]);
      await open(tester, existing: existing, habits: [t]);
      await tester.enterText(find.byKey(const Key('name-field')), 'Hydrate');
      await save(tester);
      final now = garden(tester).single;
      expect(now.config.name, 'Hydrate');
      expect(now.config.createdDay, testToday - 20);
      expect(now.log, {testToday - 1: 1});
    });

    testWidgets('remove asks first, Keep it leaves everything', (tester) async {
      await open(tester, existing: existing, habits: [tracked(existing)]);
      await tester.ensureVisible(find.byKey(const Key('remove-button')));
      await tester.tap(find.byKey(const Key('remove-button')));
      await settle(tester);
      expect(find.text('Remove Water?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('keep-it')));
      await settle(tester);
      expect(garden(tester).length, 1);
      expect(find.byType(HabitForm), findsOneWidget);
    });

    testWidgets('confirming removes the habit and goes back to the start', (
      tester,
    ) async {
      final db = FakeGardenDb([
        tracked(existing, [testToday]),
      ]);
      await open(
        tester,
        existing: existing,
        habits: [
          tracked(existing, [testToday]),
        ],
        db: db,
      );
      await tester.ensureVisible(find.byKey(const Key('remove-button')));
      await tester.tap(find.byKey(const Key('remove-button')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-remove')));
      await settle(tester);
      expect(garden(tester), isEmpty);
      expect(db.logs.containsKey('a'), isFalse);
      expect(find.byType(HabitForm), findsNothing);
    });

    testWidgets('a new habit has no remove button', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('remove-button')), findsNothing);
    });
  });

  testWidgets('taps are at least 44x44 and flowers have labels', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    for (final k in ['times-minus', 'save-button']) {
      await tester.tap(find.byKey(const Key('schedule-times')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(Key(k)));
      final size = tester.getSize(find.byKey(Key(k)));
      expect(size.width, greaterThanOrEqualTo(44), reason: k);
      expect(size.height, greaterThanOrEqualTo(44), reason: k);
    }
    expect(find.bySemanticsLabel('Choose Tulip'), findsOneWidget);
    expect(find.bySemanticsLabel('Choose Daisy'), findsOneWidget);
    handle.dispose();
  });
}
