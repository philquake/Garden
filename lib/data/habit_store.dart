import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/habit.dart';

const _key = 'habits';
const _corruptKey = 'habits_corrupt';

/// Typed-but-nonsense values count as corrupt data.
bool habitLooksValid(Habit h) =>
    h.declineStep >= 0 &&
    h.declineStep <= 3 &&
    h.evaluatedDay >= h.plantedDay &&
    h.plantingWaterings >= 0 &&
    h.missedSinceWater >= 0 &&
    h.reminderBaselineMissed >= 0;

class HabitStore {
  HabitStore(this._prefs);
  final SharedPreferences _prefs;

  /// Returns the readable habits. Unreadable ones are skipped (one bad habit
  /// must not hide the rest), and the raw data is kept once under
  /// `habits_corrupt`. If the whole value is unreadable, `habits` is cleared.
  List<Habit> load() {
    final raw = _prefs.get(_key);
    if (raw == null) return [];
    final List<dynamic> items;
    try {
      items = jsonDecode(raw as String) as List<dynamic>;
    } catch (e) {
      _setAside(raw);
      _prefs.remove(_key);
      return [];
    }
    final habits = <Habit>[];
    final ids = <String>{};
    var skipped = false;
    for (final e in items) {
      try {
        final h = Habit.fromJson(Map<String, dynamic>.from(e as Map));
        if (habitLooksValid(h) && ids.add(h.id)) {
          habits.add(h);
          continue;
        }
      } catch (_) {}
      skipped = true;
    }
    if (skipped) _setAside(raw);
    return habits;
  }

  // shortcut: fire-and-forget writes; in-memory prefs update synchronously.
  void _setAside(Object raw) {
    if (!_prefs.containsKey(_corruptKey)) {
      _prefs.setString(_corruptKey, raw is String ? raw : raw.toString());
    }
  }

  /// Throws if the write fails, so a change is never shown as saved when the
  /// disk refused it.
  Future<void> save(List<Habit> habits) async {
    final ok = await _prefs.setString(
      _key,
      jsonEncode(habits.map((h) => h.toJson()).toList()),
    );
    if (!ok) throw StateError('Could not save the garden');
  }
}
