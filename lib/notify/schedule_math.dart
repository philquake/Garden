import '../domain/notification_plan.dart';

/// Local wall-clock time of a planned notification (day index counts days
/// since 1970-01-01 of the calendar date, not UTC instants).
DateTime localWhen(PlannedNotification n) {
  final d = DateTime.utc(1970, 1, 1).add(Duration(days: n.dayIndex));
  return DateTime(d.year, d.month, d.day, n.minutes ~/ 60, n.minutes % 60);
}
