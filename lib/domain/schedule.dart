enum ScheduleKind { daily, timesPerWeek, weekday }

/// Immutable habit schedule. Weekdays use 1 = Monday .. 7 = Sunday.
class Schedule {
  const Schedule.daily() : this._(ScheduleKind.daily, 0);

  const Schedule._(this.kind, this._value);

  // Factories (not const) so invalid values throw ArgumentError at runtime.
  factory Schedule.timesPerWeek(int n) {
    if (n < 1 || n > 7) throw ArgumentError.value(n, 'n', 'must be 1..7');
    return Schedule._(ScheduleKind.timesPerWeek, n);
  }

  factory Schedule.weekday(int weekday) {
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError.value(weekday, 'weekday', 'must be 1..7');
    }
    return Schedule._(ScheduleKind.weekday, weekday);
  }

  final ScheduleKind kind;
  final int _value;

  /// Times per week (timesPerWeek) or the weekday (weekday); 0 for daily.
  int get value => _value;

  /// Waterings the schedule asks for in one week.
  int get perWeek => switch (kind) {
    ScheduleKind.daily => 7,
    ScheduleKind.timesPerWeek => _value,
    ScheduleKind.weekday => 1,
  };

  /// Expected completions in a 28-day window.
  int get perFourWeeks => 4 * perWeek;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (kind == ScheduleKind.timesPerWeek) 'n': _value,
    if (kind == ScheduleKind.weekday) 'weekday': _value,
  };

  factory Schedule.fromJson(Map<String, dynamic> j) {
    switch (j['kind']) {
      case 'daily':
        return const Schedule.daily();
      case 'timesPerWeek':
        return Schedule.timesPerWeek(j['n'] as int);
      case 'weekday':
        return Schedule.weekday(j['weekday'] as int);
      default:
        throw ArgumentError.value(j['kind'], 'kind', 'unknown schedule kind');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Schedule && other.kind == kind && other._value == _value;

  @override
  int get hashCode => Object.hash(kind, _value);
}
