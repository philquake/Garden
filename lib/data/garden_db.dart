import 'package:sqflite/sqflite.dart';

import '../domain/schedule.dart';
import '../domain/stats.dart';

/// Everything the tracker needs to know about a habit. History lives in the
/// completions table, never on the habit.
class HabitConfig {
  const HabitConfig({
    required this.id,
    required this.name,
    required this.flowerId,
    required this.schedule,
    required this.goal,
    required this.createdDay,
    this.unit = '',
    this.reminderMinutes,
  });

  final String id;
  final String name;
  final String flowerId;
  final Schedule schedule;
  final Goal goal;
  final String unit;
  final int createdDay;
  final int? reminderMinutes;

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'flower_id': flowerId,
    'kind': schedule.kind.name,
    'sched_value': schedule.value,
    'target': goal.target,
    'at_most': goal.atMost ? 1 : 0,
    'unit': unit,
    'created_day': createdDay,
    'reminder_minutes': reminderMinutes,
  };

  factory HabitConfig.fromRow(Map<String, Object?> r) => HabitConfig(
    id: r['id'] as String,
    name: r['name'] as String,
    flowerId: r['flower_id'] as String,
    schedule: Schedule.fromJson({
      'kind': r['kind'],
      'n': r['sched_value'],
      'weekday': r['sched_value'],
    }),
    goal: Goal(target: r['target'] as num, atMost: r['at_most'] == 1),
    unit: r['unit'] as String,
    createdDay: r['created_day'] as int,
    reminderMinutes: r['reminder_minutes'] as int?,
  );
}

class GardenDb {
  GardenDb._(this._db);
  final Database _db;

  /// [factory] and [path] are injected so tests can run in memory.
  static Future<GardenDb> open(DatabaseFactory factory, String path) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE habits (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              flower_id TEXT NOT NULL,
              kind TEXT NOT NULL,
              sched_value INTEGER NOT NULL,
              target REAL NOT NULL,
              at_most INTEGER NOT NULL,
              unit TEXT NOT NULL,
              created_day INTEGER NOT NULL,
              reminder_minutes INTEGER
            )''');
          await db.execute('''
            CREATE TABLE completions (
              habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
              day INTEGER NOT NULL,
              value REAL NOT NULL,
              note TEXT,
              PRIMARY KEY (habit_id, day)
            )''');
        },
      ),
    );
    return GardenDb._(db);
  }

  Future<void> close() => _db.close();

  Future<List<HabitConfig>> habits() async => [
    for (final r in await _db.query('habits', orderBy: 'rowid'))
      HabitConfig.fromRow(r),
  ];

  /// Insert or update. Replacing would cascade-delete the history, so update
  /// in place when the habit exists.
  Future<void> saveHabit(HabitConfig h) async {
    final row = h.toRow();
    final n = await _db.update('habits', row, where: 'id = ?', whereArgs: [h.id]);
    if (n == 0) await _db.insert('habits', row);
  }

  Future<void> removeHabit(String id) =>
      _db.delete('habits', where: 'id = ?', whereArgs: [id]);

  /// Day index -> logged value. A null [value] clears the day.
  Future<void> setValue(String habitId, int day, num? value) async {
    if (value == null) {
      await _db.delete(
        'completions',
        where: 'habit_id = ? AND day = ?',
        whereArgs: [habitId, day],
      );
      return;
    }
    await _db.insert('completions', {
      'habit_id': habitId,
      'day': day,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<int, num>> log(String habitId) async => {
    for (final r in await _db.query(
      'completions',
      where: 'habit_id = ?',
      whereArgs: [habitId],
    ))
      r['day'] as int: r['value'] as num,
  };
}
