import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/notification_plan.dart';
import 'package:garden/notify/schedule_math.dart';

PlannedNotification _n(int day, int minutes) => PlannedNotification(
  id: day,
  habitId: 'h',
  dayIndex: day,
  minutes: minutes,
  isGrouped: false,
  title: 't',
  body: 'b',
);

void main() {
  test('day 20000 at 540 minutes is 09:00 local on 2024-10-04', () {
    expect(localWhen(_n(20000, 540)), DateTime(2024, 10, 4, 9, 0));
  });
  test('minutes split into hour and minute', () {
    expect(localWhen(_n(0, 1259)), DateTime(1970, 1, 1, 20, 59));
  });
}
