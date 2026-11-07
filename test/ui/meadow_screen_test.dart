import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/meadow_painter.dart';
import 'package:garden/ui/meadow_screen.dart';
import 'package:garden/ui/motion.dart';
import 'package:garden/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _today = 20000;
const _full =
    "Your garden is full for now. You can remove a flower you've finished "
    'with to make room.';

Habit _h(String id) => Habit.newSeed(
  id: id,
  name: 'Habit $id',
  flowerId: 'tulip',
  schedule: const Schedule.daily(),
  today: _today,
);

Future<void> _pump(
  WidgetTester tester,
  int n, {
  bool disableAnimations = false,
  void Function(String)? onOpen,
  VoidCallback? onPlant,
  int Function()? today,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = HabitStore(prefs);
  await store.save([for (var i = 0; i < n; i++) _h('h$i')]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitStoreProvider.overrideWithValue(store),
        todayProvider.overrideWithValue(today ?? () => _today),
      ],
      child: MaterialApp(
        theme: gardenTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: MeadowScreen(
          onOpenHabit: onOpen ?? (_) {},
          onPlant: onPlant ?? () {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('empty state invites the first seed', (tester) async {
    await _pump(tester, 0);
    expect(
      find.text('Your meadow is waiting. Plant your first seed.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('plant-button')), findsOneWidget);
  });

  testWidgets('three flowers, tap opens habit', (tester) async {
    String? opened;
    await _pump(tester, 3, onOpen: (id) => opened = id);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('flower-h$i')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('flower-h1')));
    expect(opened, 'h1');
  });

  testWidgets('full garden shows snackbar and does not plant', (tester) async {
    var planted = 0;
    await _pump(tester, 8, onPlant: () => planted++);
    await tester.tap(find.byKey(const Key('plant-button')));
    await tester.pump();
    expect(find.text(_full), findsOneWidget);
    expect(planted, 0);
  });

  testWidgets('plant button calls onPlant under the cap', (tester) async {
    var planted = 0;
    await _pump(tester, 7, onPlant: () => planted++);
    await tester.tap(find.byKey(const Key('plant-button')));
    expect(planted, 1);
  });

  testWidgets('insects only when animations are enabled', (tester) async {
    await _pump(tester, 2, disableAnimations: true);
    expect(find.byKey(const Key('insect')), findsNothing);
    await _pump(tester, 2);
    expect(find.byKey(const Key('insect')), findsWidgets);
  });

  testWidgets('flower layout is identical across builds', (tester) async {
    await _pump(tester, 3);
    final a = tester.getTopLeft(find.byKey(const ValueKey('flower-h2')));
    await _pump(tester, 3);
    expect(tester.getTopLeft(find.byKey(const ValueKey('flower-h2'))), a);
  });

  test('flowerPosition is pure, id-dependent and in the lower band', () {
    final a = flowerPosition('abc', 0, 800, 600);
    expect(flowerPosition('abc', 0, 800, 600), a);
    expect(flowerPosition('abd', 0, 800, 600), isNot(a));
    for (var i = 0; i < 8; i++) {
      final p = flowerPosition('id$i', i, 1200, 600);
      expect(p.dx, inInclusiveRange(0, 1200));
      expect(p.dy, inInclusiveRange(600 * 0.4, 600));
    }
  });

  testWidgets('platform Reduce Motion counts as reduced motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester, 2);
    final context = tester.element(find.byType(MeadowScreen));
    expect(MediaQuery.disableAnimationsOf(context), isFalse);
    expect(reduceMotion(context), isTrue);
    expect(find.byKey(const Key('insect')), findsNothing);
  });

  testWidgets('each flower reads its name, stage and health; tap opens it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    String? opened;
    await _pump(tester, 2, onOpen: (id) => opened = id);
    tester.semantics.tap(find.semantics.byLabel('Habit h1, seed, healthy'));
    expect(opened, 'h1');
    handle.dispose();
  });

  testWidgets('coming back to the app moves the garden to the new day', (
    tester,
  ) async {
    var day = _today;
    await _pump(tester, 1, today: () => day);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(MeadowScreen)),
    );
    expect(c.read(gardenProvider).single.evaluatedDay, _today);
    day = _today + 5;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    final h = c.read(gardenProvider).single;
    expect(h.evaluatedDay, _today + 5);
    expect(h.missedSinceWater, 4);
  });

  testWidgets('turning on Reduce Motion while open stops the insects', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester, 2);
    expect(find.byKey(const Key('insect')), findsWidgets);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    expect(find.byKey(const Key('insect')), findsNothing);
  });
}
