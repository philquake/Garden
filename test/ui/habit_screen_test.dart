import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/neglect.dart' as neglect;
import 'package:garden/domain/schedule.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/state/water_random_provider.dart';
import 'package:garden/ui/habit_screen.dart';
import 'package:garden/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 20000 is a Friday, so the current week is today-4 .. today+2.
const _today = 20000;

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  bool nextBool() => true;
  @override
  int nextInt(int max) => 0;
}

class _Throwing extends GardenController {
  @override
  Future<void> water(String id, {int? forDay}) =>
      throw StateError('cannot water');

  @override
  Future<void> replant(String id) => throw StateError('cannot replant');

  @override
  Future<void> freshStart(String id) => throw StateError('cannot start');
}

Habit _seed({int plantedAgo = 0}) => Habit.newSeed(
  id: 'h1',
  name: 'Read',
  flowerId: 'tulip',
  schedule: const Schedule.daily(),
  today: _today - plantedAgo,
);

// Planted long ago, last watered 31 days back, so the garden marks it lost.
Habit _lost() => _seed(
  plantedAgo: 50,
).copyWith(wateredDays: {_today - 32, _today - 31}, lastWaterDay: _today - 31);

Future<void> _pump(
  WidgetTester tester,
  List<Habit> habits, {
  bool throwing = false,
  String id = 'h1',
  double random = 0.9,
  bool disableAnimations = false,
  VoidCallback? onEdit,
  bool pushed = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = HabitStore(await SharedPreferences.getInstance());
  await store.save(habits);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitStoreProvider.overrideWithValue(store),
        todayProvider.overrideWithValue(() => _today),
        waterRandomProvider.overrideWithValue(_FixedRandom(random)),
        if (throwing) gardenProvider.overrideWith(_Throwing.new),
      ],
      child: MaterialApp(
        theme: gardenTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: pushed
            ? Builder(
                builder: (context) => TextButton(
                  key: const Key('open'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HabitScreen(habitId: id, onEdit: () {}),
                    ),
                  ),
                  child: const Text('open'),
                ),
              )
            : HabitScreen(habitId: id, onEdit: onEdit ?? () {}),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

String _progress(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('week-progress'))).data!;

Future<void> _tapFlower(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('habit-flower')));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('tapping the flower waters once per day', (tester) async {
    await _pump(tester, [_seed()]);
    expect(_progress(tester), '0 of 7 this week');
    await _tapFlower(tester);
    expect(_progress(tester), '1 of 7 this week');
    await tester.pump(const Duration(seconds: 1));
    await _tapFlower(tester);
    expect(_progress(tester), '1 of 7 this week');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows name and schedule in words', (tester) async {
    await _pump(tester, [_seed()]);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
  });

  testWidgets('petal loss offers a fresh start, healthy does not', (
    tester,
  ) async {
    await _pump(tester, [_seed(plantedAgo: 10)]);
    expect(find.byKey(const Key('fresh-start-button')), findsOneWidget);
    expect(
      find.text(
        'Your flower comes back at the stage it had reached. '
        'Your history stays.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    await _tapVisible(tester, find.byKey(const Key('fresh-start-button')));
    expect(find.byKey(const Key('fresh-start-button')), findsNothing);
  });

  testWidgets('healthy habit has no fresh start', (tester) async {
    await _pump(tester, [_seed()]);
    expect(find.byKey(const Key('fresh-start-button')), findsNothing);
    expect(find.byKey(const Key('replant-button')), findsNothing);
  });

  testWidgets('lost habit: replant, history kept, tap does not water', (
    tester,
  ) async {
    await _pump(tester, [_lost()]);
    expect(find.byKey(const Key('replant-button')), findsOneWidget);
    expect(find.byKey(const Key('fresh-start-button')), findsNothing);
    expect(
      find.text('Your history stays exactly as it is.', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('watered-${_today - 32}'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('watered-${_today - 31}'), skipOffstage: false),
      findsOneWidget,
    );
    final before = _progress(tester);
    await _tapFlower(tester);
    expect(_progress(tester), before);
    expect(find.byKey(const Key('water-visitor')), findsNothing);
    await _tapVisible(tester, find.byKey(const Key('replant-button')));
    expect(find.byKey(const Key('replant-button')), findsNothing);
    expect(
      find.byKey(Key('watered-${_today - 31}'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('exactly the last three unwatered days can be back-filled', (
    tester,
  ) async {
    await _pump(tester, [_seed(plantedAgo: 20)]);
    for (var d = _today - 3; d < _today; d++) {
      expect(
        find.byKey(Key('backfill-$d'), skipOffstage: false),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(Key('backfill-${_today - 4}'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(Key('backfill-$_today'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w.key.toString().contains('backfill-'),
        skipOffstage: false,
      ),
      findsNWidgets(3),
    );
    expect(_progress(tester), '0 of 7 this week');
    await _tapVisible(tester, find.byKey(Key('backfill-${_today - 1}')));
    expect(_progress(tester), '1 of 7 this week');
    expect(
      find.byKey(Key('backfill-${_today - 1}'), skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('missing habit shows a gentle message', (tester) async {
    await _pump(tester, [_seed()], id: 'gone');
    expect(
      find.text('This flower is no longer in your garden.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('back-button')), findsOneWidget);
  });

  testWidgets('visitor appears with a low roll', (tester) async {
    await _pump(tester, [_seed()], random: 0.1);
    await _tapFlower(tester);
    expect(find.byKey(const Key('water-visitor')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('water-visitor')), findsNothing);
  });

  testWidgets('no visitor with a high roll', (tester) async {
    await _pump(tester, [_seed()], random: 0.9);
    await _tapFlower(tester);
    expect(find.byKey(const Key('water-visitor')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('reduced motion never shows a visitor', (tester) async {
    await _pump(tester, [_seed()], random: 0.1, disableAnimations: true);
    await _tapFlower(tester);
    expect(find.byKey(const Key('water-visitor')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  const gentle =
      "That didn't go through. Your garden has been refreshed, "
      'so please try again.';

  testWidgets('failed flower tap shows a gentle message', (tester) async {
    await _pump(tester, [_seed(plantedAgo: 20)], throwing: true);
    final before = _progress(tester);
    await _tapFlower(tester);
    expect(find.text(gentle), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(_progress(tester), before);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('failed back-fill tap shows a gentle message', (tester) async {
    await _pump(tester, [_seed(plantedAgo: 20)], throwing: true);
    final before = _progress(tester);
    await _tapVisible(tester, find.byKey(Key('backfill-${_today - 1}')));
    expect(find.text(gentle), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(_progress(tester), before);
  });

  testWidgets('back-fill cells are at least 44x44 on a phone', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, [_seed(plantedAgo: 20)]);
    for (var d = _today - 3; d < _today; d++) {
      final size = tester.getSize(
        find.byKey(Key('backfill-$d'), skipOffstage: false),
      );
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('flower and back-fill cells have semantic labels', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, [_seed(plantedAgo: 20)]);
    expect(find.bySemanticsLabel('Water Read'), findsOneWidget);
    // Day 19999 is a Thursday, 3 October 2024.
    expect(
      find.bySemanticsLabel('Mark Thursday, 3 October as watered'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('semantic tap on the flower waters it', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, [_seed(plantedAgo: 20)]);
    expect(_progress(tester), '0 of 7 this week');
    tester.semantics.tap(find.semantics.byLabel('Water Read'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_progress(tester), '1 of 7 this week');
    await tester.pump(const Duration(seconds: 1));
    handle.dispose();
  });

  testWidgets('semantic tap on a back-fill cell waters that day', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, [_seed(plantedAgo: 20)]);
    tester.semantics.tap(
      find.semantics.byLabel('Mark Thursday, 3 October as watered'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(Key('watered-${_today - 1}'), skipOffstage: false),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('failed replant shows a gentle message', (tester) async {
    await _pump(tester, [_lost()], throwing: true);
    await _tapVisible(tester, find.byKey(const Key('replant-button')));
    expect(find.text(gentle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed fresh start shows a gentle message', (tester) async {
    await _pump(tester, [_seed(plantedAgo: 10)], throwing: true);
    await _tapVisible(tester, find.byKey(const Key('fresh-start-button')));
    expect(find.text(gentle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit button calls onEdit', (tester) async {
    var edited = 0;
    await _pump(tester, [_seed()], onEdit: () => edited++);
    await _tapVisible(tester, find.byKey(const Key('edit-button')));
    expect(edited, 1);
  });

  group('paused reminders card', () {
    Habit missed({int reminder = 540, int days = 4}) => neglect.advance(
      Habit.newSeed(
        id: 'h1',
        name: 'Read',
        flowerId: 'tulip',
        schedule: const Schedule.daily(),
        today: _today - days,
        reminderMinutes: reminder,
      ),
      _today,
    );

    testWidgets('shows after 3 ignored reminders and opens edit', (
      tester,
    ) async {
      var edits = 0;
      final h = missed();
      expect(h.ignoredReminders, greaterThanOrEqualTo(3));
      await _pump(tester, [h], onEdit: () => edits++);
      expect(
        find.text('Reminders are paused for now. Want to pick a gentler time?'),
        findsOneWidget,
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('change-reminder-button')),
      );
      expect(edits, 1);
    });

    testWidgets('absent for a healthy habit', (tester) async {
      await _pump(tester, [_seed()]);
      expect(find.byKey(const Key('reminders-paused-card')), findsNothing);
    });

    testWidgets('absent when the habit has no reminder', (tester) async {
      await _pump(tester, [missed(reminder: -1)]);
      expect(find.byKey(const Key('reminders-paused-card')), findsNothing);
    });
  });

  testWidgets('back button pops the route, is 44px+ and labelled Back', (
    tester,
  ) async {
    await _pump(tester, [_seed()], pushed: true);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final back = find.byKey(const Key('habit-back-button'));
    final size = tester.getSize(back);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    await tester.tap(back);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HabitScreen), findsNothing);
    expect(find.byKey(const Key('open')), findsOneWidget);
  });

  group('loss warning card', () {
    const card = Key('loss-warning-card');
    // A weekly habit stays out of petal loss, so only the days dry matter.
    Habit weekly(int dryDays) => Habit.newSeed(
      id: 'h1',
      name: 'Swim',
      flowerId: 'Daisy',
      schedule: Schedule.weekday(1),
      today: _today - dryDays,
    );

    testWidgets('appears at day 14 with a working fresh start', (tester) async {
      await _pump(tester, [weekly(14)]);
      expect(find.byKey(card, skipOffstage: false), findsOneWidget);
      expect(
        find.textContaining(
          'Your daisy is waiting for you.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      final button = find.byKey(const Key('fresh-start-button'));
      expect(
        find.descendant(of: find.byKey(card), matching: button),
        findsOneWidget,
      );
      await _tapVisible(tester, button);
      expect(find.byKey(card, skipOffstage: false), findsNothing);
      expect(button, findsNothing);
    });

    testWidgets('absent at day 13 and when lost', (tester) async {
      await _pump(tester, [weekly(13)]);
      expect(find.byKey(card, skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('fresh-start-button')), findsNothing);
      await _pump(tester, [_lost()]);
      expect(find.byKey(card, skipOffstage: false), findsNothing);
    });

    testWidgets('gentler still from day 21; one button in petal loss', (
      tester,
    ) async {
      await _pump(tester, [weekly(21)]);
      expect(
        find.textContaining('There is still time.', skipOffstage: false),
        findsOneWidget,
      );
      await _pump(tester, [_seed(plantedAgo: 14)]);
      expect(
        find.byKey(const Key('fresh-start-button'), skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
