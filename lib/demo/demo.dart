import 'dart:math';

import '../domain/day.dart';
import '../domain/habit_config.dart';
import '../domain/schedule.dart';
import '../domain/stats.dart';
import '../purchases/purchases.dart';

/// Run with `--dart-define=DEMO=true` to start on sample habits (in their own
/// database file, so real data is never touched) with the unlock switched on.
const demoMode = bool.fromEnvironment('DEMO');

/// Pretends the one-time unlock is owned, so the demo can show every plant,
/// chart and the export.
class DemoPurchases implements Purchases {
  const DemoPurchases();

  @override
  Future<bool> isUnlocked() async => true;

  @override
  String get priceLabel => fallbackPrice;

  @override
  Future<PurchaseResult> buy() async => PurchaseResult.unlocked;

  @override
  Future<bool> restore() async => true;
}

/// Ten sample habits whose plants sit at different growth stages: some
/// formed, some young, one neglected, one that missed a day or two.
List<Tracked> demoHabits(int today) {
  Tracked make({
    required String id,
    required String name,
    required String plant,
    required int ago,
    required double rate,
    Schedule schedule = const Schedule.daily(),
    Goal goal = const Goal(),
    String unit = '',
    int stoppedAgo = 0,
    bool doneToday = true,
    int seed = 1,
  }) {
    final rnd = Random(seed);
    final created = today - ago;
    final last = today - stoppedAgo;
    final log = <int, num>{};
    for (var d = created; d <= last; d++) {
      if (d == today && !doneToday) continue;
      final onSchedule = switch (schedule.kind) {
        ScheduleKind.daily => true,
        ScheduleKind.weekday => weekdayOf(d) == schedule.value,
        ScheduleKind.timesPerWeek => rnd.nextDouble() < schedule.value / 7,
      };
      if (!onSchedule || rnd.nextDouble() > rate) continue;
      if (goal.target == 1 && !goal.atMost) {
        log[d] = 1;
      } else if (goal.atMost) {
        log[d] = rnd.nextInt(goal.target.toInt() + 2);
      } else {
        final t = goal.target.toInt();
        log[d] = max(1, t - rnd.nextInt(3) + (rnd.nextBool() ? 0 : 1));
      }
    }
    return Tracked(
      HabitConfig(
        id: id,
        name: name,
        flowerId: plant,
        schedule: schedule,
        goal: goal,
        unit: unit,
        createdDay: created,
      ),
      log,
    );
  }

  return [
    make(id: 'd1', name: 'Morning run', plant: 'tulip', ago: 80, rate: 0.97),
    make(
      id: 'd2',
      name: 'Drink water',
      plant: 'sunflower',
      ago: 52,
      rate: 0.9,
      goal: const Goal(target: 8),
      unit: 'glasses',
      seed: 2,
    ),
    make(
      id: 'd3',
      name: 'Meditate',
      plant: 'lavender',
      ago: 41,
      rate: 0.93,
      seed: 3,
    ),
    make(
      id: 'd4',
      name: 'Read 20 pages',
      plant: 'pothos',
      ago: 26,
      rate: 0.92,
      seed: 4,
    ),
    make(
      id: 'd5',
      name: 'Stretch',
      plant: 'aloe_vera',
      ago: 36,
      rate: 0.95,
      schedule: Schedule.timesPerWeek(5),
      seed: 5,
    ),
    make(
      id: 'd6',
      name: 'Journal',
      plant: 'rose',
      ago: 75,
      rate: 0.98,
      seed: 6,
    ),
    make(
      id: 'd7',
      name: 'Coffees',
      plant: 'saguaro_cactus',
      ago: 30,
      rate: 1,
      goal: const Goal(target: 2, atMost: true),
      unit: 'cups',
      seed: 7,
    ),
    make(
      id: 'd8',
      name: 'Walk the dog',
      plant: 'elephant_ear',
      ago: 14,
      rate: 0.95,
      doneToday: false,
      seed: 8,
    ),
    make(
      id: 'd9',
      name: 'Vitamins',
      plant: 'snake_plant',
      ago: 45,
      rate: 0.95,
      stoppedAgo: 18,
      seed: 9,
    ),
    make(
      id: 'd10',
      name: 'Sunday yoga',
      plant: 'hydrangea',
      ago: 90,
      rate: 0.95,
      schedule: Schedule.weekday(7),
      seed: 10,
    ),
  ];
}
