import 'schedule.dart';

/// Immutable habit state. Days are day indexes (see day.dart).
class Habit {
  // Not const: wateredDays is copied into an unmodifiable set so no caller can
  // mutate a Habit (or earlier snapshots sharing the set) after construction.
  Habit({
    required this.id,
    required this.name,
    required this.flowerId,
    required this.schedule,
    required Set<int> wateredDays,
    required this.plantedDay,
    required this.plantingWaterings,
    required this.declineStep,
    required this.missedSinceWater,
    required this.lastWaterDay,
    required this.evaluatedDay,
    required this.lost,
    required this.plantingNumber,
    required this.reminderMinutes,
    required this.ignoredReminders,
    this.reminderBaselineMissed = 0,
  }) : wateredDays = Set.unmodifiable(wateredDays);

  /// A freshly planted seed; the planting day counts as a grace day.
  factory Habit.newSeed({
    required String id,
    required String name,
    required String flowerId,
    required Schedule schedule,
    required int today,
    int reminderMinutes = -1,
  }) => Habit(
    id: id,
    name: name,
    flowerId: flowerId,
    schedule: schedule,
    wateredDays: const {},
    plantedDay: today,
    plantingWaterings: 0,
    declineStep: 0,
    missedSinceWater: 0,
    lastWaterDay: today,
    evaluatedDay: today,
    lost: false,
    plantingNumber: 1,
    reminderMinutes: reminderMinutes,
    ignoredReminders: 0,
  );

  final String id;
  final String name;
  final String flowerId;
  final Schedule schedule;
  final Set<int> wateredDays;
  final int plantedDay;
  final int plantingWaterings;

  /// 0 healthy, 1 thirsty, 2 wilting, 3 petal loss.
  final int declineStep;
  final int missedSinceWater;
  final int lastWaterDay;
  final int evaluatedDay;
  final bool lost;
  final int plantingNumber;

  /// Minutes after midnight, or -1 for no reminder.
  final int reminderMinutes;
  final int ignoredReminders;

  /// missedSinceWater when the reminder was last set or changed; misses up to
  /// here do not count as ignored reminders.
  final int reminderBaselineMissed;

  Habit copyWith({
    String? id,
    String? name,
    String? flowerId,
    Schedule? schedule,
    Set<int>? wateredDays,
    int? plantedDay,
    int? plantingWaterings,
    int? declineStep,
    int? missedSinceWater,
    int? lastWaterDay,
    int? evaluatedDay,
    bool? lost,
    int? plantingNumber,
    int? reminderMinutes,
    int? ignoredReminders,
    int? reminderBaselineMissed,
  }) => Habit(
    id: id ?? this.id,
    name: name ?? this.name,
    flowerId: flowerId ?? this.flowerId,
    schedule: schedule ?? this.schedule,
    wateredDays: wateredDays ?? this.wateredDays,
    plantedDay: plantedDay ?? this.plantedDay,
    plantingWaterings: plantingWaterings ?? this.plantingWaterings,
    declineStep: declineStep ?? this.declineStep,
    missedSinceWater: missedSinceWater ?? this.missedSinceWater,
    lastWaterDay: lastWaterDay ?? this.lastWaterDay,
    evaluatedDay: evaluatedDay ?? this.evaluatedDay,
    lost: lost ?? this.lost,
    plantingNumber: plantingNumber ?? this.plantingNumber,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    ignoredReminders: ignoredReminders ?? this.ignoredReminders,
    reminderBaselineMissed:
        reminderBaselineMissed ?? this.reminderBaselineMissed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'flowerId': flowerId,
    'schedule': schedule.toJson(),
    'wateredDays': wateredDays.toList()..sort(),
    'plantedDay': plantedDay,
    'plantingWaterings': plantingWaterings,
    'declineStep': declineStep,
    'missedSinceWater': missedSinceWater,
    'lastWaterDay': lastWaterDay,
    'evaluatedDay': evaluatedDay,
    'lost': lost,
    'plantingNumber': plantingNumber,
    'reminderMinutes': reminderMinutes,
    'ignoredReminders': ignoredReminders,
    'reminderBaselineMissed': reminderBaselineMissed,
  };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
    id: j['id'] as String,
    name: j['name'] as String,
    flowerId: j['flowerId'] as String,
    schedule: Schedule.fromJson(
      Map<String, dynamic>.from(j['schedule'] as Map),
    ),
    wateredDays: (j['wateredDays'] as List).cast<int>().toSet(),
    plantedDay: j['plantedDay'] as int,
    plantingWaterings: j['plantingWaterings'] as int,
    declineStep: j['declineStep'] as int,
    missedSinceWater: j['missedSinceWater'] as int,
    lastWaterDay: j['lastWaterDay'] as int,
    evaluatedDay: j['evaluatedDay'] as int,
    lost: j['lost'] as bool,
    plantingNumber: j['plantingNumber'] as int,
    reminderMinutes: j['reminderMinutes'] as int,
    ignoredReminders: j['ignoredReminders'] as int,
    // Absent in gardens saved before this field existed.
    reminderBaselineMissed: j['reminderBaselineMissed'] as int? ?? 0,
  );
}
