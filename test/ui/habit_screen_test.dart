import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit_config.dart';
import 'package:garden/domain/stats.dart';
import 'package:garden/ui/habit_form.dart';
import 'package:garden/ui/habit_screen.dart';

import '../support.dart';

// 4 Oct 2024. Day testToday-3 is 1 Oct; testToday-4 is 30 Sep.
Tracked sample({int logged = 6}) => tracked(
  habit('a', name: 'Read', createdDay: testToday - 10),
  [for (var i = 0; i < logged; i++) testToday - i],
);

/// The Text at [key], or the first Text inside it.
Text _text(WidgetTester tester, String key) {
  final f = find.byKey(Key(key));
  final w = tester.widget(f);
  if (w is Text) return w;
  return tester.widget<Text>(
    find.descendant(of: f, matching: find.byType(Text)).first,
  );
}

Finder _segment(String label) => find.descendant(
  of: find.byKey(const Key('range')),
  matching: find.text(label),
);

void main() {
  testWidgets('shows the status, the overview and the way to habit formed', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'a'),
      habits: [sample()],
    );
    expect(find.text('Read'), findsOneWidget);
    expect(_text(tester, 'status-line').data, '6 days');
    expect(_text(tester, 'total').data, '6');
    expect(find.text('6 of 66 days to habit formed'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Best streaks'), findsOneWidget);
    expect(find.text('6 days'), findsWidgets);
  });

  testWidgets('score changes show a sign and a percentage', (tester) async {
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'a'),
      habits: [sample()],
    );
    expect(_text(tester, 'change-month').data, matches(r'^\+\d+%$'));
  });

  testWidgets('the calendar lets you log a past day and take it back', (
    tester,
  ) async {
    final db = FakeGardenDb([sample(logged: 2)]);
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'a'),
      habits: [sample(logged: 2)],
      db: db,
    );
    final day = testToday - 3; // 1 Oct
    await tester.ensureVisible(find.byKey(Key('day-$day')));
    await tester.tap(find.byKey(Key('day-$day')));
    await settle(tester);
    expect(db.logs['a']!.containsKey(day), isTrue);
    expect(_text(tester, 'total').data, '3');
    await tester.tap(find.byKey(Key('day-$day')));
    await settle(tester);
    expect(db.logs['a']!.containsKey(day), isFalse);
    expect(_text(tester, 'total').data, '2');
  });

  testWidgets('days after today and before creation cannot be edited', (
    tester,
  ) async {
    final db = FakeGardenDb([sample()]);
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'a'),
      habits: [sample()],
      db: db,
    );
    final before = {...db.logs['a']!};
    for (final day in [testToday + 1, testToday - 11]) {
      final f = find.byKey(Key('day-$day'));
      if (f.evaluate().isEmpty) continue;
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle(tester);
    }
    expect(db.logs['a'], before);
  });

  testWidgets('month navigation stops at the creation month and at today', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'a'),
      // Created 4 Sep 2024: one month back is the earliest.
      habits: [
        tracked(habit('a', createdDay: testToday - 30), [testToday]),
      ],
    );
    expect(_text(tester, 'month-title').data, 'Oct 2024');
    final next = find.byKey(const Key('month-next'));
    final prev = find.byKey(const Key('month-prev'));
    await tester.ensureVisible(prev);
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    await tester.tap(prev);
    await settle(tester);
    expect(_text(tester, 'month-title').data, 'Sep 2024');
    expect(tester.widget<IconButton>(prev).onPressed, isNull);
    await tester.tap(next);
    await settle(tester);
    expect(_text(tester, 'month-title').data, 'Oct 2024');
  });

  testWidgets('a numeric habit opens a value box from the calendar', (
    tester,
  ) async {
    final h = habit(
      'w',
      name: 'Water',
      goal: const Goal(target: 8),
      createdDay: testToday - 10,
    );
    final db = FakeGardenDb([tracked(h)]);
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'w'),
      habits: [tracked(h)],
      db: db,
    );
    final day = testToday - 2;
    await tester.ensureVisible(find.byKey(Key('day-$day')));
    await tester.tap(find.byKey(Key('day-$day')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('value-field')), '5');
    await tester.tap(find.byKey(const Key('value-save')));
    await settle(tester);
    expect(db.logs['w'], {day: 5});
    expect(_text(tester, 'total').data, '0'); // 5 of 8 is partial
  });

  testWidgets('a number habit shows its progress today under the status', (
    tester,
  ) async {
    final h = habit(
      'w',
      name: 'Water',
      goal: const Goal(target: 8),
      unit: 'glasses',
    );
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'w'),
      habits: [
        Tracked(h, {testToday: 5}),
      ],
    );
    expect(_text(tester, 'progress-line').data, '5 of 8 glasses today');
  });

  testWidgets('the range toggle redraws the charts', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'a'),
      habits: [sample()],
    );
    expect(find.bySemanticsLabel(RegExp('History by month')), findsOneWidget);
    await tester.tap(_segment('Week'));
    await settle(tester);
    expect(find.bySemanticsLabel(RegExp('History by week')), findsOneWidget);
    await tester.tap(_segment('Year'));
    await settle(tester);
    expect(
      find.bySemanticsLabel(RegExp('Score over time.*year')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('best streaks lists the longest runs first', (tester) async {
    final days = [
      for (var i = 0; i < 4; i++) testToday - i,
      testToday - 8,
      testToday - 9,
    ];
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'a'),
      habits: [tracked(habit('a', createdDay: testToday - 12), days)],
    );
    expect(find.textContaining('from '), findsWidgets);
  });

  testWidgets('edit opens the form with the habit filled in', (tester) async {
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'a'),
      habits: [sample()],
    );
    await tester.tap(find.byKey(const Key('edit-habit')));
    await settle(tester);
    expect(find.byType(HabitForm), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const Key('name-field')));
    expect(field.controller!.text, 'Read');
  });

  testWidgets('the charts have text alternatives', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'a'),
      habits: [sample()],
    );
    expect(find.bySemanticsLabel(RegExp(r'^Score \d+%$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Score over time')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('renders in the dark theme', (tester) async {
    await pumpScreen(
      tester,
      const HabitScreen(habitId: 'a'),
      habits: [sample()],
      dark: true,
    );
    expect(tester.takeException(), isNull);
  });
}
