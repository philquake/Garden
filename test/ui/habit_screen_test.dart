import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/domain/habit.dart';
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
        home: HabitScreen(habitId: id, onEdit: onEdit ?? () {}),
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
    addTearDown(handle.dispose);
    await _pump(tester, [_seed(plantedAgo: 20)]);
    expect(find.bySemanticsLabel('Water Read'), findsOneWidget);
    // Day 19999 is a Thursday, 3 October 2024.
    expect(
      find.bySemanticsLabel('Mark Thursday, 3 October as watered'),
      findsOneWidget,
    );
  });

  testWidgets('edit button calls onEdit', (tester) async {
    var edited = 0;
    await _pump(tester, [_seed()], onEdit: () => edited++);
    await _tapVisible(tester, find.byKey(const Key('edit-button')));
    expect(edited, 1);
  });
}
