import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/day.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/neglect.dart';
import 'package:garden/domain/schedule.dart';

Habit planted(Schedule s, int day, {Set<int>? watered}) => Habit.newSeed(
  id: 'h',
  name: 'Habit',
  flowerId: 'rose',
  schedule: s,
  today: day,
).copyWith(wateredDays: watered ?? {day});

// Day 4 is a Monday (1970-01-05); day 10 is the Sunday that closes its week.
const monday = 4;
const sunday = 10;

void main() {
  test('day constants are a Monday and its Sunday', () {
    expect(weekdayOf(monday), 1);
    expect(weekdayOf(sunday), 7);
  });

  group('daily habit watered on day 0', () {
    final h = planted(const Schedule.daily(), 0);

    test('day 1 is healthy (day 1 not yet over)', () {
      expect(advance(h, 1).declineStep, 0);
    });
    test('day 2 is thirsty (day 1 missed)', () {
      final a = advance(h, 2);
      expect(a.declineStep, 1);
      expect(a.missedSinceWater, 1);
    });
    test('day 3 is still thirsty (2 missed, only 3 days)', () {
      expect(advance(h, 3).declineStep, 1);
    });
    test('day 4 is wilting (3 missed, 4 days)', () {
      expect(advance(h, 4).declineStep, 2);
    });
    test('day 7 is still wilting', () {
      expect(advance(h, 7).declineStep, 2);
    });
    test('day 8 is petal loss', () {
      final a = advance(h, 8);
      expect(a.declineStep, 3);
      expect(petalsLost(a), a.missedSinceWater - 3);
    });
    test('day 29 is not lost, day 30 is lost', () {
      expect(advance(h, 29).lost, isFalse);
      expect(advance(h, 30).lost, isTrue);
    });
    test(
      'a 45-day jump in one call ends lost and leaves wateredDays alone',
      () {
        final a = advance(h, 45);
        expect(a.lost, isTrue);
        expect(a.wateredDays, {0});
        expect(a.evaluatedDay, 45);
      },
    );
    test('one big jump equals many small advances', () {
      var stepwise = h;
      for (var d = 1; d <= 45; d++) {
        stepwise = advance(stepwise, d);
      }
      expect(stepwise.toJson(), advance(h, 45).toJson());
    });
    test('advance with an earlier or same today returns the same habit', () {
      final a = advance(h, 5);
      expect(identical(advance(a, 3), a), isTrue);
      expect(identical(advance(a, 5), a), isTrue);
    });
  });

  test('petalsLost is 0 below petal loss', () {
    final h = planted(const Schedule.daily(), 0);
    expect(petalsLost(advance(h, 7)), 0);
  });

  test('daysSinceWater counts from lastWaterDay', () {
    expect(daysSinceWater(planted(const Schedule.daily(), 3), 10), 7);
  });

  group('weekday (Monday) habit watered on a Monday', () {
    final h = planted(Schedule.weekday(1), monday);

    test('days before the next Monday closes are healthy', () {
      expect(advance(h, monday + 7).declineStep, 0);
    });
    test('thirsty after the next Monday closes', () {
      final a = advance(h, monday + 8);
      expect(a.declineStep, 1);
      expect(a.missedSinceWater, 1);
    });
    test('still thirsty until a second Monday is missed', () {
      expect(advance(h, monday + 14).declineStep, 1);
    });
    test('wilting after two misses and 4+ days', () {
      final a = advance(h, monday + 15);
      expect(a.missedSinceWater, 2);
      expect(a.declineStep, 2);
    });
  });

  group('timesPerWeek(3)', () {
    test('3 waterings in the week means no misses at Sunday close', () {
      final h = planted(
        Schedule.timesPerWeek(3),
        monday,
        watered: {monday, monday + 2, monday + 4},
      ).copyWith(lastWaterDay: monday + 4);
      final a = advance(h, sunday + 1);
      expect(a.missedSinceWater, 0);
      expect(a.declineStep, 0);
    });
    test('1 watering in the week gives a shortfall of 2', () {
      final h = planted(Schedule.timesPerWeek(3), monday);
      final a = advance(h, sunday + 1);
      expect(a.missedSinceWater, 2);
    });
    test('no shortfall counted before Sunday closes', () {
      final h = planted(Schedule.timesPerWeek(3), monday);
      expect(advance(h, sunday).missedSinceWater, 0);
    });
  });
}
