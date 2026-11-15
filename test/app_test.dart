import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/app.dart';
import 'package:garden/ui/habit_form.dart';
import 'package:garden/ui/habit_screen.dart';

import 'support.dart';

void main() {
  testWidgets('add a habit, log it, open it, edit it, remove it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeGardenDb();
    await tester.pumpWidget(
      ProviderScope(
        overrides: gardenOverrides(db: db),
        child: const GardenApp(),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('add-first')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-first')));
    await settle(tester);
    expect(find.byType(HabitForm), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name-field')), 'Stretch');
    await tester.tap(find.byKey(const Key('save-button')));
    await settle(tester);
    expect(find.byType(HabitForm), findsNothing);
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('0 of 1 done today'), findsOneWidget);

    final id = db.configs.keys.single;
    await tester.tap(find.byKey(Key('log-$id')));
    await settle(tester);
    expect(find.text('1 of 1 done today'), findsOneWidget);
    expect(db.logs[id]!.length, 1);

    await tester.tap(find.byKey(Key('card-$id')));
    await settle(tester);
    expect(find.byType(HabitScreen), findsOneWidget);
    expect(find.text('Stretch'), findsWidgets);

    await tester.tap(find.byKey(const Key('edit-habit')));
    await settle(tester);
    expect(find.text('Edit habit'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('remove-button')));
    await tester.tap(find.byKey(const Key('remove-button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-remove')));
    await settle(tester);
    expect(find.byType(HabitScreen), findsNothing);
    expect(find.byKey(const Key('add-first')), findsOneWidget);
    expect(db.configs, isEmpty);
  });

  testWidgets('habits already on disk show up at start', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: gardenOverrides(
          habits: [
            tracked(habit('a', name: 'Read'), [testToday - 1, testToday]),
          ],
        ),
        child: const GardenApp(),
      ),
    );
    await settle(tester);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('2 days'), findsOneWidget);
    expect(find.text('1 of 1 done today'), findsOneWidget);
  });
}
