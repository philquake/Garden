import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/app.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/habit_form.dart';
import 'package:garden/ui/habit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _frames(WidgetTester tester) async {
  // Let real store I/O finish, then run a few frames (animations never settle).
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('plant, open and edit a habit', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          habitStoreProvider.overrideWithValue(HabitStore(prefs)),
          todayProvider.overrideWithValue(() => 20000),
        ],
        child: const GardenApp(),
      ),
    );
    await _frames(tester);
    expect(find.byKey(const Key('plant-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('plant-button')));
    await _frames(tester);
    expect(find.byType(HabitForm), findsOneWidget);

    await tester.enterText(find.byKey(const Key('name-field')), 'Stretch');
    await tester.tap(find.byKey(const Key('save-button')));
    await _frames(tester);
    expect(find.byType(HabitForm), findsNothing);
    final flower = find.byWidgetPredicate(
      (w) => w.key.toString().contains("'flower-") && w.key is ValueKey,
    );
    expect(flower, findsOneWidget);

    await tester.tap(flower);
    await _frames(tester);
    expect(find.byType(HabitScreen), findsOneWidget);
    expect(find.text('Stretch'), findsWidgets);

    await tester.tap(find.byKey(const Key('edit-button')));
    await _frames(tester);
    expect(find.byType(HabitForm), findsOneWidget);
    expect(find.text('Edit habit'), findsOneWidget);
    expect(find.text('Stretch'), findsWidgets);
    final field = tester.widget<TextField>(find.byKey(const Key('name-field')));
    expect(field.controller!.text, 'Stretch');

    await tester.pageBack();
    await _frames(tester);
    expect(find.byType(HabitForm), findsNothing);
    expect(find.byType(HabitScreen), findsOneWidget);
  });
}
