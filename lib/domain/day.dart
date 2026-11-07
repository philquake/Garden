import 'rules.dart';

/// Day index from wall-clock fields only (no elapsed-time arithmetic), so DST
/// transitions cannot shift the day. DateTime.utc normalises a negative hour
/// into the previous day.
int dayIndexFromWallClock(int year, int month, int day, int hour) {
  final ms =
      DateTime.utc(year, month, day, hour - Rules.dayStartHour)
          .millisecondsSinceEpoch;
  return _floorDiv(ms, Duration.millisecondsPerDay);
}

/// Days since 1970-01-01 of the calendar date of [local] minus the day-start
/// offset.
int dayIndex(DateTime local) =>
    dayIndexFromWallClock(local.year, local.month, local.day, local.hour);

// Day 0 (1970-01-01) was a Thursday, hence the +3 to align to Monday.
/// Monday-start week number.
int weekIndex(int day) => _floorDiv(day + 3, 7);

/// 1 = Monday .. 7 = Sunday.
int weekdayOf(int day) => (day + 3) % 7 + 1;

int _floorDiv(int a, int b) => (a - (a % b)) ~/ b;
