import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/habit_store.dart';
import '../domain/actions.dart' as actions;
import '../domain/day.dart';
import '../domain/habit.dart';
import '../domain/neglect.dart';
import '../domain/reminders.dart';
import '../domain/rules.dart';
import '../domain/schedule.dart';

final habitStoreProvider = Provider<HabitStore>(
  (ref) => throw UnimplementedError('override habitStoreProvider'),
);

final todayProvider = Provider<int Function()>(
  (ref) =>
      () => dayIndex(DateTime.now()),
);

final gardenProvider = NotifierProvider<GardenController, List<Habit>>(
  GardenController.new,
);

class GardenController extends Notifier<List<Habit>> {
  HabitStore get _store => ref.read(habitStoreProvider);
  int get _today => ref.read(todayProvider)();

  @override
  List<Habit> build() {
    final today = _today;
    return [
      for (final h in _store.load()) syncIgnoredReminders(advance(h, today)),
    ];
  }

  Future<void> _set(List<Habit> habits) async {
    final synced = [for (final h in habits) syncIgnoredReminders(h)];
    state = synced;
    await _store.save(synced);
  }

  Future<void> _update(String id, Habit Function(Habit h, int today) f) {
    final i = state.indexWhere((h) => h.id == id);
    if (i < 0) throw StateError('No habit $id');
    final next = f(state[i], _today);
    return _set([...state]..[i] = next);
  }

  Future<void> add(Habit h) {
    if (state.length >= Rules.habitCap) {
      throw StateError('Garden is full (${Rules.habitCap})');
    }
    if (state.any((e) => e.id == h.id)) {
      throw StateError('Duplicate habit id ${h.id}');
    }
    return _set([...state, h]);
  }

  /// Takes the habit and its history out of the garden for good.
  Future<void> remove(String id) {
    if (!state.any((h) => h.id == id)) throw StateError('No habit $id');
    return _set([
      for (final h in state)
        if (h.id != id) h,
    ]);
  }

  Future<void> water(String id, {int? forDay}) =>
      _update(id, (h, t) => actions.water(h, t, forDay: forDay));

  Future<void> editSchedule(String id, Schedule s) =>
      _update(id, (h, t) => actions.editSchedule(h, s, t));

  Future<void> editDetails(
    String id, {
    String? name,
    String? flowerId,
    int? reminderMinutes,
  }) {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    return _update(
      id,
      (h, t) => h.copyWith(
        name: trimmed,
        flowerId: flowerId,
        reminderMinutes: reminderMinutes,
        // A new or changed reminder starts its ignored count afresh.
        reminderBaselineMissed:
            reminderMinutes != null && reminderMinutes != h.reminderMinutes
            ? advance(h, t).missedSinceWater
            : null,
      ),
    );
  }

  Future<void> freshStart(String id) => _update(id, actions.freshStart);

  Future<void> replant(String id) => _update(id, actions.replant);

  Future<void> refresh() async {
    final today = _today;
    final next = [
      for (final h in state) syncIgnoredReminders(advance(h, today)),
    ];
    var changed = false;
    for (var i = 0; i < next.length; i++) {
      if (!identical(next[i], state[i])) changed = true;
    }
    if (changed) await _set(next);
  }
}
