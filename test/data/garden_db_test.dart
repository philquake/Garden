import 'package:flutter_test/flutter_test.dart';
import 'package:garden/data/garden_db.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/stats.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

HabitConfig sample({String id = 'h1'}) => HabitConfig(
  id: id,
  name: 'Drink water',
  flowerId: 'tulip',
  schedule: Schedule.timesPerWeek(5),
  goal: const Goal(target: 8, atMost: false),
  unit: 'glasses',
  createdDay: 100,
  reminderMinutes: 540,
);

void main() {
  sqfliteFfiInit();
  late GardenDb db;

  setUp(() async {
    db = await GardenDb.open(databaseFactoryFfi, inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  test('saves and reads habits back unchanged', () async {
    await db.saveHabit(sample());
    final back = (await db.habits()).single;
    expect(back.name, 'Drink water');
    expect(back.schedule, Schedule.timesPerWeek(5));
    expect(back.goal.target, 8);
    expect(back.goal.atMost, isFalse);
    expect(back.unit, 'glasses');
    expect(back.createdDay, 100);
    expect(back.reminderMinutes, 540);
  });

  test('saving again updates the habit instead of duplicating it', () async {
    await db.saveHabit(sample());
    await db.saveHabit(
      HabitConfig(
        id: 'h1',
        name: 'Water',
        flowerId: 'tulip',
        schedule: const Schedule.daily(),
        goal: const Goal(),
        createdDay: 100,
      ),
    );
    final all = await db.habits();
    expect(all, hasLength(1));
    expect(all.single.name, 'Water');
    expect(all.single.reminderMinutes, isNull);
  });

  test('setValue upserts and null clears the day', () async {
    await db.saveHabit(sample());
    await db.setValue('h1', 101, 3);
    await db.setValue('h1', 101, 8);
    await db.setValue('h1', 102, 1);
    expect(await db.log('h1'), {101: 8, 102: 1});
    await db.setValue('h1', 101, null);
    expect(await db.log('h1'), {102: 1});
  });

  test('removing a habit removes its history', () async {
    await db.saveHabit(sample());
    await db.setValue('h1', 101, 1);
    await db.removeHabit('h1');
    expect(await db.habits(), isEmpty);
    expect(await db.log('h1'), isEmpty);
  });

  test('histories of different habits stay apart', () async {
    await db.saveHabit(sample());
    await db.saveHabit(sample(id: 'h2'));
    await db.setValue('h1', 101, 1);
    expect(await db.log('h2'), isEmpty);
  });
}
