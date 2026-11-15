import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/flower/flower_view.dart';
import 'package:garden/flower/look.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/habit_form.dart';
import 'package:garden/ui/habit_screen.dart';
import 'package:garden/ui/meadow_screen.dart';
import 'package:garden/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _today = 20000; // a Friday

Habit _h(String id, {Set<int> watered = const {}, int plantedAgo = 0}) =>
    Habit.newSeed(
      id: id,
      name: 'Habit $id',
      flowerId: 'tulip',
      schedule: const Schedule.daily(),
      today: _today - plantedAgo,
    ).copyWith(wateredDays: watered);

// Last watered 31 days back, so the garden marks it lost.
Habit _lost() => _h(
  'h1',
  plantedAgo: 50,
  watered: {_today - 31},
).copyWith(lastWaterDay: _today - 31);

Future<void> _pump(WidgetTester tester, List<Habit> habits, Widget home) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = HabitStore(await SharedPreferences.getInstance());
  await store.save(habits);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitStoreProvider.overrideWithValue(store),
        todayProvider.overrideWithValue(() => _today),
      ],
      child: MaterialApp(theme: gardenTheme(), home: home),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

FlowerView _view(WidgetTester tester, Key within) => tester.widget<FlowerView>(
  find.descendant(of: find.byKey(within), matching: find.byType(FlowerView)),
);

List<String> _haptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

void main() {
  group('meadow', () {
    final meadow = MeadowScreen(onOpenHabit: (_) {}, onPlant: () {});

    testWidgets('draws each habit as a live flower, with no images', (
      tester,
    ) async {
      await _pump(tester, [_h('a'), _h('b')], meadow);
      for (final id in ['a', 'b']) {
        expect(_view(tester, ValueKey('flower-$id')).look.kind, 'tulip');
      }
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a flower due today says so; a watered one does not', (
      tester,
    ) async {
      await _pump(tester, [
        _h('a'),
        _h('b', watered: {_today}),
      ], meadow);
      expect(_view(tester, const ValueKey('flower-a')).look.bubble, isTrue);
      expect(_view(tester, const ValueKey('flower-b')).look.bubble, isFalse);
      expect(
        find.bySemanticsLabel('Habit a, seed, healthy, needs water today'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Habit b, seed, healthy'), findsOneWidget);
    });

    testWidgets('a lost flower is a faded seed', (tester) async {
      await _pump(tester, [_lost()], meadow);
      final look = _view(tester, const ValueKey('flower-h1')).look;
      expect((look.faded, look.stage, look.face), (true, 0, Face.asleep));
      expect(find.bySemanticsLabel('Habit h1, seed, resting'), findsOneWidget);
    });
  });

  group('habit screen', () {
    const key = Key('habit-flower');
    Widget screen() => HabitScreen(habitId: 'h1', onEdit: () {});

    testWidgets('shows the flower large', (tester) async {
      await _pump(tester, [_h('h1')], screen());
      expect(_view(tester, key).size, 240);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('each tap delights the flower with one light tick', (
      tester,
    ) async {
      final haptics = _haptics(tester);
      await _pump(tester, [_h('h1')], screen());
      final before = _view(tester, key).delightTrigger;
      await tester.tap(find.byKey(key));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_view(tester, key).delightTrigger, before + 1);
      expect(_view(tester, key).look.bubble, isFalse);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await tester.pump(const Duration(seconds: 2));
      // An already-watered flower still reacts.
      await tester.tap(find.byKey(key));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_view(tester, key).delightTrigger, before + 2);
      expect(haptics.length, 2);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a lost flower does not react', (tester) async {
      final haptics = _haptics(tester);
      await _pump(tester, [_lost()], screen());
      final before = _view(tester, key).delightTrigger;
      await tester.tap(find.byKey(key));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_view(tester, key).delightTrigger, before);
      expect(haptics, isEmpty);
    });

    testWidgets('back-filling a day does not delight or tick', (tester) async {
      final haptics = _haptics(tester);
      await _pump(tester, [_h('h1', plantedAgo: 5)], screen());
      final before = _view(tester, key).delightTrigger;
      final cell = find.byKey(const ValueKey('backfill-${_today - 1}'));
      await tester.ensureVisible(cell);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(cell);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey('watered-${_today - 1}')),
        findsOneWidget,
      );
      expect(_view(tester, key).delightTrigger, before);
      expect(haptics, isEmpty);
    });
  });

  group('form', () {
    testWidgets('offers the four kinds as happy full blooms, tulip first', (
      tester,
    ) async {
      await _pump(tester, const [], const HabitForm());
      for (final kind in flowerKinds) {
        final view = _view(tester, Key('flower-choice-$kind'));
        expect(view.look, pickerLook(kind));
        expect(view.size, 64);
      }
      expect(find.byType(Image), findsNothing);
    });
  });
}
