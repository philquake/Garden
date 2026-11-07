import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/art/art_pack.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/domain/growth.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/state/art_provider.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/habit_form.dart';
import 'package:garden/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _today = 20000;
const _ids = ['rose', 'lily', 'iris', 'poppy', 'aster'];

final _pack = ArtPack.fromManifest({
  for (final id in _ids)
    id: {
      '2': {
        'healthy': ['missing/$id.png'],
      },
    },
});

late ProviderContainer _c;

Habit _habit(String id, {Schedule s = const Schedule.daily(), int ago = 0}) =>
    Habit.newSeed(
      id: id,
      name: 'Read',
      flowerId: 'lily',
      schedule: s,
      today: _today - ago,
    );

Future<void> _pump(
  WidgetTester tester, {
  List<Habit> habits = const [],
  Habit? existing,
  int today = _today,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = HabitStore(prefs);
  await store.save(habits);
  _c = ProviderContainer(
    overrides: [
      habitStoreProvider.overrideWithValue(store),
      todayProvider.overrideWithValue(() => today),
      artPackProvider.overrideWithValue(_pack),
    ],
  );
  addTearDown(_c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _c,
      child: MaterialApp(
        theme: gardenTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open'),
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
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _save(WidgetTester tester) async {
  await _tap(tester, 'save-button');
  // The store write is real async I/O, so let it finish before the pop.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

List<Habit> get _habits => _c.read(gardenProvider);

void main() {
  testWidgets('empty or blank name is not saved and says why', (tester) async {
    await _pump(tester);
    expect(find.text('Plant a seed'), findsOneWidget);
    await _save(tester);
    expect(find.text('Give your habit a name.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name-field')), '   ');
    await _save(tester);
    expect(find.text('Give your habit a name.'), findsOneWidget);
    expect(_habits, isEmpty);
    expect(find.byType(HabitForm), findsOneWidget);
  });

  testWidgets('saving plants a seed with chosen flower and schedule', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const Key('name-field')), '  Walk ');
    await _tap(tester, 'flower-choice-iris');
    await _tap(tester, 'schedule-times');
    await _tap(tester, 'times-plus');
    await _save(tester);
    final h = _habits.single;
    expect(h.name, 'Walk');
    expect(h.flowerId, 'iris');
    expect(h.schedule, Schedule.timesPerWeek(4));
    expect(growthStage(h), 0);
    expect(h.wateredDays, isEmpty);
    expect(h.plantingNumber, 1);
    expect(h.reminderMinutes, -1);
    expect(find.byType(HabitForm), findsNothing);
  });

  testWidgets('default flower is the first and the picker lists all', (
    tester,
  ) async {
    await _pump(tester);
    for (final id in _ids) {
      expect(find.byKey(Key('flower-choice-$id')), findsOneWidget);
    }
    await tester.enterText(find.byKey(const Key('name-field')), 'A');
    await _save(tester);
    expect(_habits.single.flowerId, 'rose');
  });

  testWidgets('daily and weekday schedules', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const Key('name-field')), 'A');
    await _save(tester);
    expect(_habits.single.schedule, const Schedule.daily());

    await _pump(tester);
    await tester.enterText(find.byKey(const Key('name-field')), 'A');
    await _tap(tester, 'schedule-weekday');
    await _tap(tester, 'weekday-5');
    await _save(tester);
    expect(_habits.single.schedule, Schedule.weekday(5));
  });

  testWidgets('times stepper defaults to 3 and stays within 1..7', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, 'schedule-times');
    expect(
      find.descendant(
        of: find.byKey(const Key('times-stepper')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    for (var i = 0; i < 10; i++) {
      await _tap(tester, 'times-plus');
    }
    await tester.enterText(find.byKey(const Key('name-field')), 'A');
    await _save(tester);
    expect(_habits.single.schedule, Schedule.timesPerWeek(7));
  });

  testWidgets('reminder switch gives 540 on and -1 off', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const Key('name-field')), 'A');
    expect(find.byKey(const Key('reminder-time')), findsNothing);
    await _tap(tester, 'reminder-switch');
    expect(find.byKey(const Key('reminder-time')), findsOneWidget);
    await _save(tester);
    expect(_habits.single.reminderMinutes, 540);

    await _pump(tester);
    await tester.enterText(find.byKey(const Key('name-field')), 'A');
    await _tap(tester, 'reminder-switch');
    await _tap(tester, 'reminder-switch');
    await _save(tester);
    expect(_habits.single.reminderMinutes, -1);
  });

  testWidgets('editing preselects fields', (tester) async {
    final h = _habit(
      'a',
      s: Schedule.weekday(3),
    ).copyWith(reminderMinutes: 600);
    await _pump(tester, habits: [h], existing: h);
    expect(find.text('Edit habit'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.byKey(const Key('weekday-3')), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('weekday-3'))).selected,
      isTrue,
    );
    expect(find.byKey(const Key('reminder-time')), findsOneWidget);
    expect(find.bySemanticsLabel('Choose Lily'), findsOneWidget);
  });

  testWidgets('editing schedule creates no misses; details persist', (
    tester,
  ) async {
    // Planted 2 days ago, never watered: one day into neglect.
    final h = _habit('a', ago: 2);
    await _pump(tester, habits: [h], existing: h);
    final before = _habits.single;
    await tester.enterText(find.byKey(const Key('name-field')), 'Stretch');
    await _tap(tester, 'flower-choice-poppy');
    await _tap(tester, 'schedule-weekday');
    await _tap(tester, 'weekday-2');
    await _tap(tester, 'reminder-switch');
    await _save(tester);
    final after = _habits.single;
    expect(after.schedule, Schedule.weekday(2));
    expect(after.name, 'Stretch');
    expect(after.flowerId, 'poppy');
    expect(after.reminderMinutes, 540);
    expect(after.missedSinceWater, before.missedSinceWater);
    expect(after.declineStep, before.declineStep);
    expect(find.byType(HabitForm), findsNothing);
  });

  testWidgets('full garden shows a gentle message and keeps the form', (
    tester,
  ) async {
    await _pump(tester, habits: [for (var i = 0; i < 8; i++) _habit('h$i')]);
    await tester.enterText(find.byKey(const Key('name-field')), 'Ninth');
    await _save(tester);
    expect(
      find.text('Your garden is full for now. Let a few flowers bloom first.'),
      findsOneWidget,
    );
    expect(find.byType(HabitForm), findsOneWidget);
    expect(_habits.length, 8);
  });

  testWidgets('double tap on Save adds only one habit', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const Key('name-field')), 'Once');
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.tap(find.byKey(const Key('save-button')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_habits.length, 1);
  });
}
