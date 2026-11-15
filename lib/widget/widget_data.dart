import 'dart:convert';

import '../domain/habit_config.dart';
import '../flower/look.dart';

/// What a home-screen tile shows for one habit. Same rules as the home card:
/// done means today's value meets the goal; stage comes from [lookOf].
class WidgetTile {
  const WidgetTile(this.id, this.name, this.flower, this.stage, this.done);

  final String id;
  final String name;
  final String flower;
  final int stage;
  final bool done;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'asset': '${flower}_$stage',
    'done': done,
  };
}

/// Tiles in the same order as the home screen.
List<WidgetTile> tilesOf(List<Tracked> habits, int today) => [
  for (final t in habits) _tile(t, today),
];

WidgetTile _tile(Tracked t, int today) {
  final c = t.config;
  final v = t.log[today];
  final done = v != null && c.goal.met(v);
  final look = lookOf(c.flowerId, t.stats(today), doneToday: done);
  return WidgetTile(c.id, c.name, look.kind, look.stage, done);
}

/// The JSON the native widgets read. `day` lets them ignore "done" after the
/// 03:00 rollover until the app next refreshes it.
String snapshotJson(List<Tracked> habits, int today) => jsonEncode({
  'day': today,
  'tiles': [for (final t in tilesOf(habits, today)) t.toJson()],
});

/// The value a tap on a habit logs for today: yes/no habits toggle, counting
/// habits add 1. Null clears the day.
num? tapValue(HabitConfig c, num? current) =>
    c.isYesNo ? (current == null ? 1 : null) : (current ?? 0) + 1;
