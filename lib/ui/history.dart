import '../domain/day.dart';
import '../domain/habit_config.dart';
import '../domain/schedule.dart';
import '../domain/stats.dart';

enum Range { week, month, year }

const monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Day index of the first of [month] (1-12; out of range rolls over).
int monthStartDay(int year, int month) =>
    DateTime.utc(year, month, 1).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

String shortDate(int day) {
  final d = dateOf(day);
  return '${d.day} ${monthNames[d.month - 1]}';
}

/// One bar of the history chart and one point of the score line.
class Bucket {
  const Bucket(this.start, this.end, this.met, this.score);

  /// First and last day of the bucket (the last one ends today).
  final int start;
  final int end;

  /// Days in the bucket that met the goal.
  final int met;

  /// Score at the end of the bucket, 0..1.
  final double score;
}

double scoreAt(Tracked t, int day) =>
    day < t.config.createdDay ? 0 : t.stats(day).score;

/// 12 weeks, 12 months or 5 years ending with the one that contains [today].
List<Bucket> buckets(Tracked t, int today, Range range) {
  final d = dateOf(today);
  final starts = switch (range) {
    Range.week => [
      for (var i = 11; i >= 0; i--) (weekIndex(today) - i) * 7 - 3,
    ],
    Range.month => [
      for (var i = 11; i >= 0; i--) monthStartDay(d.year, d.month - i),
    ],
    Range.year => [for (var i = 4; i >= 0; i--) monthStartDay(d.year - i, 1)],
  };
  return [
    for (var i = 0; i < starts.length; i++)
      () {
        final end = i + 1 < starts.length ? starts[i + 1] - 1 : today;
        var met = 0;
        for (var day = starts[i]; day <= end; day++) {
          final v = t.log[day];
          if (v != null && t.config.goal.met(v)) met++;
        }
        return Bucket(starts[i], end, met, scoreAt(t, end));
      }(),
  ];
}

enum Mark { none, partial, met, forgiven }

/// How each day looks on the heatmap and the calendar.
Map<int, Mark> marksOf(Tracked t, Stats s) {
  final out = <int, Mark>{};
  if (t.config.schedule.kind != ScheduleKind.timesPerWeek) {
    for (final p in s.periods) {
      if (p.state == PeriodState.forgiven) out[p.day] = Mark.forgiven;
    }
  }
  t.log.forEach((day, v) {
    if (t.config.goal.met(v)) {
      out[day] = Mark.met;
    } else if (v > 0) {
      out[day] = Mark.partial;
    }
  });
  return out;
}
