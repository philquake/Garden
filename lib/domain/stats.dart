import 'dart:math';

import 'day.dart';
import 'schedule.dart';

const freeMissesPerMonth = 2;
const formedAfter = 66;

/// Daily target for a habit. Yes/no habits use the default (1, at least).
class Goal {
  const Goal({this.target = 1, this.atMost = false});

  final num target;
  final bool atMost;

  bool met(num value) => atMost ? value <= target : value >= target;
}

/// Whether [day] counts as done. An unlogged day is 0, so it meets an "at
/// most" goal; times-a-week habits count only logged days (shortcut: "at most"
/// targets are meant for daily habits).
bool dayMet(Schedule schedule, Goal goal, Map<int, num> log, int day) =>
    goal.met(log[day] ?? 0) &&
    (schedule.kind != ScheduleKind.timesPerWeek || log.containsKey(day));

enum PeriodState { met, forgiven, missed, pending }

/// One scheduled day (daily, weekday) or one week (times a week).
class Period {
  const Period(this.day, this.state);

  /// First day index of the period.
  final int day;
  final PeriodState state;
}

class Run {
  const Run(this.start, this.length);

  final int start;
  final int length;
}

class Stats {
  const Stats({
    required this.periods,
    required this.streak,
    required this.graceUsed,
    required this.qualifyingDays,
    required this.totalCompletions,
    required this.score,
    required this.bestRuns,
  });

  final List<Period> periods;

  /// Current run of met or forgiven periods; an unmet current period is
  /// pending and does not break it.
  final int streak;

  /// Free misses used in the calendar month of `today`.
  final int graceUsed;

  /// Days that count towards "habit formed" (met or forgiven).
  final int qualifyingDays;
  final int totalCompletions;

  /// 0..1, smoothed over time like Loop's score. Forgiven periods count as met.
  final double score;

  /// Up to five longest runs, longest first.
  final List<Run> bestRuns;

  bool get formed => qualifyingDays >= formedAfter;

  /// Today (or this week, for times-a-week habits) is still open: not met yet.
  bool get due =>
      periods.isNotEmpty && periods.last.state == PeriodState.pending;

  /// 0..1 growth towards "habit formed".
  double get growth => min(qualifyingDays / formedAfter, 1);
}

/// All streak, forgiveness and score numbers are recomputed from [log]
/// (day index -> logged value) every time, so editing a past day can never
/// leave them out of step.
Stats computeStats({
  required Schedule schedule,
  required int createdDay,
  required Map<int, num> log,
  required int today,
  Goal goal = const Goal(),
}) {
  final weekly = schedule.kind == ScheduleKind.timesPerWeek;
  bool counts(int d) => dayMet(schedule, goal, log, d);

  final periods = <Period>[];
  var qualifying = 0;
  var total = 0;
  for (var d = createdDay; d <= today; d++) {
    if (counts(d)) total++;
  }

  if (weekly) {
    final thisWeek = weekIndex(today);
    for (var w = weekIndex(createdDay); w <= thisWeek; w++) {
      final first = w * 7 - 3;
      final from = max(first, createdDay);
      final to = min(first + 6, today);
      var done = 0;
      for (var d = from; d <= to; d++) {
        if (counts(d)) done++;
      }
      qualifying += done;
      // The creation week only asks for the days that are left in it.
      final expected = min(schedule.value, first + 7 - from);
      periods.add(
        Period(
          first,
          done >= expected
              ? PeriodState.met
              : w == thisWeek
              ? PeriodState.pending
              : PeriodState.missed,
        ),
      );
    }
  } else {
    final usedByMonth = <int, int>{};
    // Free misses only bridge a live run: nothing is forgiven before the first
    // met day or after a miss the allowance could not cover.
    var live = false;
    for (var d = createdDay; d <= today; d++) {
      if (schedule.kind == ScheduleKind.weekday &&
          weekdayOf(d) != schedule.value) {
        continue;
      }
      if (counts(d)) {
        periods.add(Period(d, PeriodState.met));
        live = true;
      } else if (d == today) {
        periods.add(Period(d, PeriodState.pending));
      } else {
        final m = _monthKey(d);
        final used = usedByMonth[m] ?? 0;
        if (live && used < freeMissesPerMonth) {
          usedByMonth[m] = used + 1;
          periods.add(Period(d, PeriodState.forgiven));
        } else {
          live = false;
          periods.add(Period(d, PeriodState.missed));
        }
      }
    }
  }

  // A forgiven period counts only when a met one follows it before the next
  // miss; trailing ones are allowance spent but not yet earned.
  final counted = List<bool>.filled(periods.length, false);
  var followed = false;
  for (var i = periods.length - 1; i >= 0; i--) {
    switch (periods[i].state) {
      case PeriodState.met:
        counted[i] = followed = true;
      case PeriodState.forgiven:
        counted[i] = followed;
      case PeriodState.missed:
        followed = false;
      case PeriodState.pending:
        break;
    }
  }
  if (!weekly) qualifying = counted.where((c) => c).length;

  var streak = 0;
  for (var i = periods.length - 1; i >= 0; i--) {
    if (periods[i].state == PeriodState.missed) break;
    if (counted[i]) streak++;
  }

  final runs = <Run>[];
  int? start;
  var length = 0;
  void close() {
    if (start != null) runs.add(Run(start!, length));
    start = null;
    length = 0;
  }

  for (var i = 0; i < periods.length; i++) {
    if (periods[i].state == PeriodState.missed) {
      close();
    } else if (counted[i]) {
      start ??= periods[i].day;
      length++;
    }
  }
  close();
  runs.sort((a, b) => b.length.compareTo(a.length));

  // Half-life of 13 days (daily) or 4 weeks (weekly, weekday habits).
  final keep = pow(
    0.5,
    1 / (schedule.kind == ScheduleKind.daily ? 13 : 4),
  ).toDouble();
  var score = 0.0;
  for (final p in periods) {
    if (p.state == PeriodState.pending) continue;
    final hit = p.state == PeriodState.missed ? 0 : 1;
    score = score * keep + hit * (1 - keep);
  }

  final month = _monthKey(today);
  final grace = weekly
      ? 0
      : periods
            .where(
              (p) =>
                  p.state == PeriodState.forgiven && _monthKey(p.day) == month,
            )
            .length;

  return Stats(
    periods: periods,
    streak: streak,
    graceUsed: grace,
    qualifyingDays: qualifying,
    totalCompletions: total,
    score: score,
    bestRuns: runs.take(5).toList(),
  );
}

/// Calendar month of a day index, as one int. Day 0 is 1970-01-01.
int _monthKey(int day) {
  final d = DateTime.utc(1970, 1, 1 + day);
  return d.year * 12 + d.month;
}
