import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Habit seed(String id, int today) => Habit.newSeed(
  id: id,
  name: id,
  flowerId: 'tulip',
  schedule: const Schedule.daily(),
  today: today,
);

Future<ProviderContainer> make(SharedPreferences prefs, int Function() today) {
  final c = ProviderContainer(
    overrides: [
      habitStoreProvider.overrideWithValue(HabitStore(prefs)),
      todayProvider.overrideWithValue(today),
    ],
  );
  addTearDown(c.dispose);
  return Future.value(c);
}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('ninth habit and duplicate id throw', () async {
    final c = await make(prefs, () => 20000);
    final g = c.read(gardenProvider.notifier);
    for (var i = 0; i < 8; i++) {
      await g.add(seed('h$i', 20000));
    }
    expect(() => g.add(seed('h9', 20000)), throwsStateError);
    expect(c.read(gardenProvider).length, 8);
    final c2 = await make(prefs, () => 20000);
    expect(
      () => c2.read(gardenProvider.notifier).add(seed('h0', 20000)),
      throwsStateError,
    );
  });

  test('water persists across containers', () async {
    var day = 20000;
    final c = await make(prefs, () => day);
    await c.read(gardenProvider.notifier).add(seed('a', day));
    await c.read(gardenProvider.notifier).water('a');
    final c2 = await make(prefs, () => day);
    expect(c2.read(gardenProvider).single.wateredDays, {20000});
    expect(
      () => c2.read(gardenProvider.notifier).water('zzz'),
      throwsStateError,
    );
  });

  test('refresh with clock moved backwards changes nothing', () async {
    var day = 20010;
    final c = await make(prefs, () => day);
    await c.read(gardenProvider.notifier).add(seed('a', day));
    day = 20003;
    final before = c.read(gardenProvider).single.toJson();
    await c.read(gardenProvider.notifier).refresh();
    expect(c.read(gardenProvider).single.toJson(), before);
  });

  test('40 days later the habit is lost with wateredDays intact', () async {
    final c = await make(prefs, () => 20000);
    await c.read(gardenProvider.notifier).add(seed('a', 20000));
    await c.read(gardenProvider.notifier).water('a');
    final c2 = await make(prefs, () => 20040);
    final h = c2.read(gardenProvider).single;
    expect(h.lost, isTrue);
    expect(h.wateredDays, {20000});
  });

  test('editDetails changes name, flower, reminder; validates', () async {
    final c = await make(prefs, () => 20000);
    final g = c.read(gardenProvider.notifier);
    await g.add(seed('a', 20000));
    await g.editDetails('a', name: '  Read  ', flowerId: 'daisy');
    var h = c.read(gardenProvider).single;
    expect([h.name, h.flowerId, h.reminderMinutes], ['Read', 'daisy', -1]);
    await g.editDetails('a', reminderMinutes: 540);
    h = c.read(gardenProvider).single;
    expect([h.name, h.reminderMinutes], ['Read', 540]);
    expect(HabitStore(prefs).load().single.reminderMinutes, 540);
    expect(() => g.editDetails('a', name: '  '), throwsArgumentError);
    expect(() => g.editDetails('zz', name: 'x'), throwsStateError);
  });
}
