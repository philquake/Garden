import 'rules.dart';

/// Days since 1970-01-01 of the calendar date of [local] minus the day-start
/// offset. Uses a UTC date so DST cannot shift the result.
int dayIndex(DateTime local) {
  final s = local.subtract(const Duration(hours: Rules.dayStartHour));
  return DateTime.utc(s.year, s.month, s.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

/// Monday-start week number (1970-01-01 was a Thursday).
int weekIndex(int day) => ((day + 3) / 7).floor();

/// 1 = Monday .. 7 = Sunday.
int weekdayOf(int day) => (day + 3) % 7 + 1;
