import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../data/garden_db.dart';
import '../domain/day.dart';
import '../domain/habit_config.dart';
import '../purchases/purchases.dart';

final gardenDbProvider = Provider<GardenDb>(
  (ref) => throw UnimplementedError('override gardenDbProvider'),
);

/// Habits and history read once before the app starts.
final initialHabitsProvider = Provider<List<Tracked>>(
  (ref) => throw UnimplementedError('override initialHabitsProvider'),
);

/// The current day index (03:00 rollover). Tests override [build].
final todayProvider = NotifierProvider<Today, int>(Today.new);

class Today extends Notifier<int> {
  @override
  int build() => dayIndex(DateTime.now());

  /// Call when the app returns to the foreground: the day may have changed.
  void refresh() => state = dayIndex(DateTime.now());
}

final gardenProvider = NotifierProvider<GardenController, List<Tracked>>(
  GardenController.new,
);

class GardenController extends Notifier<List<Tracked>> {
  GardenDb get _db => ref.read(gardenDbProvider);

  @override
  List<Tracked> build() => ref.read(initialHabitsProvider);

  /// Updates state first, then the database; a failed write is rolled back.
  Future<void> _apply(List<Tracked> next, Future<void> Function() write) async {
    final before = state;
    state = next;
    try {
      await write();
    } catch (_) {
      state = before;
      rethrow;
    }
  }

  Tracked _find(String id) {
    final t = state.where((t) => t.config.id == id).firstOrNull;
    if (t == null) throw StateError('No habit $id');
    return t;
  }

  Future<void> add(HabitConfig c) async {
    if (state.any((t) => t.config.id == c.id)) {
      throw StateError('Duplicate habit id ${c.id}');
    }
    _validate(c);
    if (state.length >= freeHabitLimit && !ref.read(unlockedProvider)) {
      throw const FreeLimitReached();
    }
    await _apply([...state, Tracked(c, const {})], () => _db.saveHabit(c));
    if (ref.mounted) {
      ref.read(analyticsProvider).track(AnalyticsEvent.habitCreated);
    }
  }

  /// Replaces the settings, keeping the history. The creation day is fixed.
  Future<void> update(HabitConfig c) {
    final old = _find(c.id);
    _validate(c);
    final kept = HabitConfig(
      id: c.id,
      name: c.name,
      flowerId: c.flowerId,
      schedule: c.schedule,
      goal: c.goal,
      unit: c.unit,
      createdDay: old.config.createdDay,
      reminderMinutes: c.reminderMinutes,
    );
    return _apply([
      for (final t in state)
        if (t.config.id == c.id) Tracked(kept, t.log) else t,
    ], () => _db.saveHabit(kept));
  }

  /// Replaces the whole garden (restoring a backup). Free-tier limits are not
  /// applied here: the restore itself is behind the unlock.
  Future<void> replaceAll(List<Tracked> all) =>
      _apply(all, () => _db.replaceAll(all));

  /// Removes the habit and all its history for good.
  Future<void> remove(String id) {
    _find(id);
    return _apply([
      for (final t in state)
        if (t.config.id != id) t,
    ], () => _db.removeHabit(id));
  }

  /// Logs [value] for [day]; null clears the day. Any day from the habit's
  /// creation up to today can be edited.
  Future<void> setValue(String id, int day, num? value) async {
    final t = _find(id);
    final today = ref.read(todayProvider);
    if (day < t.config.createdDay || day > today) {
      throw ArgumentError.value(day, 'day', 'outside creation..today');
    }
    if (value != null && value < 0) {
      throw ArgumentError.value(value, 'value', 'must not be negative');
    }
    final log = {...t.log};
    value == null ? log.remove(day) : log[day] = value;
    await _apply([
      for (final e in state)
        if (e.config.id == id) Tracked(e.config, log) else e,
    ], () => _db.setValue(id, day, value));
    if (value != null && ref.mounted) {
      ref.read(analyticsProvider).trackOnce(AnalyticsEvent.firstCompletion);
    }
  }

  /// Yes/no habits toggle; numeric habits add 1 (the card's quick tap).
  Future<void> tap(String id) {
    final t = _find(id);
    final today = ref.read(todayProvider);
    final now = t.log[today];
    if (t.config.isYesNo) return setValue(id, today, now == null ? 1 : null);
    return setValue(id, today, (now ?? 0) + 1);
  }

  void _validate(HabitConfig c) {
    if (c.name.trim().isEmpty) {
      throw ArgumentError.value(c.name, 'name', 'must not be empty');
    }
    if (c.goal.target <= 0 && !c.goal.atMost) {
      throw ArgumentError.value(c.goal.target, 'target', 'must be positive');
    }
  }
}
