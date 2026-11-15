import 'package:sqflite/sqflite.dart';

import '../domain/habit_config.dart';
import '../domain/schedule.dart';
import '../domain/stats.dart';

Map<String, Object?> _toRow(HabitConfig h) => {
  'id': h.id,
  'name': h.name,
  'flower_id': h.flowerId,
  'kind': h.schedule.kind.name,
  'sched_value': h.schedule.value,
  'target': h.goal.target,
  'at_most': h.goal.atMost ? 1 : 0,
  'unit': h.unit,
  'created_day': h.createdDay,
  'reminder_minutes': h.reminderMinutes,
};

HabitConfig _fromRow(Map<String, Object?> r) => HabitConfig(
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

  /// Every habit with its full history, in creation order.
  Future<List<Tracked>> loadAll() async => [
    for (final h in await habits()) Tracked(h, await log(h.id)),
  ];

  Future<List<HabitConfig>> habits() async => [
    for (final r in await _db.query('habits', orderBy: 'rowid')) _fromRow(r),
  ];

  /// Insert or update. Replacing would cascade-delete the history, so update
  /// in place when the habit exists.
  Future<void> saveHabit(HabitConfig h) async {
    final row = _toRow(h);
    final n = await _db.update(
      'habits',
      row,
      where: 'id = ?',
      whereArgs: [h.id],
    );
    if (n == 0) await _db.insert('habits', row);
  }

  /// Swaps the whole garden for [all] in one transaction: either everything
  /// is replaced or, if anything fails, nothing is.
  Future<void> replaceAll(List<Tracked> all) => _db.transaction((txn) async {
    await txn.delete('completions');
    await txn.delete('habits');
    for (final t in all) {
      await txn.insert('habits', _toRow(t.config));
      for (final e in t.log.entries) {
        await txn.insert('completions', {
          'habit_id': t.config.id,
          'day': e.key,
          'value': e.value,
        });
      }
    }
  });

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
