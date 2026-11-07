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

  /// Returns [] on missing or corrupt data. Corrupt data is all-or-nothing:
  /// the first bad copy is kept under `habits_corrupt` and `habits` is cleared.
  List<Habit> load() {
    final raw = _prefs.get(_key);
    if (raw == null) return [];
    try {
      final habits = [
        for (final e in jsonDecode(raw as String) as List)
          Habit.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
      final ids = habits.map((h) => h.id).toSet();
      if (ids.length != habits.length || !habits.every(habitLooksValid)) {
        throw const FormatException('invalid habits');
      }
      return habits;
    } catch (e) {
      // shortcut: fire-and-forget writes; in-memory prefs update synchronously.
      if (!_prefs.containsKey(_corruptKey)) {
        _prefs.setString(_corruptKey, raw is String ? raw : raw.toString());
      }
      _prefs.remove(_key);
      return [];
    }
  }

  Future<void> save(List<Habit> habits) async {
    await _prefs.setString(
      _key,
      jsonEncode(habits.map((h) => h.toJson()).toList()),
    );
  }
}
