import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/messages.dart';
import 'package:garden/domain/neglect.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/meadow_screen.dart';
import 'package:garden/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _banner = Key('encouragement-banner');
const _dismiss = Key('dismiss-banner');

/// A daily habit planted [daysAgo] days before [today], advanced to [today].
Habit _seed(String id, int today, int daysAgo, {String flower = 'Tulip'}) =>
    advance(
      Habit.newSeed(
        id: id,
        name: 'Habit $id',
        flowerId: flower,
        schedule: const Schedule.daily(),
        today: today - daysAgo,
      ),
      today,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<Habit> habits, {
  int today = 20000,
  void Function(String)? onOpen,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = HabitStore(prefs);
  await store.save(habits);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitStoreProvider.overrideWithValue(store),
        todayProvider.overrideWithValue(() => today),
      ],
      child: MaterialApp(
        theme: gardenTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: MeadowScreen(onOpenHabit: onOpen ?? (_) {}, onPlant: () {}),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return ProviderScope.containerOf(tester.element(find.byType(MeadowScreen)));
}

void main() {
  testWidgets('hidden with no habits and with only two misses', (tester) async {
    await _pump(tester, []);
    expect(find.byKey(_banner), findsNothing);
    await _pump(tester, [_seed('a', 20000, 3)]);
    expect(find.byKey(_banner), findsNothing);
  });

  testWidgets('visible with three misses, text follows day parity', (
    tester,
  ) async {
    await _pump(tester, [_seed('a', 20000, 4)], today: 20000);
    expect(find.byKey(_banner), findsOneWidget);
    expect(find.text(encouragement(Tone.warm, 20000)), findsOneWidget);
    await _pump(tester, [_seed('a', 20001, 4)], today: 20001);
    expect(find.text(encouragement(Tone.smallStep, 20001)), findsOneWidget);
  });

  testWidgets('dismiss hides it and it stays hidden after updates', (
    tester,
  ) async {
    final c = await _pump(tester, [_seed('a', 20000, 4)]);
    await tester.tap(find.byKey(_dismiss));
    await tester.pump();
    expect(find.byKey(_banner), findsNothing);
    await c.read(gardenProvider.notifier).water('a');
    await c.read(gardenProvider.notifier).refresh();
    await tester.pump();
    expect(find.byKey(_banner), findsNothing);
  });

  testWidgets('dismiss control is at least 44x44 and does not block plant', (
    tester,
  ) async {
    await _pump(tester, [_seed('a', 20000, 4)]);
    final size = tester.getSize(find.byKey(_dismiss));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(
      tester
          .getRect(find.byKey(_banner))
          .overlaps(tester.getRect(find.byKey(const Key('plant-button')))),
      isFalse,
    );
  });

  testWidgets('petal-loss habit shows freshStart banner that opens it', (
    tester,
  ) async {
    String? opened;
    final h = _seed('rose1', 20000, 10, flower: 'Rose');
    expect(h.declineStep, 3);
    await _pump(tester, [h], onOpen: (id) => opened = id);
    expect(find.byKey(_banner), findsOneWidget);
    expect(
      find.text(encouragement(Tone.freshStart, 20000, flower: 'rose')),
      findsOneWidget,
    );
    expect(find.textContaining('your rose'), findsOneWidget);
    await tester.tap(find.byKey(_banner));
    expect(opened, 'rose1');
  });

  testWidgets('semantic activation of dismiss and freshStart banner', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    String? opened;
    final h = _seed('rose1', 20000, 10, flower: 'Rose');
    await _pump(tester, [h], onOpen: (id) => opened = id);
    tester.semantics.tap(
      find.semantics.byLabel(
        encouragement(Tone.freshStart, 20000, flower: 'rose'),
      ),
    );
    expect(opened, 'rose1');
    tester.semantics.tap(find.semantics.byLabel('Dismiss message'));
    await tester.pump();
    expect(find.byKey(_banner), findsNothing);
    handle.dispose();
  });
}
