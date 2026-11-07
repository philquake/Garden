import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/day.dart';

void main() {
  test('before 3am belongs to previous day', () {
    expect(
      dayIndex(DateTime(2026, 11, 7, 2, 59)),
      dayIndex(DateTime(2026, 11, 6, 12)),
    );
  });
  test('3am starts the new day', () {
    expect(
      dayIndex(DateTime(2026, 11, 7, 3, 0)),
      dayIndex(DateTime(2026, 11, 7, 23)),
    );
  });
  test('DST-day wall-clock behaviour', () {
    final d3 = dayIndexFromWallClock(2026, 3, 29, 3);
    expect(d3, dayIndexFromWallClock(2026, 3, 29, 23));
    expect(d3, dayIndexFromWallClock(2026, 3, 29, 2) + 1);
    expect(
      dayIndexFromWallClock(2026, 10, 25, 2),
      dayIndexFromWallClock(2026, 10, 24, 12),
    );
  });
  test('pre-1970 alignment', () {
    expect(weekdayOf(-3), 1);
    expect(weekIndex(-4), -1);
  });
  test('Monday starts a new week', () {
    final sun = dayIndex(DateTime(2026, 11, 8, 12));
    final mon = dayIndex(DateTime(2026, 11, 9, 12));
    expect(weekIndex(mon), weekIndex(sun) + 1);
    expect(weekdayOf(mon), 1);
    expect(weekdayOf(sun), 7);
  });
}
