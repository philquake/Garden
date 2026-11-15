import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit_config.dart';
import 'package:garden/domain/stats.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/home_screen.dart';

import '../support.dart';

Widget home({VoidCallback? onAdd, void Function(String)? onOpen}) =>
    HomeScreen(onAdd: onAdd ?? () {}, onOpen: onOpen ?? (_) {});

void main() {
  testWidgets('an empty garden invites the first habit', (tester) async {
    var added = 0;
    await pumpScreen(tester, home(onAdd: () => added++));
    expect(find.text('Add your first habit'), findsOneWidget);
    expect(find.byKey(const Key('add-habit')), findsNothing);
    await tester.tap(find.byKey(const Key('add-first')));
    expect(added, 1);
  });

  testWidgets('lists a card per habit with a summary of today', (tester) async {
    await pumpScreen(
      tester,
      home(),
      habits: [
        tracked(habit('a', name: 'Read')),
        tracked(habit('b', name: 'Stretch'), [testToday]),
      ],
    );
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('1 of 2 done today'), findsOneWidget);
  });

  testWidgets('the button logs today and tapping again undoes it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final db = FakeGardenDb([tracked(habit('a', name: 'Read'))]);
    await pumpScreen(
      tester,
      home(),
      habits: [tracked(habit('a', name: 'Read'))],
      db: db,
    );
    expect(find.bySemanticsLabel('Mark Read done'), findsOneWidget);
    expect(find.text('0 of 1 done today'), findsOneWidget);

    await tester.tap(find.byKey(const Key('log-a')));
    await settle(tester);
    expect(find.text('1 of 1 done today'), findsOneWidget);
    expect(find.bySemanticsLabel('Undo Read'), findsOneWidget);
    expect(db.logs['a'], {testToday: 1});

    await tester.tap(find.byKey(const Key('log-a')));
    await settle(tester);
    expect(find.text('0 of 1 done today'), findsOneWidget);
    expect(db.logs['a'], isEmpty);
    handle.dispose();
  });

  testWidgets('a numeric habit adds one per tap and shows the count', (
    tester,
  ) async {
    final h = habit(
      'w',
      name: 'Water',
      goal: const Goal(target: 2),
      unit: 'glasses',
    );
    await pumpScreen(tester, home(), habits: [tracked(h)]);
    await tester.tap(find.byKey(const Key('log-w')));
    await settle(tester);
    expect(find.text('1 of 1 done today'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('log-w')));
    await settle(tester);
    expect(find.text('1 of 1 done today'), findsOneWidget);
  });

  testWidgets('long press types an exact value', (tester) async {
    final h = habit('w', name: 'Water', goal: const Goal(target: 8));
    final db = FakeGardenDb([tracked(h)]);
    await pumpScreen(tester, home(), habits: [tracked(h)], db: db);
    await tester.longPress(find.byKey(const Key('log-w')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('value-field')), '8');
    await tester.tap(find.byKey(const Key('value-save')));
    await settle(tester);
    expect(db.logs['w'], {testToday: 8});
    expect(find.text('1 of 1 done today'), findsOneWidget);
  });

  testWidgets('long press can clear a value, and rejects nonsense', (
    tester,
  ) async {
    final h = habit('w', goal: const Goal(target: 8));
    final db = FakeGardenDb([
      Tracked(h, {testToday: 3}),
    ]);
    await pumpScreen(
      tester,
      home(),
      habits: [
        Tracked(h, {testToday: 3}),
      ],
      db: db,
    );
    await tester.longPress(find.byKey(const Key('log-w')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('value-field')), 'abc');
    await tester.tap(find.byKey(const Key('value-save')));
    await settle(tester);
    expect(find.text('Enter a number, 0 or more.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('value-clear')));
    await settle(tester);
    expect(db.logs['w'], isEmpty);
  });

  testWidgets('the status line shows the streak and grace used', (
    tester,
  ) async {
    final h = habit('a', createdDay: testToday - 5);
    await pumpScreen(
      tester,
      home(),
      habits: [
        tracked(h, [
          testToday - 5,
          testToday - 4,
          testToday - 2,
          testToday - 1,
        ]),
      ],
    );
    expect(find.text('5 days · 1 grace used'), findsOneWidget);
  });

  testWidgets('a new habit is gentle: ready when you are', (tester) async {
    await pumpScreen(tester, home(), habits: [tracked(habit('a'))]);
    expect(find.text('Ready when you are'), findsOneWidget);
  });

  testWidgets('tapping the card opens the habit', (tester) async {
    String? opened;
    await pumpScreen(
      tester,
      home(onOpen: (id) => opened = id),
      habits: [tracked(habit('a'))],
    );
    await tester.tap(find.text('a'));
    expect(opened, 'a');
  });

  testWidgets('the log button is at least 44x44', (tester) async {
    await pumpScreen(tester, home(), habits: [tracked(habit('a'))]);
    final size = tester.getSize(find.byKey(const Key('log-a')));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('a failed save puts the day back and says so gently', (
    tester,
  ) async {
    final db = FakeGardenDb([tracked(habit('a'))]);
    await pumpScreen(tester, home(), habits: [tracked(habit('a'))], db: db);
    db.failWrites = true;
    await tester.tap(find.byKey(const Key('log-a')));
    await settle(tester);
    expect(find.textContaining("didn't go through"), findsOneWidget);
    expect(find.text('0 of 1 done today'), findsOneWidget);
  });

  testWidgets('a new day moves the summary on', (tester) async {
    await pumpScreen(
      tester,
      home(),
      habits: [
        tracked(habit('a'), [testToday]),
      ],
    );
    expect(find.text('1 of 1 done today'), findsOneWidget);
    containerOf(tester).read(todayProvider.notifier).state = testToday + 1;
    await settle(tester);
    expect(find.text('0 of 1 done today'), findsOneWidget);
  });

  testWidgets('renders in the dark theme without errors', (tester) async {
    await pumpScreen(
      tester,
      home(),
      dark: true,
      habits: [
        tracked(habit('a'), [testToday - 1]),
        tracked(habit('b', flower: 'lavender')),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('0 of 1 done today'), findsNothing);
  });

  testWidgets('a number habit shows today\'s progress against its goal', (
    tester,
  ) async {
    final water = habit('w', goal: const Goal(target: 8), unit: 'glasses');
    final coffee = habit(
      'c',
      goal: const Goal(target: 2, atMost: true),
      unit: 'cups',
    );
    await pumpScreen(
      tester,
      home(),
      habits: [
        Tracked(water, {testToday: 3}),
        Tracked(coffee, {testToday: 3}),
        tracked(habit('y')),
      ],
    );
    expect(find.text('3 of 8 glasses today'), findsOneWidget);
    expect(find.text('3 of 2 cups max today'), findsOneWidget);
    expect(find.byKey(const Key('progress-y')), findsNothing);
  });

  testWidgets('an "at most" habit counts as done until it goes over', (
    tester,
  ) async {
    final coffee = habit('c', goal: const Goal(target: 2, atMost: true));
    await pumpScreen(
      tester,
      home(),
      habits: [
        Tracked(coffee, {testToday: 1}),
      ],
    );
    expect(find.text('1 of 1 done today'), findsOneWidget);
    await tester.tap(find.byKey(const Key('log-c')));
    await settle(tester);
    expect(find.text('2 of 2 max today'), findsOneWidget);
    expect(find.text('1 of 1 done today'), findsOneWidget);
    await tester.tap(find.byKey(const Key('log-c')));
    await settle(tester);
    expect(find.text('3 of 2 max today'), findsOneWidget);
    expect(find.text('0 of 1 done today'), findsOneWidget);
  });
}
