import 'schedule.dart';
import 'stats.dart';

/// Everything the tracker needs to know about a habit. History is the log,
/// never stored on the habit.
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

  /// Minutes after midnight, or null for no reminder.
  final int? reminderMinutes;

  /// A yes/no habit: target 1, at least.
  bool get isYesNo => goal.target == 1 && !goal.atMost;
}

/// A habit with its history (day index -> logged value).
class Tracked {
  const Tracked(this.config, this.log);

  final HabitConfig config;
  final Map<int, num> log;

  Stats stats(int today) => computeStats(
    schedule: config.schedule,
    createdDay: config.createdDay,
    log: log,
    today: today,
    goal: config.goal,
  );
}
