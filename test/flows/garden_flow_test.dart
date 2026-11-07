import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/app.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/domain/day.dart';
import 'package:garden/domain/growth.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/habit_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _plant(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('plant-button')));
  await _frames(tester);
  await tester.enterText(find.byKey(const Key('name-field')), name);
  await tester.tap(find.byKey(const Key('save-button')));
  await _frames(tester);
}

Future<ProviderContainer> _start(
  WidgetTester tester,
  int Function() today,
) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitStoreProvider.overrideWithValue(HabitStore(prefs)),
        todayProvider.overrideWithValue(today),
      ],
      child: const GardenApp(),
    ),
  );
  await _frames(tester);
  return ProviderScope.containerOf(tester.element(find.byType(GardenApp)));
}

void main() {
  testWidgets('plant, water, neglect, fresh start, lose, replant', (
    tester,
  ) async {
    var day = dayIndex(DateTime(2026, 11, 9, 12));
    final planted = day;
    final container = await _start(tester, () => day);
    Habit habit() => container.read(gardenProvider).single;
    Future<void> advance(int days) async {
      day += days;
      await tester.runAsync(
        () => container.read(gardenProvider.notifier).refresh(),
      );
      await _frames(tester);
    }

    final flower = find.byWidgetPredicate(
      (w) => w.key is ValueKey && w.key.toString().contains("'flower-"),
    );

    expect(
      find.text('Your meadow is waiting. Plant your first seed.'),
      findsOneWidget,
    );
    await _plant(tester, 'Stretch');
    expect(find.byType(HabitForm), findsNothing);
    expect(flower, findsOneWidget);

    await tester.tap(flower);
    await _frames(tester);
    await tester.tap(find.byKey(const Key('habit-flower')));
    await _frames(tester);
    expect(find.text('1 of 7 this week'), findsOneWidget);
    expect(habit().wateredDays, contains(planted));

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await _frames(tester);
    await advance(9);
    expect(find.byKey(const Key('encouragement-banner')), findsOneWidget);
    await tester.tap(flower);
    await _frames(tester);
    expect(find.byKey(const Key('fresh-start-button')), findsOneWidget);

    final stageBefore = growthStage(habit());
    await tester.tap(find.byKey(const Key('fresh-start-button')));
    await _frames(tester);
    expect(find.byKey(const Key('fresh-start-button')), findsNothing);
    expect(growthStage(habit()), stageBefore);
    expect(habit().wateredDays, contains(planted));
    expect(habit().declineStep, 0);
    expect(find.byKey(ValueKey('watered-$planted')), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await _frames(tester);
    await advance(40);
    expect(habit().lost, isTrue);
    await tester.tap(flower);
    await _frames(tester);
    expect(find.byKey(const Key('replant-button')), findsOneWidget);
    expect(find.byKey(const Key('fresh-start-button')), findsNothing);

    await tester.tap(find.byKey(const Key('replant-button')));
    await _frames(tester);
    expect(growthStage(habit()), 0);
    expect(habit().wateredDays, contains(planted));
    expect(habit().plantingNumber, 2);
    expect(find.byKey(const Key('replant-button')), findsNothing);
  });

  testWidgets('a ninth habit is refused with a gentle message', (tester) async {
    final container = await _start(tester, () => 20000);
    for (var i = 0; i < 8; i++) {
      await _plant(tester, 'Habit $i');
    }
    expect(container.read(gardenProvider), hasLength(8));
    await tester.tap(find.byKey(const Key('plant-button')));
    await _frames(tester);
    expect(find.byType(HabitForm), findsNothing);
    expect(find.textContaining('Your garden is full'), findsOneWidget);
    expect(container.read(gardenProvider), hasLength(8));
  });
}
